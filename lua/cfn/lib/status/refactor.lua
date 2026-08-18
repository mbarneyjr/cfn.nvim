local M = {}

local state = require("cfn.lib.state")

---@type StatusWindowDataHandler
function M.get_status_window_data(content, highlights, _)
  local refactor_operation = state.refactor_operation:get("main")
  if refactor_operation == nil or #refactor_operation.mappings == 0 then
    return
  end

  table.insert(content, "")

  local title = "current stack refactor:"
  table.insert(highlights, {
    line = #content,
    col_start = 0,
    col_end = #title,
    hl_group = "Label",
  })
  table.insert(content, title)

  for _, mapping in ipairs(refactor_operation.mappings) do
    local current_line_number = #content
    local line_content = "  "

    local source = mapping.source.stack_name .. ":" .. mapping.source.logical_id
    -- table.insert(highlights, {
    --   line = current_line_number,
    --   col_start = #line_content,
    --   col_end = #line_content + #mapping.source.stack_name,
    --   hl_group = "Normal",
    -- })
    table.insert(highlights, {
      line = current_line_number,
      col_start = #line_content + #mapping.source.stack_name + 1,
      col_end = #line_content + #source,
      hl_group = "String",
    })
    line_content = line_content .. source

    -- table.insert(highlights, {
    --   line = current_line_number,
    --   col_start = #line_content,
    --   col_end = #line_content + 4,
    --   hl_group = "Normal",
    -- })
    line_content = line_content .. " -> "

    local destination = mapping.destination.stack_name .. ":" .. mapping.destination.logical_id
    -- table.insert(highlights, {
    --   line = current_line_number,
    --   col_start = #line_content,
    --   col_end = #line_content + #mapping.destination.stack_name,
    --   hl_group = "Normal",
    -- })
    table.insert(highlights, {
      line = current_line_number,
      col_start = #line_content + #mapping.destination.stack_name + 1,
      col_end = #line_content + #destination,
      hl_group = "String",
    })
    line_content = line_content .. destination

    table.insert(content, line_content)
  end
end

return M
