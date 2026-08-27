local M = {}

local lsp = require("cfn.lib.lsp")
local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local progress = require("cfn.lib.progress")
local credentials = require("cfn.lib.credentials")
local ui = require("cfn.lib.ui")
local sleep = require("cfn.lib.sleep")
local util = require("cfn.lib.util")
local config = require("cfn.lib.config")
local changeset_util = require("cfn.core.changeset.util")

---@param ctx cfn.HookContext
---@return string? error
---@return CfnLspParameter[]?
local function get_parameters(ctx)
  local stack_parameters_err, stack_parameters = lsp.stack.parameters(vim.uri_from_fname(ctx.template_path))
  if stack_parameters_err ~= nil or stack_parameters == nil then
    return "error getting template parameters: " .. (stack_parameters_err or "no result from lsp"), nil
  end
  if ctx.stack ~= nil then
    for _, existing_parameter in ipairs(ctx.stack.Parameters or {}) do
      for _, template_parameter in ipairs(stack_parameters.parameters) do
        if existing_parameter.ParameterKey == template_parameter.name then
          if template_parameter.NoEcho then
            template_parameter.UsePreviousValue = true
          else
            template_parameter.CurrentValue = existing_parameter.ParameterValue
          end
        end
      end
    end
  end
  for name, value in pairs(config.call_hook("parameters", ctx) or {}) do
    for _, template_parameter in ipairs(stack_parameters.parameters) do
      if template_parameter.name == name then
        template_parameter.CurrentValue = tostring(value)
        template_parameter.UsePreviousValue = false
      end
    end
  end
  local param_err, params = ui.parameter_form.collect_parameter_values(stack_parameters.parameters, ctx.template_path)
  if param_err ~= nil or params == nil then
    return "error collecting parameters: " .. (param_err or "no parameters returned"), nil
  end
  return nil, params
end

---@param ctx cfn.HookContext
---@return string? error
---@return CfnLspTag[]?
local function get_tags(ctx)
  local stack_tags = ctx.stack and ctx.stack.Tags
  local supplied = config.call_hook("tags", ctx)
  if supplied ~= nil then
    stack_tags = ui.tag_form.to_array(vim.tbl_extend("force", ui.tag_form.to_object(stack_tags or {}), supplied))
  end
  local tag_err, tags = ui.tag_form.collect_tags(stack_tags)
  if tag_err ~= nil or tags == nil then
    return "error collecting tags: " .. (tag_err or "no tags returned"), nil
  end
  return nil, tags
end

---@param registration TemplateRegistration
---@param create_validation CfnLspStackValidationCreateResult
---@return CfnLspStackValidationDescribeResult?
local function wait_for_changeset(registration, create_validation)
  local done = false
  local progress_report = progress.send("creating changeset", true, {
    title = registration.stack_name,
    status = "running",
  })
  while not done do
    local err, result = lsp.validation.status({
      id = create_validation.id,
    })
    if err ~= nil or result == nil then
      progress_report.status = "failed"
      progress.send("error checking changeset status: " .. (err or "no result from lsp"), true, progress_report)
      return
    end
    if result.state ~= "IN_PROGRESS" then
      done = true
    end
    sleep.sleep(1000)
  end
  local describe_err, describe_result = lsp.validation.describe({
    id = create_validation.id,
  })
  if describe_err ~= nil or describe_result == nil then
    progress_report.status = "failed"
    progress.send("error describing changeset" .. (describe_err or "no result from lsp"), true, progress_report)
    return
  end
  if describe_result.state == "FAILED" then
    progress_report.status = "failed"
    progress.send("changeset creation failed: " .. describe_result.FailureReason, true, progress_report)
    return
  end
  progress_report.status = "success"
  progress.send("created changeset", true, progress_report)
  return describe_result
end

---@param registration TemplateRegistration
---@param template_path string
---@return string? error
---@return string? artifact_bucket_name
local function handle_artifacts(registration, template_path)
  local artifacts_err, artifacts = lsp.template.artifacts(vim.uri_from_fname(template_path))
  if artifacts_err ~= nil or artifacts == nil then
    return "error getting template artifacts: " .. (artifacts_err or "no result from lsp"), nil
  end
  if #artifacts.artifacts == 0 then
    return nil, nil
  end
  if registration.artifact_bucket_name == nil then
    local register_err, artifact_bucket_name = ui.artifact_bucket.prompt_for_artifact_bucket()
    if register_err ~= nil or artifact_bucket_name == nil then
      return "error registering artifact bucket: " .. (register_err or "no bucket name returned"), nil
    end
    registration.artifact_bucket_name = artifact_bucket_name
    state.template_registration:set(template_path, registration)
  end
  return nil, registration.artifact_bucket_name
