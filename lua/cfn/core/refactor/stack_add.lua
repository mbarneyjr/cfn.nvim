local M = {}

local notify = require("cfn.lib.notify")
local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")
local ui = require("cfn.lib.ui")
local refactor_util = require("cfn.core.refactor.util")

---@return string? template_path
---@return TemplateRegistration? registration
local function resolve_current_registration()
  local template_path_err, template_path = buffer.get_current_buffer_template_path()
  if template_path_err ~= nil or not template_path then
    return nil, nil
  end
  return template_path, state.template_registration:get(template_path)
end

function M.add_stack()
  coroutine.wrap(function()
    local refactor_operation = state.refactor_operation:get("main") or { mappings = {}, stack_definitions = {} }

    local template_path, registration = resolve_current_registration()
    if registration == nil then
      ---@type { template_path: string, registration: TemplateRegistration }[]
      local candidates = {}
      for path, candidate_registration in pairs(state.template_registration:list()) do
        if not refactor_util.stack_is_defined_in_refactor(candidate_registration.stack_name, refactor_operation) then
          table.insert(candidates, { template_path = path, registration = candidate_registration })
        end
      end
      if #candidates == 0 then
        return notify.error("no registered stacks available to add")
      end
      local chosen = ui.select(candidates, {
        prompt = "Choose a registered stack to add to the refactor",
        format_item = function(item)
          return item.registration.stack_name
        end,
      })
      if chosen == nil then
        return notify.error("no stack chosen")
      end
      template_path = chosen.template_path
      registration = chosen.registration
    end

    if refactor_util.stack_is_defined_in_refactor(registration.stack_name, refactor_operation) then
      return notify.warn("stack is already part of the refactor: " .. registration.stack_name)
    end

    if #refactor_operation.stack_definitions > 0 then
      local existing_err, existing_registration = refactor_util.get_registration(refactor_operation)
      if existing_err ~= nil then
        return notify.error(existing_err)
      end
      if
        existing_registration ~= nil
        and (
          existing_registration.profile ~= registration.profile
          or existing_registration.region ~= registration.region
        )
      then
        return notify.error("all stacks in a refactor must use the same profile and region")
      end
    end

    table.insert(refactor_operation.stack_definitions, {
      stack_name = registration.stack_name,
      template_path = template_path,
    })
    state.refactor_operation:set("main", refactor_operation)
    notify.info("added stack to refactor: " .. registration.stack_name)
  end)()
end

return M
