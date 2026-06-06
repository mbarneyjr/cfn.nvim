local M = {}

---@param msg string
function M.error(msg)
  vim.notify("cfn.nvim: " .. msg, vim.log.levels.ERROR)
end

---@param msg string
function M.warn(msg)
  vim.notify("cfn.nvim: " .. msg, vim.log.levels.WARN)
end

---@param msg string
function M.info(msg)
  vim.notify("cfn.nvim: " .. msg, vim.log.levels.INFO)
end

---@param msg string
function M.debug(msg)
  vim.notify("cfn.nvim: " .. msg, vim.log.levels.DEBUG)
end

return M
