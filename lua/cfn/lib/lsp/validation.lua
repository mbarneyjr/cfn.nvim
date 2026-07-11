local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@class CfnLspParameter
---@field ParameterKey string
---@field ParameterValue? string
---@field UsePreviousValue? boolean
---@class CfnLspTag
---@field Key string
---@field Value string
---@class CfnLspResourceToImport
---@field ResourceType string
---@field LogicalResourceId string
---@field ResourceIdentifier table<string, string>
---@alias CfnLspCapability "CAPABILITY_IAM"|"CAPABILITY_NAMED_IAM"|"CAPABILITY_AUTO_EXPAND"
---@alias CfnLspOnStackFailure "DO_NOTHING"|"ROLLBACK"|"DELETE"
---@alias CfnLspDeploymentMode "REVERT_DRIFT"
---@class CfnLspStackValidationCreateParams
---@field id string
---@field uri string
---@field stackName string
---@field parameters? CfnLspParameter[]
---@field capabilities? CfnLspCapability[]
---@field tags? CfnLspTag[]
---@field onStackFailure? CfnLspOnStackFailure
---@field includeNestedStacks? boolean
---@field resourcesToImport? CfnLspResourceToImport[]
---@field importExistingResources? boolean
---@field deploymentMode? CfnLspDeploymentMode
---@field keepChangeSet? boolean
---@field s3Bucket? string
---@field s3Key? string
---@class CfnLspStackValidationCreateResult
---@field id string
---@field changeSetName string   Server-generated: "cfn-lsp-...-<id>-<uuid>". Cannot be chosen.
---@field stackName string

---@param params CfnLspStackValidationCreateParams
---@return string? err
---@return CfnLspStackValidationCreateResult? result
function M.create(params)
  ---@type lsp.ResponseError?, CfnLspStackValidationCreateResult?
  local err, result = rpc.request("aws/cfn/stack/validation/create", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@alias CfnLspStackActionState "IN_PROGRESS"|"SUCCESSFUL"|"FAILED"
---@alias CfnLspStackActionPhase
---| "VALIDATION_STARTED"
---| "VALIDATION_IN_PROGRESS"
---| "VALIDATION_COMPLETE"
---| "VALIDATION_FAILED"
---| "DEPLOYMENT_STARTED"
---| "DEPLOYMENT_IN_PROGRESS"
---| "DEPLOYMENT_COMPLETE"
---| "DEPLOYMENT_FAILED"
---| "DELETION_STARTED"
---| "DELETION_IN_PROGRESS"
---| "DELETION_COMPLETE"
---| "DELETION_FAILED"
---@class CfnLspStackValidationStatusParams
---@field id string
---@class CfnLspStackValidationStatusResult
---@field id string
---@field state CfnLspStackActionState

---@param params CfnLspStackValidationStatusParams
---@return string? err
---@return CfnLspStackValidationStatusResult? result
function M.status(params)
  ---@type lsp.ResponseError?, CfnLspStackValidationStatusResult?
  local err, result = rpc.request("aws/cfn/stack/validation/status", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspResourceChangeDetail
---@field Target? { Attribute?: string, Name?: string, RequiresRecreation?: string }
---@field Evaluation? string
---@field ChangeSource? string
---@field CausingEntity? string
---@alias CfnLspChangeAction "Add"|"Dynamic"|"Import"|"Modify"|"Remove"|"SyncWithActual"
---@class CfnLspResourceChange
---@field action? CfnLspChangeAction
---@field logicalResourceId? string
---@field physicalResourceId? string
---@field resourceType? string
---@field replacement? string
---@field scope? string[]
---@field beforeContext? string
---@field afterContext? string
---@field resourceDriftStatus? string
---@field details? CfnLspResourceChangeDetail[]
---@class CfnLspStackChange
---@field type? string
---@field resourceChange? CfnLspResourceChange
---@class CfnLspValidationDetail
---@field ValidationName string
---@field Severity "INFO"|"ERROR"
---@field Message string
---@field LogicalId? string
---@field ResourcePropertyPath? string
---@field Timestamp? string
---@field ValidationStatusReason? string
---@field diagnosticId? string
---@class CfnLspStackValidationDescribeParams
---@field id string
---@class CfnLspStackValidationDescribeResult
---@field id string
---@field state CfnLspStackActionState
---@field changes? CfnLspStackChange[]
---@field FailureReason? string
---@field ValidationDetails? CfnLspValidationDetail[]
---@field deploymentMode? CfnLspDeploymentMode

---@param params CfnLspStackValidationDescribeParams
---@return string? err
---@return CfnLspStackValidationDescribeResult? result
function M.describe(params)
  ---@type lsp.ResponseError?, CfnLspStackValidationDescribeResult?
  local err, result = rpc.request("aws/cfn/stack/validation/status/describe", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

return M
