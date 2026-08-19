local M = {}

---@type StatusWindowDataHandler
function M.get_status_window_data(builder)
  builder:line({ { "cfn.nvim status window", "Title" } })
  builder:line({ { "keys: > to open, < to close, <CR> to enter", "Comment" } })
  builder:line({})
end

return M
