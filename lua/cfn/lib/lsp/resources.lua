local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@class CfnLspListResourcesRequest
---@field resourceType string e.g. "AWS::EC2::VPC"
---@field nextToken? string
---@class CfnLspResourceList
---@field typeName string
---@field resourceIdentifiers string[]
---@field nextToken? string
---@class CfnLspListResourcesResult
---@field resources CfnLspResourceList[]

---@param resources CfnLspListResourcesRequest[]
---@return string? err
---@return CfnLspListResourcesResult? result
function M.list_resources(resources)
  ---@type lsp.ResponseError?, CfnLspListResourcesResult?
  local err, result = rpc.request("aws/cfn/resources/list", { resources = resources })
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@param resources CfnLspListResourcesRequest[]
---@return string? err
---@return CfnLspResourceList[]? resources
function M.list_resources_all(resources)
  local all = {}
  local by_type = {}
  local pending = resources
  while #pending > 0 do
    local err, page = M.list_resources(pending)
    if err or page == nil then
      return err or "no result from LSP method", nil
    end
    pending = {}
    for _, res in ipairs(page.resources) do
      local agg = by_type[res.typeName]
      if not agg then
        agg = { typeName = res.typeName, resourceIdentifiers = {} }
        by_type[res.typeName] = agg
        table.insert(all, agg)
      end
      vim.list_extend(agg.resourceIdentifiers, res.resourceIdentifiers)
      if res.nextToken then
        table.insert(pending, { resourceType = res.typeName, nextToken = res.nextToken })
      end
    end
  end
  return nil, all
end

---@class CfnLspResourceTypesResult
---@field resourceTypes string[]

---@return string? err
---@return CfnLspResourceTypesResult? result
function M.resource_types()
  ---@type lsp.ResponseError?, CfnLspResourceTypesResult?
  local err, result = rpc.request("aws/cfn/resources/types", vim.empty_dict())
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspResourceSelection
---@field resourceType string
---@field resourceIdentifiers string[]
---@class CfnLspResourceStateParams
---@field textDocument lsp.TextDocumentIdentifier
---@field resourceSelections CfnLspResourceSelection[]
---@field purpose "Import" | "Clone"
---@field parentResourceType? string
---@class CfnLspResourceStateResult
---@field completionItem? lsp.CompletionItem
---@field successfulImports table<string, string[]>
---@field failedImports table<string, string[]>
---@field failureReasons? table<string, table<string, string>>
---@field warning? string

---@param params CfnLspResourceStateParams
---@return string? err
---@return CfnLspResourceStateResult? result
function M.resource_state(params)
  ---@type lsp.ResponseError?, CfnLspResourceStateResult?
  local err, result = rpc.request("aws/cfn/resources/state", params)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspResourceStackManagementResult
---@field physicalResourceId string
---@field managedByStack boolean?
---@field stackName? string
---@field stackId? string
---@field error? string

---@param physical_resource_id string
---@return string? err
---@return CfnLspResourceStackManagementResult? result
function M.stack_mgmt_info(physical_resource_id)
  ---@type lsp.ResponseError?, CfnLspResourceStackManagementResult?
  local err, result = rpc.request("aws/cfn/resources/stackMgmtInfo", physical_resource_id)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

return M
