local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@class CfnLspTemplateResource
---@field logicalId string
---@field type string
---@field primaryIdentifierKeys? string[]
---@field primaryIdentifier? table<string, string>
---@class CfnLspTemplateResourcesResult
---@field resources CfnLspTemplateResource[]

---@param uri string
---@return string? err
---@return CfnLspTemplateResourcesResult? result
function M.import_resources(uri)
  ---@type lsp.ResponseError?, CfnLspTemplateResourcesResult?
  local err, result = rpc.request("aws/cfn/stack/import/resources", uri)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

return M
