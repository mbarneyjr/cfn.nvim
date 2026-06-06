local M = {}

local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")

function M.load()
  -- load the current template's profile credentials into the LSP
  coroutine.wrap(function()
    local template_path_err, template_path = buffer.get_current_buffer_template_path()
    if template_path_err ~= nil or not template_path then
      vim.print("cfn.nvim: cannot load profile: " .. (template_path_err or "no template path"))
      return
    end
    local template_registration = state.template_registration:get(template_path)
    if not template_registration then
      vim.print("cfn.nvim: current template is not registered")
      return
    end
    local credentials = require("cfn.lib.credentials")
    credentials.set(template_registration.profile)
  end)()
end

return M
