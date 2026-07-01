local M = {}

local Map = require("cfn.lib.state.map")

---@class TemplateRegistration
---@field profile string
---@field region string
---@field stack_name string
---@field artifact_bucket_name? string
---@type Map<TemplateRegistration>
M.template_registration = Map.new()
M.template_registration:persist("template-registrations.json")

---@class ActiveChangeSet
---@field id string
---@field stackName string
---@field changeSetName string
---@type Map<ActiveChangeSet>
M.active_changeset = Map.new()

---@type Map<CfnCredentials>
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
