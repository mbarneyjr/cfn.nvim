local M = {}

local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local ui = require("cfn.lib.ui")
local util = require("cfn.lib.util")

function M.unload()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local registration_err, registration, template_path = util.state.get_template_registration(bufnr, "unload changeset")
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.warn(registration_err or "no registration found")
      return
    end

    if state.active_changeset:get(vim.fn.fnamemodify(template_path, ":.")) == nil then
      return notify.warn("no active changeset to unload")
    end

    local clear_err = ui.template_highlight.clear(bufnr)
    if clear_err ~= nil then
      return notify.error("cannot clear resource highlights: " .. clear_err)
    end

    state.active_changeset:remove(vim.fn.fnamemodify(template_path, ":."))
    notify.info("unloaded changeset")
  end)()
end

return M
