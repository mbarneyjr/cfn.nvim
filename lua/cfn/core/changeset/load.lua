local M = {}

local credentials = require("cfn.lib.credentials")
local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local lsp = require("cfn.lib.lsp")
local ui = require("cfn.lib.ui")
local util = require("cfn.core.changeset.util")

function M.load()
  coroutine.wrap(function()
    local registration_err, registration, template_path = util.get_template_registration()
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.error(registration_err or "no registration found")
      return
    end

    if credentials.current_profile() ~= registration.profile then
      credentials.set(registration.profile)
    end
    local changeset_err, changesets = lsp.stack.changeset_list_all({
      stackName = registration.stack_name,
    })
    if changeset_err ~= nil or changesets == nil then
      notify.error("cannot load changeset: " .. (changeset_err or "no changesets found"))
      return
    end
    ---@type CfnLspChangeSetSummary[]
    local valid_changesets = {}
    for _, changeset in ipairs(changesets) do
      if changeset.status == "CREATE_COMPLETE" then
        table.insert(valid_changesets, changeset)
      end
    end
    table.sort(valid_changesets, function(a, b)
      return (a.creationTime or "") > (b.creationTime or "")
    end)

    if #valid_changesets == 0 then
      return notify.warn("There are no valid changesets to load")
    end

    local chosen_changeset = ui.select(valid_changesets, {
      prompt = "Select a changeset to load:",
      ---@param item CfnLspChangeSetSummary
      format_item = function(item)
        local max = 40
        local name = item.changeSetName
        if #name > max then
          name = name:sub(1, max - 1) .. "…"
        end
        return name .. " (" .. item.creationTime .. ")"
      end,
    })
    if chosen_changeset == nil then
      notify.warn("no changeset selected")
      return
    end

    state.active_changeset:set(vim.fn.fnamemodify(template_path, ":."), {
      stackName = registration.stack_name,
      changeSetName = chosen_changeset.changeSetName,
    })
  end)()
end

return M
