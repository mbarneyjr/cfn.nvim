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
---| string todo: handle AWS::SSM::Parameter::Value<> types
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

function M.describe(params)
  ---@type lsp.ResponseError?, CfnLspStacksResult?
  local err, result = rpc.request("aws/cfn/stacks/describe", params or {})
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

return M
