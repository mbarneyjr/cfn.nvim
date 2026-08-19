local M = {}

local notify = require("cfn.lib.notify")
local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")
local ui = require("cfn.lib.ui")

function M.remove_stack()
  coroutine.wrap(function()
    local refactor_operation = state.refactor_operation:get("main")
    if refactor_operation == nil or #refactor_operation.stack_definitions == 0 then
      return notify.warn("no stack definitions in the current refactor")
    end

    ---@type RefactorStackDefinition?
    local chosen

    local template_path_err, template_path = buffer.get_current_buffer_template_path()
    if template_path_err == nil and template_path ~= nil then
      local registration = state.template_registration:get(template_path)
      if registration ~= nil then
        for _, stack_definition in ipairs(refactor_operation.stack_definitions) do
          if stack_definition.stack_name == registration.stack_name then
            chosen = stack_definition
            break
          end
        end
      end
    end

    if chosen == nil then
      chosen = ui.select(refactor_operation.stack_definitions, {
        prompt = "Choose a stack to remove from the refactor",
        format_item = function(item)
          return item.stack_name
        end,
      })
      if chosen == nil then
        return notify.error("no stack chosen")
      end
    end

    for _, mapping in ipairs(refactor_operation.mappings) do
      if mapping.source.stack_name == chosen.stack_name or mapping.destination.stack_name == chosen.stack_name then
        return notify.error("stack is referenced by a mapping, cannot remove: " .. chosen.stack_name)
      end
    end

    for i, stack_definition in ipairs(refactor_operation.stack_definitions) do
      if stack_definition.stack_name == chosen.stack_name then
        table.remove(refactor_operation.stack_definitions, i)
        break
      end
    end

    state.refactor_operation:set("main", refactor_operation)
    notify.info("removed stack from refactor: " .. chosen.stack_name)
  end)()
end

return M
