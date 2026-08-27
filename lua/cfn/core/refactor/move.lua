local M = {}

local notify = require("cfn.lib.notify")
local treesitter = require("cfn.lib.treesitter")
local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")
local lsp = require("cfn.lib.lsp")
local ui = require("cfn.lib.ui")
local credentials = require("cfn.lib.credentials")
local util = require("cfn.lib.util")
local refactor_util = require("cfn.core.refactor.util")

---@param prompt_message string
---@param current_registration TemplateRegistration
local function select_stack_registration(prompt_message, current_registration)
  local response = state.template_registration:list()
  ---@type { template_path: string, registration: TemplateRegistration }[]
  local registrations = {}
  for path, registration in pairs(response) do
    if registration.profile == current_registration.profile and registration.region == current_registration.region then
      table.insert(registrations, { registration = registration, template_path = path })
    end
  end
  local result = ui.select(registrations, {
    prompt = prompt_message,
    format_item = function(item)
      return item.registration.stack_name
    end,
  })
  return result
end

---@param stack_name string
---@param resource_type string
---@return string? err
---@return string? logical_id
local function select_resource(stack_name, resource_type)
  local err, stack_resources = lsp.stack.resources_all({ stackName = stack_name })
  if err ~= nil then
    if not err:find("Stack with id " .. stack_name .. " does not exist", 1, true) then
      return "could not list resources for stack " .. stack_name .. ": " .. (err or "no result")
    end
  end
  ---@type CfnLspStackResourceSummary[]
  local filtered_resources = {}
  for _, resource in ipairs(stack_resources or {}) do
    if resource.ResourceType == resource_type then
      table.insert(filtered_resources, resource)
    end
  end
  if #filtered_resources == 0 then
    return "no resources of type " .. resource_type .. " found in stack " .. stack_name
  end
  local picked = ui.select(filtered_resources, {
    prompt = "Choose a resource from stack " .. stack_name,
    format_item = function(item)
      return item.LogicalResourceId .. " [" .. item.PhysicalResourceId .. "]"
    end,
  })
  if picked == nil then
    return "no resource chosen"
  end
  return nil, picked.LogicalResourceId
end

function M.move()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local template_path_err, template_path = buffer.get_current_buffer_template_path(bufnr)
    if template_path_err ~= nil or not template_path then
      return notify.error("cannot move resource: " .. (template_path_err or "no template path"))
    end
    local registration = state.template_registration:get(template_path)
    if registration == nil then
      return notify.error("current template is not registered, please run :Cfn template register")
    end
    credentials.set(registration.profile, registration.region)
    local refactor_operation = state.refactor_operation:get("main")
    if refactor_operation == nil then
      refactor_operation = {
        mappings = {},
        stack_definitions = {},
      }
    end

    local resource_at_cursor = treesitter.resource_at_cursor(bufnr)
    if resource_at_cursor == nil then
      return notify.error("no resource found under cursor")
    end

    local resource_exists_err, resource_exists_in_current_stack =
      util.cfn.resource_exists_in_stack(registration.stack_name, resource_at_cursor.logical_id.name, refactor_operation)
    if resource_exists_err ~= nil or resource_exists_in_current_stack == nil then
      return notify.error(resource_exists_err or "could not check if resource exists in stack")
    end
    ---@type RefactorResourceMapping
    local mapping
    if resource_exists_in_current_stack then
      -- resource exists in the current stack, we're moving the resource FROM here, prompt for a destination location
      local destination_stack = select_stack_registration("Choose a registered stack for the destination", registration)
      if destination_stack == nil then
        return notify.error("no destination stack chosen")
      end
      local destination_logical_id = ui.input({
        default = resource_at_cursor.logical_id.name,
        prompt = "Enter the target logical ID",
      })
      if destination_logical_id == nil or destination_logical_id == "" then
        destination_logical_id = resource_at_cursor.logical_id.name
      end

      mapping = {
        source = {
          stack_name = registration.stack_name,
          logical_id = resource_at_cursor.logical_id.name,
        },
        destination = {
          stack_name = destination_stack.registration.stack_name,
          logical_id = destination_logical_id,
        },
      }
      local reconcile_err = refactor_util.reconcile_move(mapping, refactor_operation)
      if reconcile_err ~= nil then
        return notify.error("failed to reconcile move operation: " .. reconcile_err)
      end
    else
      local source_stack = select_stack_registration("Choose a registered stack for the source", registration)
      if source_stack == nil then
        return notify.error("no source stack chosen")
      end
      local resource_err, source_resource =
        select_resource(source_stack.registration.stack_name, resource_at_cursor.type)
      if resource_err ~= nil or source_resource == nil then
        return notify.error(resource_err or "no source resource chosen")
      end
      mapping = {
        source = {
          stack_name = source_stack.registration.stack_name,
          logical_id = source_resource,
        },
        destination = {
          stack_name = registration.stack_name,
          logical_id = resource_at_cursor.logical_id.name,
        },
      }
      local reconcile_err = refactor_util.reconcile_move(mapping, refactor_operation)
      if reconcile_err ~= nil then
        return notify.error("failed to reconcile move operation: " .. reconcile_err)
      end
    end
    state.refactor_operation:set("main", refactor_operation)
    notify.info(
      ("move %s:%s to %s:%s"):format(
        mapping.source.stack_name,
        mapping.source.logical_id,
        mapping.destination.stack_name,
        mapping.destination.logical_id
      )
    )
  end)()
end

return M