end

---@param registration TemplateRegistration
---@param template_path string
---@return string? error
---@return CfnLspResourceToImport[]? resources_to_import
---@return boolean? auto_import
local function get_resource_import(registration, template_path)
  local stack_resources_err, stack_resources = lsp.stack.resources_all({ stackName = registration.stack_name })
  if stack_resources_err ~= nil or stack_resources == nil then
    if not stack_resources_err then
      stack_resources_err = "no result from lsp"
    end
    if not string.find(stack_resources_err, "does not exist") then
      return "error getting stack resources: " .. stack_resources_err, nil, nil
    end
    stack_resources = {}
  end
  local stack_resource_map = {}
  for _, stack_resource in ipairs(stack_resources) do
    stack_resource_map[stack_resource.LogicalResourceId] = stack_resource
  end

  local importable_resources_err, importable_resources = lsp.import.import_resources(vim.uri_from_fname(template_path))
  if importable_resources_err ~= nil or importable_resources == nil then
    return "error getting importable resources: " .. (importable_resources_err or "no result from lsp"), nil, nil
  end

  ---@type CfnLspTemplateResource[]
  local new_resources = {}
  for _, importable_resource in ipairs(importable_resources.resources) do
    if stack_resource_map[importable_resource.logicalId] == nil then
      table.insert(new_resources, importable_resource)
    end
  end

  if #new_resources == 0 then
    return nil, nil, nil
  end

  ---@type { [string]: CfnLspResourceToImport }
  local resources_to_import = {}
  local resources_to_import_registration = state.resources_to_import:get(template_path)
  if resources_to_import_registration ~= nil and resources_to_import_registration.resources ~= nil then
    for _, resource_to_import in ipairs(resources_to_import_registration.resources) do
      resources_to_import[resource_to_import.LogicalResourceId] = resource_to_import
    end
  end

  local import_choice
  if next(resources_to_import) ~= nil then
    import_choice = "IMPORT_EXISTING_RESOURCES"
  else
    local import_choices = {
      ["AUTO_IMPORT"] = "auto-import named resources",
      ["IMPORT_EXISTING_RESOURCES"] = "import existing resources",
      ["CREATE_NEW_RESOURCES"] = "create new resources",
    }
    local import_choice_ordered = { "AUTO_IMPORT", "IMPORT_EXISTING_RESOURCES", "CREATE_NEW_RESOURCES" }
    import_choice = ui.select(import_choice_ordered, {
      prompt = "New resources detected, how would you like to handle them?",
      format_item = function(choice)
        return import_choices[choice]
      end,
    })
  end
  if import_choice == nil then
    return "no import choice selected", nil, nil
  elseif import_choice == "AUTO_IMPORT" then
    return nil, nil, true
  elseif import_choice == "CREATE_NEW_RESOURCES" then
    return nil, nil, false
  end

  ---@type { [string]: string[] }
  local discovered_resources = {}
  ---@type boolean
  local confirmed_import = false
  for _, importable_resource in ipairs(new_resources) do
    if resources_to_import[importable_resource.logicalId] ~= nil then
      goto continue
    end
    if not confirmed_import then
      local confirm_import = ui.select({ "Cancel Import Operation", "Enter New Resource Ids" },
        { prompt = "There are new template resource weren't marked for import, continue?" })
      if confirm_import == nil or confirm_import == "Cancel Import Operation" then
        return "import operation cancelled", nil, nil
      end
      confirmed_import = true
    end

    if discovered_resources[importable_resource.type] == nil then
      local resources_err, resources = lsp.resources.list_resources_all({ { resourceType = importable_resource.type } })
      if resources_err ~= nil or resources == nil or #resources < 1 then
        return "cannot list " .. importable_resource.type .. " " .. (resources_err or "no result from lsp"), nil, nil
      end
      discovered_resources[importable_resource.type] = resources[1].resourceIdentifiers
    end
    local resource_identifier_table = {}
    if #discovered_resources[importable_resource.type] < 1 then
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
          return "no resource identifier provided for " .. importable_resource.logicalId, nil, nil
        end
        resource_identifier_table[key] = resource_identifier
      end
    else
      local chosen_identifier = ui.select(discovered_resources[importable_resource.type], {
        prompt = "Please select the resource to import to " .. importable_resource.logicalId,
        format_item = function(item)
          return item
        end,
      })
      if chosen_identifier == nil then
        return "no resource identifier selected for " .. importable_resource.logicalId, nil, nil
      end
      local chosen_identifier_split = vim.split(chosen_identifier, "|")
      for i, key in ipairs(importable_resource.primaryIdentifierKeys or {}) do
        resource_identifier_table[key] = chosen_identifier_split[i]
      end
    end
    resources_to_import[importable_resource.logicalId] = {
      ResourceType = importable_resource.type,
      LogicalResourceId = importable_resource.logicalId,
      ResourceIdentifier = resource_identifier_table,
    }
    ::continue::
  end
  ---@type CfnLspResourceToImport[]
  local result = {}
  for _, resource_to_import in pairs(resources_to_import) do
    table.insert(result, resource_to_import)
  end
  return nil, result, nil
