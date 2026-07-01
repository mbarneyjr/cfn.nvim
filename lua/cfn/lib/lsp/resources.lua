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

return M
