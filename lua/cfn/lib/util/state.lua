local M = {}

local state = require("cfn.lib.state")
local buffer = require("cfn.lib.buffer")

---@param stack_name string
function M.get_template_path_from_stack(stack_name)
  local template_registrations = state.template_registration:list()
  for template_path, registration in pairs(template_registrations) do
    if registration.stack_name == stack_name then
      return template_path
    end
  end
  return nil
end

---@param bufnr? number
---@return string? error
---@return TemplateRegistration? registration
---@return string? template_path
function M.get_template_registration(bufnr)
  local template_path_err, template_path = buffer.get_current_buffer_template_path(bufnr)
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
