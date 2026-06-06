local M = {
  iam = {},
}

local rpc = require("cfn.lib.lsp._rpc")

---@return string?
function M.iam.delete()
  rpc.notify("aws/credentials/iam/delete", nil)
end

---@class CfnLspCredentialsUpdateResult
---@field success boolean

---@param token string
---@return string?
function M.iam.update(token)
  local payload = {
    data = token,
    encrypted = true,
  }
  ---@type lsp.ResponseError?, CfnLspCredentialsUpdateResult?
  local err, result = rpc.request("aws/credentials/iam/update", payload)
  if err or result == nil then
    return err and err.message or "no result from LSP method"
  end
  if not result.success then
    return "lsp returned an unsuccessful result"
  end
  return nil
end

return M
