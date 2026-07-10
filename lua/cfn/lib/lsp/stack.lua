local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@alias CfnLspParameterType
---| "String"
---| "Number"
---| "CommaDelimitedList"
---| "List<Number>"
---| "List<String>"
---| "List<AWS::EC2::AvailabilityZone::Name>"
---| "List<AWS::EC2::Image::Id>"
---| "List<AWS::EC2::Instance::Id>"
---| "List<AWS::EC2::SecurityGroup::GroupName>"
---| "List<AWS::EC2::SecurityGroup::Id>"
---| "List<AWS::EC2::Subnet::Id>"
---| "List<AWS::EC2::VPC::Id>"
---| "List<AWS::EC2::Volume::Id>"
---| "List<AWS::Route53::HostedZone::Id>"
---| "AWS::EC2::AvailabilityZone::Name"
---| "AWS::EC2::Image::Id"
---| "AWS::EC2::Instance::Id"
---| "AWS::EC2::KeyPair::KeyName"
---| "AWS::EC2::SecurityGroup::GroupName"
---| "AWS::EC2::SecurityGroup::Id"
---| "AWS::EC2::Subnet::Id"
---| "AWS::EC2::VPC::Id"
---| "AWS::EC2::Volume::Id"
---| "AWS::Route53::HostedZone::Id"
---| "AWS::SSM::Parameter::Name"
---| string
---@alias CfnLspParameterValue string|number|boolean
---@class CfnLspTemplateParameter
---@field name string
---@field Type? CfnLspParameterType
---@field Default? CfnLspParameterValue
---@field AllowedValues? CfnLspParameterValue[]
---@field AllowedPattern? string
---@field ConstraintDescription? string
---@field Description? string
---@field MaxLength? number
---@field MaxValue? number
---@field MinLength? number
---@field MinValue? number
---@field NoEcho? boolean
---@field UsePreviousValue? boolean
---@field CurrentValue? string
---@class CfnLspStackParametersResult
---@field parameters CfnLspTemplateParameter[]

---@param uri string
---@return string? err
---@return CfnLspStackParametersResult? result
function M.parameters(uri)
  ---@type lsp.ResponseError?, CfnLspStackParametersResult?
  local err, result = rpc.request("aws/cfn/stack/parameters", uri)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspStackOutput
---@field OutputKey? string
---@field OutputValue? string
---@field Description? string
---@field ExportName? string
---@class CfnLspStackParameter
---@field ParameterKey? string
---@field ParameterValue? string
---@field UsePreviousValue? boolean
---@field ResolvedValue? string
---@class CfnLspStackTag
---@field Key string
---@field Value string
---@class CfnLspStackDriftInformation
---@field StackDriftStatus string
---@field LastCheckTimestamp? string
---@class CfnLspStackOperation
---@field OperationId? string
---@field OperationType? string
---@class CfnLspRollbackConfiguration
---@field RollbackTriggers? table[]
---@field MonitoringTimeInMinutes? integer
---@class CfnLspDescribeStackParams
---@field stackName string
---@class CfnLspDescribeStackData
---@field StackId? string
---@field StackName string
---@field ChangeSetId? string
---@field Description? string
---@field Parameters? CfnLspStackParameter[]
---@field CreationTime string
---@field DeletionTime? string
---@field LastUpdatedTime? string
---@field StackStatus string
---@field StackStatusReason? string
---@field DisableRollback? boolean
---@field EnableTerminationProtection? boolean
---@field NotificationARNs? string[]
---@field TimeoutInMinutes? integer
---@field Capabilities? string[]
---@field Outputs? CfnLspStackOutput[]
---@field Tags? CfnLspStackTag[]
---@field DriftInformation? CfnLspStackDriftInformation
---@field RollbackConfiguration? CfnLspRollbackConfiguration
---@field LastOperations? CfnLspStackOperation[]
---@field RoleARN? string
---@class CfnLspDescribeStackResult
---@field stack CfnLspDescribeStackData

---@param params CfnLspDescribeStackParams
---@return string? err
---@return CfnLspDescribeStackResult? result
function M.describe(params)
  ---@type lsp.ResponseError?, CfnLspDescribeStackResult?
  local err, result = rpc.request("aws/cfn/stack/describe", params or {})
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspStackResourceDriftInformationSummary
---@field StackResourceDriftStatus string
---@field LastCheckTimestamp? string
---@class CfnLspModuleInfo
---@field TypeHierarchy? string
---@field LogicalIdHierarchy? string
---@class CfnLspStackResourceSummary
---@field LogicalResourceId string
---@field PhysicalResourceId? string
---@field ResourceType string
---@field LastUpdatedTimestamp string
---@field ResourceStatus string
---@field ResourceStatusReason? string
---@field DriftInformation? CfnLspStackResourceDriftInformationSummary
---@field ModuleInfo? CfnLspModuleInfo
---@class CfnLspListStackResourcesParams
---@field stackName string
---@field nextToken? string
---@class CfnLspListStackResourcesResult
---@field resources CfnLspStackResourceSummary[]
---@field nextToken? string

