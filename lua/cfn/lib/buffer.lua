local M = {}

---@return string? err
---@return string? path
function M.get_current_buffer_template_path()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  if string.find(filetype, "yaml") == nil and string.find(filetype, "json") == nil then
    return "buffer is not a yaml or json file", nil
  end
  local template_path = vim.api.nvim_buf_get_name(bufnr)
  if template_path == "" then
    return "buffer has no file path", nil
  end
  return nil, template_path
end

return M
