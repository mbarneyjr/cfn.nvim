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

---@class ResourceToImportRegistration
---@field resources CfnLspResourceToImport[]
---@type Map<ResourceToImportRegistration>
M.resources_to_import = Map.new()

---@class RefactorStackDefinition
---@field stack_name string
---@field template_path string
---@class RefactorResourceMappingLocation
---@field stack_name string
---@field logical_id string
---@class RefactorResourceMapping
---@field source RefactorResourceMappingLocation
---@field destination RefactorResourceMappingLocation
---@field inferred? boolean the mapping was derived by `:Cfn refactor refresh`, not entered by hand
---@class RefactorMappingRegistration
---@field stack_definitions RefactorStackDefinition[]
---@field mappings RefactorResourceMapping[]
---@type Map<RefactorMappingRegistration>
M.refactor_operation = Map.new()

---@class ActiveRefactor
---@field stack_refactor_id string
---@field profile string
---@field region string
---@type Map<ActiveRefactor>
M.active_refactor = Map.new()

---@class ActiveChangeSet
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
