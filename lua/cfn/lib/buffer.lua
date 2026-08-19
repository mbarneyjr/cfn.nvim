local M = {}

local config = require("cfn.lib.config")

---@param bufnr? number
---@return string? err
---@return string? path
function M.get_current_buffer_template_path(bufnr)
  if bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  if string.find(filetype, "yaml") == nil and string.find(filetype, "json") == nil then
    return "buffer is not a yaml or json file", nil
  end
  if #vim.lsp.get_clients({ bufnr = bufnr, name = config.options.lsp_client_name }) == 0 then
    return "LSP client '" .. config.options.lsp_client_name .. "' is not attached"
  end
  local template_path = vim.api.nvim_buf_get_name(bufnr)
  if template_path == "" then
    return "buffer has no file path", nil
  end
  return nil, template_path
end

return M
