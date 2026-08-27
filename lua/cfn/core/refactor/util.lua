local M = {}

local cli = require("cfn.lib.cli")
local progress = require("cfn.lib.progress")
local sleep = require("cfn.lib.sleep")
local state = require("cfn.lib.state")
local util = require("cfn.lib.util")

---@param refactor_operation RefactorMappingRegistration
---@return string? err
---@return TemplateRegistration? registration
function M.get_registration(refactor_operation)
  ---@type TemplateRegistration?
  local result
  for _, stack_definition in ipairs(refactor_operation.stack_definitions) do
    local registration = state.template_registration:get(stack_definition.template_path)
    if registration == nil then
      return "template is not registered: " .. stack_definition.template_path, nil
    end
    if result ~= nil and (result.profile ~= registration.profile or result.region ~= registration.region) then
      return "all stacks in a refactor must use the same profile and region", nil
    end
    result = registration
  end
  return nil, result
end

---@param refactor_operation RefactorMappingRegistration
---@return string? template_path the first template with unsaved changes
function M.unsaved_template(refactor_operation)
  ---@type { [string]: boolean }
  local modified = {}
  for _, buffer in ipairs(vim.fn.getbufinfo({ bufmodified = 1 })) do
    modified[buffer.name] = true
  end
  for _, stack_definition in ipairs(refactor_operation.stack_definitions) do
    if modified[stack_definition.template_path] then
      return stack_definition.template_path
    end
  end
end

---@param active_refactor ActiveRefactor
---@param message string the operation name, for example `stack refactor creation`
---@param complete string the status that means the operation succeeded
---@param select fun(described: CliRefactorDescribeResult): string, string? the status to wait on, and its reason
---@return boolean success
function M.wait(active_refactor, message, complete, select)
  local progress_report = progress.send(message .. " in progress", true, {
    title = active_refactor.stack_refactor_id,
    status = "running",
  })
  while true do
    local err, described =
      cli.refactor.describe(active_refactor.profile, active_refactor.region, active_refactor.stack_refactor_id)
    if err ~= nil or described == nil then
      progress_report.status = "failed"
      progress.send("error checking stack refactor status: " .. (err or "no result from cli"), true, progress_report)
      return false
    end
    local status, reason = select(described)
    if status ~= "AVAILABLE" and not status:find("_IN_PROGRESS$") then
      if status ~= complete then
        progress_report.status = "failed"
        progress.send(message .. " failed: " .. (reason or status), true, progress_report)
        return false
      end
      progress_report.status = "success"
      progress.send(message .. " complete", true, progress_report)
      return true
    end
    sleep.sleep(1000)
  end
end

---@param stack_name string
---@param refactor_operation RefactorMappingRegistration
---@return boolean
function M.stack_is_defined_in_refactor(stack_name, refactor_operation)
  if refactor_operation == nil then
    return false
  end
  for _, stack_definition in ipairs(refactor_operation.stack_definitions) do
    if stack_definition.stack_name == stack_name then
      return true
    end
  end
  return false
end

---@param a RefactorResourceMappingLocation
---@param b RefactorResourceMappingLocation
function M.locations_equal(a, b)
  return a.stack_name == b.stack_name and a.logical_id == b.logical_id
end

---@param refactor_operation RefactorMappingRegistration
function M.remove_unused_stack_definitions(refactor_operation)
  local used = {}
  for _, mapping in ipairs(refactor_operation.mappings) do
    used[mapping.source.stack_name] = true
    used[mapping.destination.stack_name] = true
  end
  for i = #refactor_operation.stack_definitions, 1, -1 do
    local stack_definition = refactor_operation.stack_definitions[i]
    if stack_definition.inferred and not used[stack_definition.stack_name] then
      table.remove(refactor_operation.stack_definitions, i)
    end
  end
end

---@param new_mapping RefactorResourceMapping
---@param refactor_operation RefactorMappingRegistration
---@return string? err
function M.reconcile_move(new_mapping, refactor_operation)
  -- move from source to destination location
  if M.locations_equal(new_mapping.source, new_mapping.destination) then
    return "source and destination are the same location: "
      .. new_mapping.source.stack_name
      .. ":"
      .. new_mapping.source.logical_id
  end

  local override_index = nil
  local override_count = 0
  local destination_collision = false
  for i, mapping in ipairs(refactor_operation.mappings) do
    if
      M.locations_equal(new_mapping.source, mapping.source)
      or M.locations_equal(new_mapping.source, mapping.destination)
    then
      override_index = i
      override_count = override_count + 1
    elseif M.locations_equal(new_mapping.destination, mapping.destination) then
      destination_collision = true
    end
  end

  if override_count > 1 then
    return "ambiguous move: "
      .. new_mapping.source.stack_name
      .. ":"
      .. new_mapping.source.logical_id
      .. " matches multiple pending mappings, cannot determine which to redirect"
  end

  if destination_collision then
    return "destination already exists in refactor operation: "
      .. new_mapping.destination.stack_name
      .. ":"
      .. new_mapping.destination.logical_id
  end
  local source_path = util.state.get_template_path_from_stack(new_mapping.source.stack_name)
  if not source_path then
    return "source stack is not registered: " .. new_mapping.source.stack_name
  end
  local destination_path = util.state.get_template_path_from_stack(new_mapping.destination.stack_name)
  if not destination_path then
    return "destination stack is not registered: " .. new_mapping.destination.stack_name
  end

  state.active_refactor:remove("main")

  if override_index ~= nil then
    local existing = refactor_operation.mappings[override_index]
    if M.locations_equal(existing.source, new_mapping.destination) then
      table.remove(refactor_operation.mappings, override_index)
      M.remove_unused_stack_definitions(refactor_operation)
      return
    end
    existing.destination = new_mapping.destination
    M.remove_unused_stack_definitions(refactor_operation)
  else
    table.insert(refactor_operation.mappings, new_mapping)
  end

  if not M.stack_is_defined_in_refactor(new_mapping.source.stack_name, refactor_operation) then
    table.insert(refactor_operation.stack_definitions, {
      stack_name = new_mapping.source.stack_name,
      template_path = source_path,
      inferred = true,
    })
  end
  if not M.stack_is_defined_in_refactor(new_mapping.destination.stack_name, refactor_operation) then
    table.insert(refactor_operation.stack_definitions, {
      stack_name = new_mapping.destination.stack_name,
      template_path = destination_path,
      inferred = true,
    })
  end
end

return M
