local M = {}

local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")

---@return string? error
---@return TemplateRegistration? registration
---@return string? template_path
function M.get_template_registration()
  local template_path_err, template_path = buffer.get_current_buffer_template_path()
  if template_path_err ~= nil or not template_path then
    return "cannot load profile: " .. (template_path_err or "no template path"), nil, nil
  end

  local registration = state.template_registration:get(template_path)
  if registration == nil then
    return "current template is not registered, please run :Cfn template register", nil, nil
  end

  return nil, registration, template_path
end

return M
