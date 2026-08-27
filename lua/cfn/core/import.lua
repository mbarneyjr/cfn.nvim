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

---@param bufnr integer
---@param template_path string
---@param resource_to_import CfnLspResourceToImport
---@return string? err
local function register_resource_to_import(bufnr, template_path, resource_to_import)
  local registration = state.resources_to_import:get(template_path) or { resources = {} }

  -- state.resources_to_import:get returns the live table, so reject the request
  -- before anything is written
  for _, registered_import in ipairs(registration.resources or {}) do
    if
      registered_import.ResourceType == resource_to_import.ResourceType
      and resource_identifiers_equal(registered_import.ResourceIdentifier, resource_to_import.ResourceIdentifier)
      and registered_import.LogicalResourceId ~= resource_to_import.LogicalResourceId
    then
      return "resource " .. registered_import.LogicalResourceId .. " is already registered to import this resource"
    end
  end

  local already_imported = false
  for i, registered_import in ipairs(registration.resources or {}) do
    if registered_import.LogicalResourceId == resource_to_import.LogicalResourceId then
      registration.resources[i] = resource_to_import
      already_imported = true
      break
    end
  end
  if not already_imported then
    table.insert(registration.resources, resource_to_import)
  end

  ui.template_highlight.clear(bufnr)
  for _, resource_to_highlight in ipairs(registration.resources or {}) do
    local highlight_err = ui.template_highlight.highlight(
      bufnr,
      resource_to_highlight.LogicalResourceId,
      "DiagnosticVirtualTextInfo",
      "Import: " .. vim.fn.json_encode(resource_to_highlight.ResourceIdentifier),
      "Title"
    )
    if highlight_err ~= nil and not highlight_err:find("resource not found for logical id") then
      return "cannot highlight resource: " .. highlight_err
    end
  end

  state.resources_to_import:set(template_path, registration)
  return nil
end

---@param template_path string
---@param logical_id string
---@return string? err
---@return CfnLspTemplateResource? resource
local function get_importable_resource(template_path, logical_id)
  local err, result = lsp.import.import_resources(vim.uri_from_fname(template_path))
  if err ~= nil or result == nil then
    return "error getting importable resources: " .. (err or "no result from lsp"), nil
  end
  for _, importable in ipairs(result.resources) do
    if importable.logicalId == logical_id then
      return nil, importable
    end
  end
  return "resource " .. logical_id .. " is not importable", nil
end

---@param bufnr integer
---@param template_path string
---@param stack_name string
---@param resource ResourceLocation
local function import_resource_at_cursor(bufnr, template_path, stack_name, resource)
  local stack_resources_err, stack_resources = lsp.stack.resources_all({ stackName = stack_name })
  if stack_resources_err ~= nil then
    if not stack_resources_err:find("Stack with id " .. stack_name .. " does not exist", 1, true) then
      return notify.error("cannot get stack resources: " .. stack_resources_err)
    end
  end
  for _, stack_resource in ipairs(stack_resources or {}) do
    if stack_resource.LogicalResourceId == resource.logical_id.name then
      return notify.error("resource is already part of the stack and cannot be imported")
    end
  end

  local importable_err, importable_resource = get_importable_resource(template_path, resource.logical_id.name)
  if importable_err ~= nil or importable_resource == nil then
    return notify.error(importable_err or "no importable resource")
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

  local stack_mgmt_err, stack_mgmt_info = lsp.resources.stack_mgmt_info(resource_identifier_string)
  if stack_mgmt_err ~= nil or stack_mgmt_info == nil then
    return notify.error("cannot get stack management info for resource: " .. (stack_mgmt_err or "no result from lsp"))
  end
  if stack_mgmt_info.managedByStack == true then
    return notify.error("resource is already managed by another stack: " .. (stack_mgmt_info.stackName or "unknown"))
  end

  local register_err = register_resource_to_import(bufnr, template_path, {
    ResourceType = importable_resource.type,
    LogicalResourceId = importable_resource.logicalId,
    ResourceIdentifier = resource_identifier_table,
  })
  if register_err ~= nil then
    return notify.error(register_err)
  end
end

---@param bufnr integer
---@return table<string, true>
local function get_buffer_logical_ids(bufnr)
  local ids = {}
  for _, resource in ipairs(treesitter.list_resources(bufnr)) do
    ids[resource.logical_id.name] = true
  end
  return ids
end

---@param result CfnLspResourceStateResult
---@return string?
local function state_failure_reason(result)
  for _, identifiers in pairs(result.failureReasons or {}) do
    for _, reason in pairs(identifiers) do
      return reason
    end
  end
  return nil
end

---@param lines string[]
---@param from integer 1-indexed line to search back from
---@return integer? 1-indexed line
local function last_content_line(lines, from)
  for i = from, 1, -1 do
    if vim.trim(lines[i]) ~= "" then
      return i
    end
  end
  return nil
end

