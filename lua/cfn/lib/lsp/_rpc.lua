local M = {}

local config = require("cfn.lib.config")

function M.client()
  return vim.lsp.get_clients({ name = config.options.lsp_client_name })[1]
end

---@param method string
---@param payload any
---@return lsp.ResponseError?
---@return any
function M.request(method, payload)
  local co = assert(coroutine.running(), "cfn.lib.lsp functions must be called from a coroutine")
  local client = M.client()
  if not client then
    return { code = 0, message = "no active LSP client found with name " .. config.options.lsp_client_name }, nil
  end
  local bufnr = vim.api.nvim_get_current_buf()
  client:request(method, payload, function(err, result)
    vim.schedule(function()
      coroutine.resume(co, err, result)
    end)
  end, bufnr)
  return coroutine.yield()
end

---@param method string
---@param payload? table
---@return string?
function M.notify(method, payload)
  local client = M.client()
  if not client then
    return "failed to send notification: no active LSP client found with name " .. config.options.lsp_client_name
  end
  if client:notify(method, payload) == false then
    return "failed to send notification"
  end
  return nil
end

return M
