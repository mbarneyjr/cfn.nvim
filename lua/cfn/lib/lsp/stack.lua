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

return M
