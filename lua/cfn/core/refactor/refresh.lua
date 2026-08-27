local M = {}

local notify = require("cfn.lib.notify")
local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")
local lsp = require("cfn.lib.lsp")
local credentials = require("cfn.lib.credentials")
local refactor_util = require("cfn.core.refactor.util")

---@class RefactorOrphan
---@field stack_name string
---@field logical_id string
---@field type string

---@class RefactorOrphanPair
---@field source RefactorOrphan
---@field destination RefactorOrphan

---@param stack_definition RefactorStackDefinition
---@return string? err
---@return RefactorOrphan[]? removed deployed, but no longer in the template
---@return RefactorOrphan[]? added in the template, but not deployed
local function diff_stack(stack_definition)
  local load_err = buffer.load_template(stack_definition.template_path)
  if load_err ~= nil then
    return load_err, nil, nil
  end

  local authored_err, authored = lsp.template.authored_resources(vim.uri_from_fname(stack_definition.template_path))
  if authored_err ~= nil or authored == nil then
    return "cannot read template resources: " .. (authored_err or "no result"), nil, nil
  end
  if #authored == 0 then
    return "no resources found in template: " .. stack_definition.template_path, nil, nil
  end

  local deployed_err, deployed = lsp.stack.resources_all({ stackName = stack_definition.stack_name })
  if deployed_err ~= nil then
    if not deployed_err:find("Stack with id " .. stack_definition.stack_name .. " does not exist", 1, true) then
      return "cannot list resources for stack " .. stack_definition.stack_name .. ": " .. deployed_err, nil, nil
    end
  end

  ---@type { [string]: boolean }
  local authored_ids = {}
  ---@type { [string]: boolean }
  local deployed_ids = {}
  ---@type RefactorOrphan[], RefactorOrphan[]
  local removed, added = {}, {}

  for _, resource in ipairs(authored) do
    authored_ids[resource.logicalId] = true
  end
  for _, resource in ipairs(deployed or {}) do
    deployed_ids[resource.LogicalResourceId] = true
    if not authored_ids[resource.LogicalResourceId] then
      table.insert(removed, {
        stack_name = stack_definition.stack_name,
        logical_id = resource.LogicalResourceId,
        type = resource.ResourceType,
      })
    end
  end
  for _, resource in ipairs(authored) do
    if not deployed_ids[resource.logicalId] then
      table.insert(added, {
        stack_name = stack_definition.stack_name,
        logical_id = resource.logicalId,
        type = resource.type,
      })
    end
  end
  return nil, removed, added
end

--- Pair orphans that are alone on both sides of a group. A group with more than
--- one candidate on either side is ambiguous, and its orphans stay unpaired.
---@param removed RefactorOrphan[]
---@param added RefactorOrphan[]
---@param group_key fun(orphan: RefactorOrphan): string
---@return RefactorOrphanPair[] paired
---@return RefactorOrphan[] unpaired_removed
---@return RefactorOrphan[] unpaired_added
local function pair_unique(removed, added, group_key)
  ---@type { [string]: { removed: RefactorOrphan[], added: RefactorOrphan[] } }
  local groups = {}
  ---@param orphans RefactorOrphan[]
  ---@param side "removed"|"added"
  local function collect(orphans, side)
    for _, orphan in ipairs(orphans) do
      local key = group_key(orphan)
      groups[key] = groups[key] or { removed = {}, added = {} }
      table.insert(groups[key][side], orphan)
    end
  end
  collect(removed, "removed")
  collect(added, "added")

  ---@type RefactorOrphanPair[], RefactorOrphan[], RefactorOrphan[]
  local paired, unpaired_removed, unpaired_added = {}, {}, {}
  for _, group in pairs(groups) do
    if #group.removed == 1 and #group.added == 1 then
      table.insert(paired, { source = group.removed[1], destination = group.added[1] })
    else
      vim.list_extend(unpaired_removed, group.removed)
      vim.list_extend(unpaired_added, group.added)
    end
  end
  return paired, unpaired_removed, unpaired_added
