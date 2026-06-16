local M = {}

---@param node TSNode
---@return BufferRange
function M.node_to_range(node)
  local start_row, start_col, end_row, end_col = node:range()
  return {
    start_pos = { line = start_row, character = start_col },
    end_pos = { line = end_row, character = end_col },
  }
end

return M
