local M = {}

local rpc = require("cfn.lib.lsp._rpc")

---@class CfnLspStacksParams
---@field statusToInclude? string[]
---@field statusToExclude? string[]
---@field loadMore? boolean

---@class CfnLspStackSummary
---@field StackName string
---@field StackStatus string

---@class CfnLspStacksResult
---@field stacks CfnLspStackSummary[]
---@field nextToken? string

---@param params? CfnLspStacksParams
---@return string? err
---@return CfnLspStacksResult? result
function M.stacks(params)
  ---@type lsp.ResponseError?, CfnLspStacksResult?
  local err, result = rpc.request("aws/cfn/stacks", params or {})
  if err or result == nil then
    return err and err.message or "no result", nil
  end
  return nil, result
end

---@param params? CfnLspStacksParams
---@return string? err
---@return CfnLspStackSummary[]? stacks
function M.stacks_all(params)
  local all = {}
  local err, page = M.stacks(params)
  if err or page == nil then
    return err or "no result from LSP method", nil
  end
  for _, stack in ipairs(page.stacks) do
    table.insert(all, stack)
  end
  while page.nextToken do
    err, page = M.stacks({ loadMore = true })
    if err or page == nil then
      return err or "no result from LSP method", nil
    end
    for _, s in ipairs(page.stacks) do
      table.insert(all, s)
    end
  end
  return nil, all
end

return M
