local M = {}

---@type StatusWindowDataHandler
function M.get_status_window_data(content, highlights, _)
  local title = "cfn.nvim status window"
  table.insert(highlights, {
    line = #content,
    col_start = 0,
    col_end = #title,
    hl_group = "Title",
  })
  table.insert(content, title)

  local help = "keys: > to open, < to close, <CR> to enter"
  table.insert(highlights, {
    line = #content,
    col_start = 0,
    col_end = #help,
    hl_group = "Comment",
  })
  table.insert(content, help)
  table.insert(content, "")
end

return M