---@param params CfnLspListStackResourcesParams
---@return string? err
---@return CfnLspListStackResourcesResult? result
function M.resources(params)
  ---@type lsp.ResponseError?, CfnLspListStackResourcesResult?
  local err, result = rpc.request("aws/cfn/stack/resources", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@param params CfnLspListStackResourcesParams
---@return string? err
---@return CfnLspStackResourceSummary[]? resources
function M.resources_all(params)
  local all = {}
  local next_token = params.nextToken
  while true do
    local err, page = M.resources({ stackName = params.stackName, nextToken = next_token })
    if err or page == nil then
      return err or "no result from LSP method", nil
    end
    vim.list_extend(all, page.resources)
    if not page.nextToken then
      break
    end
    next_token = page.nextToken
  end
  return nil, all
end

---@class CfnLspOperationEvent
---@field EventId? string
---@field StackId? string
---@field OperationId? string the operation this event belongs to
---@field OperationType? "CREATE_STACK"|"UPDATE_STACK"|"DELETE_STACK"|"ROLLBACK"|"CONTINUE_ROLLBACK"|"CREATE_CHANGESET" aws-sdk OperationType enum
---@field OperationStatus? "IN_PROGRESS"|"SUCCEEDED"|"FAILED" aws-sdk StackOperationStatus enum
---@field EventType? "STACK_EVENT"|"PROGRESS"|"HOOK_INVOCATION_ERROR"|"PROVISIONING_ERROR"|"VALIDATION_ERROR"|string aws-sdk EventType enum (wire value is "PROGRESS", not the SDK's declared "PROGRESS_EVENT")
---@field LogicalResourceId? string
---@field PhysicalResourceId? string
---@field ResourceType? string
---@field Timestamp? string ISO-8601 (aws-sdk Date serialized on the wire)
---@field StartTime? string ISO-8601
---@field EndTime? string ISO-8601
---@field ResourceStatus? string aws-sdk ResourceStatus enum
---@field ResourceStatusReason? string
---@field ResourceProperties? string JSON blob of the properties used to create the resource
---@field ClientRequestToken? string shared by all events from one stack operation
---@field HookType? string
---@field HookStatus? string aws-sdk HookStatus enum
---@field HookStatusReason? string
---@field HookInvocationPoint? string aws-sdk HookInvocationPoint enum
---@field HookFailureMode? string aws-sdk HookFailureMode enum
---@field DetailedStatus? string aws-sdk DetailedStatus enum
---@field ValidationFailureMode? string aws-sdk HookFailureMode enum
---@field ValidationName? string
---@field ValidationStatus? "FAILED"|"SKIPPED" aws-sdk ValidationStatus enum
---@field ValidationStatusReason? string
---@field ValidationPath? string
---@class CfnLspDescribeEventsParams
---@field stackName? string
---@field changeSetName? string
---@field operationId? string
---@field failedEventsOnly? boolean
---@field nextToken? string
---@class CfnLspDescribeEventsResult
---@field events CfnLspOperationEvent[]
---@field nextToken? string

---@param params CfnLspDescribeEventsParams
---@return string? err
---@return CfnLspDescribeEventsResult? result
function M.events_describe(params)
  ---@type lsp.ResponseError?, CfnLspDescribeEventsResult?
  local err, result = rpc.request("aws/cfn/stack/events/describe", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspEventsFilter
---@field clientRequestToken? string
---@field operationId? string
---@param params CfnLspDescribeEventsParams
---@param filter CfnLspEventsFilter
---@param marker? string EventId to stop at (exclusive)
---@return string? err
---@return CfnLspOperationEvent[]? events
---@return string? marker
function M.events_describe_until(params, filter, marker)
  local all = {}
  local next_token = params.nextToken
  while true do
    local err, page = M.events_describe({
      stackName = params.stackName,
      changeSetName = params.changeSetName,
      operationId = params.operationId,
      failedEventsOnly = params.failedEventsOnly,
      nextToken = next_token,
    })
    if err or page == nil then
      return err or "no result from LSP method", nil, nil
    end
    for _, event in ipairs(page.events) do
      local matches = (filter.operationId ~= nil and event.OperationId == filter.operationId)
        or (filter.clientRequestToken ~= nil and event.ClientRequestToken == filter.clientRequestToken)
      if not matches or (marker ~= nil and event.EventId == marker) then
        return nil, all, all[1] and all[1].EventId or marker
      end
      table.insert(all, event)
    end
    if not page.nextToken then
      break
    end
    next_token = page.nextToken
  end
  return nil, all, all[1] and all[1].EventId or marker
end

---@param uri string
---@return string? err
---@return CfnLspCapability[]? capabilities
function M.capabilities(uri)
  ---@type lsp.ResponseError?, { capabilities: CfnLspCapability[] }?
  local err, result = rpc.request("aws/cfn/stack/capabilities", uri)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result.capabilities
end

---@class CfnLspChangeSetSummary
---@field changeSetName string
---@field status string
---@field creationTime? string
---@field description? string
---@class CfnLspListChangeSetParams
---@field stackName string
---@field nextToken? string
---@class CfnLspListChangeSetResult
---@field changeSets CfnLspChangeSetSummary[]
---@field nextToken? string

---@param params CfnLspListChangeSetParams
---@return string? err
---@return CfnLspListChangeSetResult? result
function M.changeset_list(params)
  ---@type lsp.ResponseError?, CfnLspListChangeSetResult?
  local err, result = rpc.request("aws/cfn/stack/changeSet/list", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@param params CfnLspListChangeSetParams
---@return string? err
---@return CfnLspChangeSetSummary[]? changeSets
function M.changeset_list_all(params)
  local all = {}
  local next_token = params.nextToken
  while true do
    local err, page = M.changeset_list({ stackName = params.stackName, nextToken = next_token })
    if err or page == nil then
      return err or "no result from LSP method", nil
    end
    vim.list_extend(all, page.changeSets)
    if not page.nextToken then
      break
    end
    next_token = page.nextToken
  end
  return nil, all
end

return M
