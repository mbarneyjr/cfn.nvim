local M = {}

local rpc = require("cfn.lib.cli._rpc")

---@alias CliRefactorStatus
---| "CREATE_IN_PROGRESS"
---| "CREATE_COMPLETE"
---| "CREATE_FAILED"
---| "DELETE_IN_PROGRESS"
---| "DELETE_COMPLETE"
---| "DELETE_FAILED"

---@alias CliRefactorExecutionStatus
---| "UNAVAILABLE"
---| "AVAILABLE"
---| "OBSOLETE"
---| "EXECUTE_IN_PROGRESS"
---| "EXECUTE_COMPLETE"
---| "EXECUTE_FAILED"
---| "ROLLBACK_IN_PROGRESS"
---| "ROLLBACK_COMPLETE"
---| "ROLLBACK_FAILED"

---@class CliRefactorIdResult
---@field stackRefactorId string

---@class CliRefactorDescribeResult
---@field stackRefactorId string
---@field status CliRefactorStatus
---@field statusReason? string
---@field executionStatus CliRefactorExecutionStatus
---@field executionStatusReason? string
---@field description? string
---@field stackIds? string[]

---@param profile string
---@param region string
---@param refactor_operation RefactorMappingRegistration
---@return string? err
---@return CliRefactorIdResult? created
function M.create(profile, region, refactor_operation)
  local payload = vim.json.encode(refactor_operation)
  return rpc.run({ "refactor", "create", "--profile", profile, "--region", region, "--payload", payload })
end

---@param profile string
---@param region string
---@param stack_refactor_id string
---@return string? err
---@return CliRefactorDescribeResult? described
function M.describe(profile, region, stack_refactor_id)
  return rpc.run({ "refactor", "describe", "--profile", profile, "--region", region, "--id", stack_refactor_id })
end

---@param profile string
---@param region string
---@param stack_refactor_id string
---@return string? err
---@return CliRefactorIdResult? executed
function M.execute(profile, region, stack_refactor_id)
  return rpc.run({ "refactor", "execute", "--profile", profile, "--region", region, "--id", stack_refactor_id })
end

return M