---The server always builds JSON edits for VS Code.
---It assumes the last line of the document is the closing brace, but a Neovim buffer always has a trailing newline.
---It also dedents the fragment by one level because `insertSnippet` reindents on insert and `apply_text_edits` doesn't.
---@param bufnr integer
---@param edit lsp.TextEdit
local function adapt_json_edit(bufnr, edit)
  if not vim.bo[bufnr].filetype:find("json") then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local closing_brace = last_content_line(lines, #lines)
  if closing_brace ~= nil and vim.trim(lines[closing_brace]) == "}" and edit.range.start.line == closing_brace - 1 then
    local target = last_content_line(lines, closing_brace - 1)
    if target ~= nil then
      local trimmed = lines[target]:gsub("%s+$", "")
      edit.range.start = { line = target - 1, character = #trimmed }
      edit.range["end"] = edit.range.start
    end
  end

  local anchor = lines[edit.range.start.line + 1]
  local indent = anchor and anchor:match("^%s*") or ""
  if indent ~= "" then
    edit.newText = edit.newText:gsub("\n([^\n])", "\n" .. indent .. "%1")
  end
end

---@param bufnr integer
---@param template_path string
local function insert_new_resource(bufnr, template_path)
  local types_err, types = lsp.resources.resource_types()
  if types_err ~= nil or types == nil or #types.resourceTypes < 1 then
    return notify.error("cannot list resource types: " .. (types_err or "no result from lsp"))
  end
  table.sort(types.resourceTypes)
  local resource_type = ui.select(types.resourceTypes, { prompt = "Please select the resource type to import" })
  if resource_type == nil then
    return notify.info("import cancelled")
  end

  local resources_err, resources = lsp.resources.list_resources_all({ { resourceType = resource_type } })
  if resources_err ~= nil or resources == nil or #resources < 1 or #resources[1].resourceIdentifiers < 1 then
    return notify.error("cannot list " .. resource_type .. ": " .. (resources_err or "no resources found"))
  end
  local identifier = ui.select(resources[1].resourceIdentifiers, {
    prompt = "Please select the " .. resource_type .. " to import",
  })
  if identifier == nil then
    return notify.info("import cancelled")
  end

  local existing_ids = get_buffer_logical_ids(bufnr)
  local state_err, state_result = lsp.resources.resource_state({
    textDocument = { uri = vim.uri_from_fname(template_path) },
    resourceSelections = { { resourceType = resource_type, resourceIdentifiers = { identifier } } },
    purpose = "Import",
  })
  if state_err ~= nil or state_result == nil then
    return notify.error("cannot get resource state: " .. (state_err or "no result from lsp"))
  end
  if state_result.warning ~= nil then
    return notify.error(state_result.warning)
  end
  local text_edit = state_result.completionItem and state_result.completionItem.textEdit --[[@as lsp.TextEdit?]]
  if text_edit == nil or text_edit.range == nil then
    return notify.error("cannot generate resource definition: " .. (state_failure_reason(state_result) or "unknown"))
  end

  adapt_json_edit(bufnr, text_edit)
  vim.lsp.util.apply_text_edits({ text_edit }, bufnr, lsp.client().offset_encoding)
  if text_edit.newText:find("%${%d+:") then
    notify.warn("the inserted resource contains ${n:...} placeholders that you must replace")
  end

  ---@type string?
  local new_logical_id = nil
  for new_id in pairs(get_buffer_logical_ids(bufnr)) do
    if not existing_ids[new_id] then
      new_logical_id = new_id
      break
    end
  end
  if new_logical_id == nil then
    return notify.error("cannot find the inserted resource in the template")
  end

  local importable_err, importable = get_importable_resource(template_path, new_logical_id)
  if importable_err ~= nil or importable == nil or importable.primaryIdentifier == nil then
    return notify.warn(
      "inserted "
        .. new_logical_id
        .. " but could not register it for import: "
        .. (importable_err or "resource has no primary identifier")
    )
  end
  local register_err = register_resource_to_import(bufnr, template_path, {
    ResourceType = importable.type,
    LogicalResourceId = importable.logicalId,
    ResourceIdentifier = importable.primaryIdentifier,
  })
  if register_err ~= nil then
    return notify.error(register_err)
  end
  notify.info("inserted " .. new_logical_id .. " and registered it for import")
end

function M.setup()
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("cfn.core.import", {}),
    desc = "redraw cfn.nvim import markers after a buffer reload",
    callback = function(args)
      local registration = state.resources_to_import:get(vim.api.nvim_buf_get_name(args.buf))
      if registration == nil then
        return
      end
      ui.template_highlight.clear(args.buf)
      for _, resource_to_highlight in ipairs(registration.resources or {}) do
        ui.template_highlight.highlight(
          args.buf,
          resource_to_highlight.LogicalResourceId,
          "DiagnosticVirtualTextInfo",
          "Import: " .. vim.fn.json_encode(resource_to_highlight.ResourceIdentifier),
          "Title"
        )
      end
    end,
  })
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
    credentials.set(template_registration.profile, template_registration.region)

    local resource = treesitter.resource_at_cursor(bufnr)
    if resource == nil then
      return insert_new_resource(bufnr, template_path)
    end

    local import_into_cursor = "Import into " .. resource.logical_id.name
    local choice = ui.select({ import_into_cursor, "Insert a new resource definition" }, {
      prompt = "Please select what to import",
    })
    if choice == nil then
      return notify.info("import cancelled")
    end
    if choice == import_into_cursor then
      return import_resource_at_cursor(bufnr, template_path, template_registration.stack_name, resource)
    end
    return insert_new_resource(bufnr, template_path)
  end)()
end

return M
