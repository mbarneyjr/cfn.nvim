local M = {}

local Map = require("cfn.lib.state.map")

---@class TemplateRegistration
---@field profile string
---@field region string
---@field stack_name string
---@type Map<TemplateRegistration>
M.template_registration = Map.new()
M.template_registration:persist("template-registrations.json")

---@class Credentials
---@field jwe string
---@field expiration string
---@type Map<Credentials>
M.credentials = Map.new()

local session_key = nil
---@return string base64-encoded 32-byte session key
function M.encryption_key()
  if not session_key then
    session_key = vim.base64.encode(assert(vim.uv.random(32)))
  end
  return session_key
end

return M
