local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@class CfnLspStackDeploymentCreateParams
---@field id string
---@field changeSetName string
---@field stackName string
---@class CfnLspStackDeploymentCreateResult
---@field id string
---@field changeSetName string
---@field stackName string

---@param params CfnLspStackDeploymentCreateParams
---@return string? err
---@return CfnLspStackDeploymentCreateResult? result
function M.create(params)
  ---@type lsp.ResponseError?, CfnLspStackDeploymentCreateResult?
  local err, result = rpc.request("aws/cfn/stack/deployment/create", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspDeploymentEvent
---@field LogicalResourceId? string
---@field ResourceType? string
---@field Timestamp? string ISO 8601 (serialized luxon DateTime)
---@field ResourceStatus? string aws-sdk ResourceStatus enum
---@field ResourceStatusReason? string
---@field DetailedStatus? string aws-sdk DetailedStatus enum
---@class CfnLspStackDeploymentDescribeParams
---@field id string
---@class CfnLspStackDeploymentDescribeResult
---@field id string
---@field state CfnLspStackActionState
---@field phase CfnLspStackActionPhase
---@field changes? CfnLspStackChange[]
---@field FailureReason? string
---@field DeploymentEvents? CfnLspDeploymentEvent[]

---@param params CfnLspStackDeploymentDescribeParams
---@return string? err
---@return CfnLspStackDeploymentDescribeResult? result
function M.describe(params)
  ---@type lsp.ResponseError?, CfnLspStackDeploymentDescribeResult?
  local err, result = rpc.request("aws/cfn/stack/deployment/status/describe", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

return M
