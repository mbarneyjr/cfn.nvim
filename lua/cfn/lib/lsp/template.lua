local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@class CfnLspTemplateArtifact
---@field resourceType string
---@field filePath string
---@class CfnLspTemplateArtifactsResult
---@field artifacts CfnLspTemplateArtifact[]

---@param uri string
---@return string? err
---@return CfnLspTemplateArtifactsResult? result
function M.artifacts(uri)
  ---@type lsp.ResponseError?, CfnLspTemplateArtifactsResult?
  local err, result = rpc.request("aws/cfn/stack/template/artifacts", uri)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@class CfnLspAuthoredResource
---@field logicalId string
---@field type string

---@param uri string
---@return string? err
---@return CfnLspAuthoredResource[]? resources
function M.authored_resources(uri)
  ---@type lsp.ResponseError?, CfnLspAuthoredResource[]?
  local err, result = rpc.request("aws/cfn/template/resources/authored/v2", uri)
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

return M