end

function M.create()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local registration_err, registration, template_path = util.state.get_template_registration(bufnr, "create changeset")
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.error(registration_err or "no registration found")
      return
    end

    credentials.set(registration.profile, registration.region)

    local stack_description_err, stack_description = lsp.stack.describe({ stackName = registration.stack_name })
    if stack_description_err ~= nil then
      if not string.find(stack_description_err, "does not exist") then
        notify.error("error describing stack: " .. (stack_description_err or "no result from lsp"))
        return
      end
    end

    ---@type cfn.HookContext
    local ctx = {
      template_path = template_path,
      stack_name = registration.stack_name,
      profile = registration.profile,
      region = registration.region,
      stack = stack_description and stack_description.stack,
    }

    local params_err, params = get_parameters(ctx)
    if params_err ~= nil or params == nil then
      notify.error(params_err or "no parameters returned")
      return
    end

    local tag_err, tags = get_tags(ctx)
    if tag_err ~= nil or tags == nil then
      notify.error("error collecting tags: " .. (tag_err or "no tags returned"))
      return
    end

    local caps_err, capabilities = lsp.stack.capabilities(vim.uri_from_fname(template_path))
    if caps_err ~= nil then
      notify.error("error getting capabilities: " .. caps_err)
      return
    end

    local artifacts_err, artifact_bucket_name = handle_artifacts(registration, template_path)
    if artifacts_err ~= nil then
      notify.error(artifacts_err)
      return
    end

    local import_err, resources_to_import, auto_import = get_resource_import(registration, template_path)
    if import_err ~= nil then
      notify.error("error discovering resource import: " .. (import_err or "no result from lsp"))
      return
    end

    local include_nested_stacks = true
    if resources_to_import ~= nil then
      include_nested_stacks = false
    end
    local raw = vim.fn.reltimestr(vim.fn.reltime())
    local id = "cfn-nvim-" .. raw:gsub("%s", ""):gsub("%.", "")
    local create_validation_err, create_validation = lsp.validation.create({
      id = id,
      stackName = registration.stack_name,
      uri = vim.uri_from_fname(template_path),
      keepChangeSet = true,
      capabilities = capabilities,
      parameters = params,
      tags = tags,
      s3Bucket = artifact_bucket_name,
      includeNestedStacks = include_nested_stacks,
      importExistingResources = auto_import,
      resourcesToImport = resources_to_import,
    })
    if create_validation_err ~= nil or create_validation == nil then
      notify.error("error creating changeset: " .. (create_validation_err or "no result from lsp"))
      return
    end
    local changeset = wait_for_changeset(registration, create_validation)
    if changeset == nil then
      return
    end
    local highlight_err = changeset_util.highlight_changeset(bufnr, changeset)
    if highlight_err ~= nil then
      notify.error("error highlighting changeset: " .. highlight_err)
      return
    end
    state.resources_to_import:remove(template_path)
    state.active_changeset:set(template_path, {
      stackName = create_validation.stackName,
      changeSetName = create_validation.changeSetName,
    })
    local console_url = string.format(
      "https://%s.console.aws.amazon.com/cloudformation/home?region=%s#/stacks/changesets/changes?stackId=%s&changeSetId=%s",
      registration.region,
      registration.region,
      create_validation.stackName,
      create_validation.changeSetName
    )
    progress.send(console_url, true, {
      title = "changeset url",
      status = "success",
    })
    notify.info("created changeset: " .. create_validation.changeSetName)
  end)()
end

return M
