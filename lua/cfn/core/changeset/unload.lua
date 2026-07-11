local M = {}

local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local util = require("cfn.core.changeset.util")

function M.unload()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local registration_err, registration, template_path = util.get_template_registration(bufnr)
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.warn(registration_err or "no registration found")
      return
    end

    local highlight_err = util.clear_highlight(bufnr)
    if highlight_err ~= nil then
      notify.error("error clearing highlight: " .. highlight_err)
      return
    end

    state.active_changeset:remove(vim.fn.fnamemodify(template_path, ":."))
    notify.info("unloaded changeset")
  end)()
end

return M
