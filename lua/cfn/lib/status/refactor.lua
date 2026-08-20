local M = {}

local state = require("cfn.lib.state")
local arrow = require("cfn.lib.status.builder").arrow

---@type { [string]: boolean }
local open_sections = { stack_refactor = true, stack_definitions = true, resource_mappings = true }

---@type StatusWindowDataHandler
function M.get_status_window_data(builder)
  local refactor_operation = state.refactor_operation:get("main")
  if
    refactor_operation == nil or (#refactor_operation.mappings == 0 and #refactor_operation.stack_definitions == 0)
  then
    return
  end
  builder:line({})

  local active_refactor = state.active_refactor:get("main")
  builder:line({
    { arrow(open_sections.stack_refactor) .. " " },
    { "stack refactor:", "Label" },
    { active_refactor and (" (" .. active_refactor.stack_refactor_id .. ")") or "", "Comment" },
  }, {
    open = function()
      open_sections.stack_refactor = true
    end,
    close = function()
      open_sections.stack_refactor = false
    end,
  })
  if not open_sections.stack_refactor then
    return
  end

  if #refactor_operation.stack_definitions > 0 then
    builder:line({
      { "  " .. arrow(open_sections.stack_definitions) .. " " },
      { "stack definitions:" },
      {
        open_sections.stack_definitions and "" or " (" .. #refactor_operation.stack_definitions .. ")",
        "Comment",
      },
    }, {
      open = function()
        open_sections.stack_definitions = true
      end,
      close = function()
        open_sections.stack_definitions = false
      end,
    })
    if open_sections.stack_definitions then
      for _, stack_definition in ipairs(refactor_operation.stack_definitions) do
        builder:line({
          { "      " .. stack_definition.stack_name .. " ", "String" },
          { "(" .. stack_definition.template_path .. ")", "Comment" },
        })
      end
    end
  end

  if #refactor_operation.mappings > 0 then
    builder:line({
      { "  " .. arrow(open_sections.resource_mappings) .. " " },
      { "resource mappings:" },
      { open_sections.resource_mappings and "" or " (" .. #refactor_operation.mappings .. ")", "Comment" },
    }, {
      open = function()
        open_sections.resource_mappings = true
      end,
      close = function()
        open_sections.resource_mappings = false
      end,
    })
    if open_sections.resource_mappings then
      for _, mapping in ipairs(refactor_operation.mappings) do
        builder:line({
          { "      " .. mapping.source.stack_name .. ":" },
          { mapping.source.logical_id, "String" },
          { " -> " .. mapping.destination.stack_name .. ":" },
          { mapping.destination.logical_id, "String" },
          { mapping.inferred and " (inferred)" or "", "Comment" },
        })
      end
    end
  end
end

return M
