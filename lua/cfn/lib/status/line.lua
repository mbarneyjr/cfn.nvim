local M = {}

local state = require("cfn.lib.state")
local util = require("cfn.lib.util")

---@class CfnStatus
---@field stack_name string
---@field profile string
---@field region string
---@field changeset_name? string
---@field refactor_id? string

---@param bufnr? integer
---@return CfnStatus?
function M.get(bufnr)
  local _, registration, path = util.state.get_template_registration(bufnr)
  if registration == nil or path == nil then
    return
  end
  local changeset = state.active_changeset:get(path)
  local refactor = state.active_refactor:get("main")
  return {
    stack_name = registration.stack_name,
    profile = registration.profile,
    region = registration.region,
    changeset_name = changeset and changeset.changeSetName,
    refactor_id = refactor and refactor.stack_refactor_id,
  }
end

return M
