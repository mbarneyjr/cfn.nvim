local M = {}

local lsp = require("cfn.lib.lsp")
local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local credentials = require("cfn.lib.credentials")
local buffer = require("cfn.lib.buffer")
local ui = require("cfn.lib.ui")
local treesitter = require("cfn.lib.treesitter")

---@param a table<string, string>
---@param b table<string, string>
local function resource_identifiers_equal(a, b)
  for a_key, a_value in pairs(a) do
    if b[a_key] ~= a_value then
      return false
    end
  end
  for b_key, b_value in pairs(b) do
    if a[b_key] ~= b_value then
      return false
    end
  end
  return true
end

function M.import()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local template_path_err, template_path = buffer.get_current_buffer_template_path(bufnr)
    if template_path_err ~= nil or not template_path then
      return notify.error("cannot import resource in template: " .. (template_path_err or "no template path"))
    end
    local template_registration = state.template_registration:get(template_path)
    if template_registration == nil then
      return notify.error("current template is not registered, please run :Cfn template register")
    end
    if credentials.current_profile() ~= template_registration.profile then
      credentials.set(template_registration.profile)
    end

    local resources_to_import_registration = state.resources_to_import:get(template_path)
    if resources_to_import_registration == nil then
      resources_to_import_registration = {
        resources = {},
      }
    end

    local resource = treesitter.resource_at_cursor(bufnr)
    if resource == nil then
      return notify.error("no resource found under cursor")
    end

    local stack_resources_err, stack_resources = lsp.stack.resources_all({
      stackName = template_registration.stack_name,
    })
    if stack_resources_err ~= nil then
      if not stack_resources_err:find("Stack with id " .. template_registration.stack_name .. " does not exist") then
        return notify.error("cannot get stack resources: " .. stack_resources_err)
      end
    end
    for _, stack_resource in ipairs(stack_resources or {}) do
      if stack_resource.LogicalResourceId == resource.logical_id.name then
        return notify.error("resource is already part of the stack and cannot be imported")
      end
    end

    local importable_resources_err, importable_resources =
      lsp.import.import_resources(vim.uri_from_fname(template_path))
    if importable_resources_err ~= nil or importable_resources == nil then
      return notify.error("error getting importable resources: " .. (importable_resources_err or "no result from lsp"))
    end
    ---@type CfnLspTemplateResource?
    local importable_resource = nil
    for _, importable in ipairs(importable_resources.resources) do
      if importable.logicalId == resource.logical_id.name then
        importable_resource = importable
        break
      end
    end
    if importable_resource == nil then
      return notify.error("resource " .. resource.logical_id.name .. " is not importable")
    end
    local resources_err, resources = lsp.resources.list_resources_all({ { resourceType = resource.type } })
    if resources_err ~= nil or resources == nil or #resources < 1 then
      return notify.error("cannot list " .. resource.type .. " " .. (resources_err or "no result from lsp"))
    end

    ---@type { [string]: string }
    local resource_identifier_table = {}
    ---@type string
    local resource_identifier_string = ""
    if #resources[1].resourceIdentifiers < 1 then
      for _, key in ipairs(importable_resource.primaryIdentifierKeys or {}) do
        local resource_identifier = ui.input({
          prompt = "Please enter the "
            .. key
            .. " for "
            .. importable_resource.logicalId
            .. " ("
            .. importable_resource.type
            .. ")",
        })
        if resource_identifier == nil then
          return notify.error("no resource identifier provided for " .. importable_resource.logicalId)
        end
        resource_identifier_table[key] = resource_identifier
        if #resource_identifier_string == 0 then
          resource_identifier_string = resource_identifier
        else
          resource_identifier_string = resource_identifier_string .. "|" .. resource_identifier
        end
      end
    else
      local chosen_identifier = ui.select(resources[1].resourceIdentifiers, {
        prompt = "Please select the resource to import to " .. importable_resource.logicalId,
        format_item = function(item)
          return item
        end,
      })
      if chosen_identifier == nil then
        return notify.error("no resource identifier selected for " .. importable_resource.logicalId)
      end
      resource_identifier_string = chosen_identifier
      local chosen_identifier_split = vim.split(chosen_identifier, "|")
      for i, key in ipairs(importable_resource.primaryIdentifierKeys or {}) do
        resource_identifier_table[key] = chosen_identifier_split[i]
      end
    end
    local resource_to_import = {
      ResourceType = importable_resource.type,
      LogicalResourceId = importable_resource.logicalId,
      ResourceIdentifier = resource_identifier_table,
    }

    local stack_mgmt_err, stack_mgmt_info = lsp.resources.stack_mgmt_info(resource_identifier_string)
    if stack_mgmt_err ~= nil or stack_mgmt_info == nil then
      return notify.error("cannot get stack management info for resource: " .. (stack_mgmt_err or "no result from lsp"))
    end
    if stack_mgmt_info.managedByStack == true then
      return notify.error("resource is already managed by another stack: " .. (stack_mgmt_info.stackName or "unknown"))
    end

    local already_imported = false
    for i, resource_search in pairs(resources_to_import_registration.resources or {}) do
      if
        resource_search.ResourceType == resource_to_import.ResourceType
        and resource_identifiers_equal(resource_search.ResourceIdentifier, resource_to_import.ResourceIdentifier)
        and resource_search.LogicalResourceId ~= resource_to_import.LogicalResourceId
      then
        return notify.error(
          "resource " .. resource_search.LogicalResourceId .. " is already registered to be import this resource"
        )
      end
      if resource_search.LogicalResourceId == resource.logical_id.name then
        resources_to_import_registration.resources[i] = resource_to_import
        already_imported = true
      end
    end
    if not already_imported then
      table.insert(resources_to_import_registration.resources, resource_to_import)
    end

    ui.template_highlight.clear(bufnr)
    for _, resource_to_highlight in ipairs(resources_to_import_registration.resources or {}) do
      local highlight_err = ui.template_highlight.highlight(
        bufnr,
        resource_to_highlight.LogicalResourceId,
        "DiagnosticVirtualTextInfo",
        "Resource to import: " .. vim.fn.json_encode(resource_to_highlight.ResourceIdentifier),
        "Title"
      )
      if highlight_err ~= nil and not highlight_err:find("resource not found for logical id") then
        return notify.error("cannot highlight resource: " .. highlight_err)
      end
    end
    state.resources_to_import:set(template_path, resources_to_import_registration)
  end)()
end

return M
