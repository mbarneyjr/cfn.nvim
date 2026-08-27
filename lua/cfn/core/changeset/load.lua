local M = {}

local credentials = require("cfn.lib.credentials")
local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local progress = require("cfn.lib.progress")
local lsp = require("cfn.lib.lsp")
local ui = require("cfn.lib.ui")
local util = require("cfn.lib.util")
local changeset_util = require("cfn.core.changeset.util")

function M.load()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local registration_err, registration, template_path = util.state.get_template_registration(bufnr, "load changeset")
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.error(registration_err or "no registration found")
      return
    end

    credentials.set(registration.profile, registration.region)

    local describe_stack_err = lsp.stack.describe({ stackName = registration.stack_name })
    if describe_stack_err ~= nil then
      if describe_stack_err:find("does not exist", 1, true) then
        return notify.warn("stack " .. registration.stack_name .. " does not exist")
      end
      return notify.error("error describing stack: " .. describe_stack_err)
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

    local describe_err, described = lsp.stack.changeset_describe({
      stackName = registration.stack_name,
      changeSetName = chosen_changeset.changeSetName,
    })
    if describe_err ~= nil or described == nil then
      notify.error("cannot describe changeset: " .. (describe_err or "no result"))
      return
    end

    local highlight_err = changeset_util.highlight_changeset(bufnr, described)
    if highlight_err ~= nil then
      notify.error("error highlighting changeset: " .. highlight_err)
      return
    end

    state.active_changeset:set(vim.fn.fnamemodify(template_path, ":."), {
      stackName = registration.stack_name,
      changeSetName = chosen_changeset.changeSetName,
    })
    local console_url = string.format(
      "https://%s.console.aws.amazon.com/cloudformation/home?region=%s#/stacks/changesets/changes?stackId=%s&changeSetId=%s",
      registration.region,
      registration.region,
      registration.stack_name,
      chosen_changeset.changeSetName
    )
    progress.send(console_url, true, {
      title = "changeset url",
      status = "success",
    })
    notify.info("loaded changeset: " .. chosen_changeset.changeSetName)
  end)()
end

return M