end

---@param orphan RefactorOrphan|RefactorResourceMappingLocation
---@return string
local function location_key(orphan)
  return orphan.stack_name .. ":" .. orphan.logical_id
end

---@param removed RefactorOrphan[]
---@param added RefactorOrphan[]
---@return string
local function ambiguous_error(removed, added)
  local lines = {
    ("cannot infer %d resource change(s), resolve them with :Cfn refactor move:"):format(#removed + #added),
  }
  for _, orphan in ipairs(removed) do
    table.insert(lines, ("  - %s [%s] is deployed, but not in the template"):format(location_key(orphan), orphan.type))
  end
  for _, orphan in ipairs(added) do
    table.insert(lines, ("  + %s [%s] is in the template, but not deployed"):format(location_key(orphan), orphan.type))
  end
  return table.concat(lines, "\n")
end

function M.refresh()
  coroutine.wrap(function()
    local refactor_operation = state.refactor_operation:get("main")
    if refactor_operation == nil or #refactor_operation.stack_definitions == 0 then
      return notify.error("no stacks in the refactor, please run :Cfn refactor stack add")
    end

    local registration_err, registration = refactor_util.get_registration(refactor_operation)
    if registration_err ~= nil or registration == nil then
      return notify.error(registration_err or "no registration found")
    end
    credentials.set(registration.profile, registration.region)

    local refreshed = vim.deepcopy(refactor_operation)
    for i = #refreshed.mappings, 1, -1 do
      if refreshed.mappings[i].inferred then
        table.remove(refreshed.mappings, i)
      end
    end

    ---@type { [string]: boolean }
    local claimed = {}
    for _, mapping in ipairs(refreshed.mappings) do
      claimed[location_key(mapping.source)] = true
      claimed[location_key(mapping.destination)] = true
    end

    ---@type RefactorOrphan[], RefactorOrphan[]
    local removed, added = {}, {}
    for _, stack_definition in ipairs(refactor_operation.stack_definitions) do
      local diff_err, stack_removed, stack_added = diff_stack(stack_definition)
      if diff_err ~= nil or stack_removed == nil or stack_added == nil then
        return notify.error(diff_err or ("cannot diff stack " .. stack_definition.stack_name))
      end
      for _, orphan in ipairs(stack_removed) do
        if not claimed[location_key(orphan)] then
          table.insert(removed, orphan)
        end
      end
      for _, orphan in ipairs(stack_added) do
        if not claimed[location_key(orphan)] then
          table.insert(added, orphan)
        end
      end
    end

    ---@type RefactorOrphanPair[], RefactorOrphanPair[]
    local kept_id, renamed

    -- the resource kept its logical id, so the id and the type identify it
    kept_id, removed, added = pair_unique(removed, added, function(orphan)
      return orphan.logical_id .. ":" .. orphan.type
    end)
    -- the resource was renamed, so only the type is left to identify it
    renamed, removed, added = pair_unique(removed, added, function(orphan)
      return orphan.type
    end)

    if #removed > 0 or #added > 0 then
      return notify.error(ambiguous_error(removed, added))
    end

    local inferred = vim.list_extend(kept_id, renamed)
    for _, orphan_pair in ipairs(inferred) do
      local reconcile_err = refactor_util.reconcile_move({
        source = { stack_name = orphan_pair.source.stack_name, logical_id = orphan_pair.source.logical_id },
        destination = {
          stack_name = orphan_pair.destination.stack_name,
          logical_id = orphan_pair.destination.logical_id,
        },
        inferred = true,
      }, refreshed)
      if reconcile_err ~= nil then
        return notify.error("cannot apply inferred move: " .. reconcile_err)
      end
    end

    state.refactor_operation:set("main", refreshed)
    notify.info(("refactor refresh: inferred %d move(s)"):format(#inferred))
  end)()
end

return M
