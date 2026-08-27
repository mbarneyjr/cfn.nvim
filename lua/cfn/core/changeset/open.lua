local M = {}

local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local progress = require("cfn.lib.progress")
local util = require("cfn.lib.util")

function M.open()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local registration_err, registration, template_path = util.state.get_template_registration(bufnr, "open changeset")
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.warn(registration_err or "no registration found")
      return
    end

    local changeSet = state.active_changeset:get(vim.fn.fnamemodify(template_path, ":."))
    if changeSet == nil then
      notify.warn("no active changeset found, please run :Cfn changeset load or :Cfn changeset create")
      return
    end

    local console_url = string.format(
      "https://%s.console.aws.amazon.com/cloudformation/home?region=%s#/stacks/changesets/changes?stackId=%s&changeSetId=%s",
      registration.region,
      registration.region,
      registration.stack_name,
      changeSet.changeSetName
    )
    progress.send(console_url, true, {
      title = "changeset url",
      status = "success",
    })
    local cmd, err = vim.ui.open(console_url)
    if cmd == nil then
      notify.error("cannot open browser: " .. (err or "no opener available"))
      return
    end
  end)()
end

return M
