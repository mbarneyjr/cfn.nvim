local M = {}

local lsp = require("cfn.lib.lsp")

M.UNAVAILABLE_STACK_STATUSES = {
  "CREATE_FAILED",
  "ROLLBACK_FAILED",
  "ROLLBACK_COMPLETE",
  "DELETE_FAILED",
  "DELETE_COMPLETE",
  "UPDATE_FAILED",
  "UPDATE_ROLLBACK_FAILED",
  "IMPORT_ROLLBACK_FAILED",
}

---@param stack_name string
---@param logical_id string
---@param refactor_operation RefactorMappingRegistration? specify this if you want to check pending refactor moves
---@return string? err
---@return boolean?
function M.resource_exists_in_stack(stack_name, logical_id, refactor_operation)
  if refactor_operation ~= nil then
    for _, mapping in ipairs(refactor_operation.mappings or {}) do
      if mapping.source.stack_name == stack_name and mapping.source.logical_id == logical_id then
        return nil, false
      end
      if mapping.destination.stack_name == stack_name and mapping.destination.logical_id == logical_id then
        return nil, true
      end
    end
  end

  local stack_resources_err, stack_resources = lsp.stack.resources_all({ stackName = stack_name })
  if stack_resources_err ~= nil then
    if not stack_resources_err:find("Stack with id " .. stack_name .. " does not exist") then
      return "cannot get stack resources: " .. stack_resources_err, nil
    end
  end
  for _, stack_resource in ipairs(stack_resources or {}) do
    if stack_resource.LogicalResourceId == logical_id then
      return nil, true
    end
  end

  return nil, false
end

return M
