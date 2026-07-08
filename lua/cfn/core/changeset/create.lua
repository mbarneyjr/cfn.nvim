local M = {}

local lsp = require("cfn.lib.lsp")
local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local progress = require("cfn.lib.progress")
local credentials = require("cfn.lib.credentials")
local ui = require("cfn.lib.ui")
local util = require("cfn.core.changeset.util")

---@param template_path string
---@param stack_description CfnLspDescribeStackResult?
---@return string? error
---@return CfnLspParameter[]?
local function get_parameters(template_path, stack_description)
  local stack_parameters_err, stack_parameters = lsp.stack.parameters(vim.uri_from_fname(template_path))
  if stack_parameters_err ~= nil or stack_parameters == nil then
    return "error getting template parameters: " .. (stack_parameters_err or "no result from lsp"), nil
  end
  if stack_description ~= nil then
    for _, existing_parameter in ipairs(stack_description.stack.Parameters or {}) do
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
  local param_err, params = ui.parameter_form.collect_parameter_values(stack_parameters.parameters, template_path)
  if param_err ~= nil or params == nil then
    return "error collecting parameters: " .. (param_err or "no parameters returned"), nil
  end
  return nil, params
end

---@param stack_description CfnLspDescribeStackResult?
---@return string? error
---@return CfnLspParameter[]?
local function get_tags(stack_description)
  local stack_tags = nil
  if stack_description ~= nil then
    stack_tags = stack_description.stack.Tags
  end
  local tag_err, tags = ui.tag_form.collect_tags(stack_tags)
  if tag_err ~= nil or tags == nil then
    return "error collecting tags: " .. (tag_err or "no tags returned"), nil
  end
  return nil, tags
end

---@param registration TemplateRegistration
---@param create_validation CfnLspStackValidationCreateResult
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
    return "error getting stack resources: " .. (stack_resources_err or "no result from lsp"), nil, nil
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

  local import_choices = {
    ["AUTO_IMPORT"] = "auto-import named resources",
    ["IMPORT_EXISTING_RESOURCES"] = "import existing resources",
    ["CREATE_NEW_RESOURCES"] = "create new resources",
  }
  local import_choice_ordered = { "AUTO_IMPORT", "IMPORT_EXISTING_RESOURCES", "CREATE_NEW_RESOURCES" }
  local import_choice = ui.select(import_choice_ordered, {
    prompt = "New resources detected, how would you like to handle them?",
    format_item = function(choice)
      return import_choices[choice]
    end,
  })
  if import_choice == nil then
    return "no import choice selected", nil, nil
  elseif import_choice == "AUTO_IMPORT" then
    return nil, nil, true
  elseif import_choice == "CREATE_NEW_RESOURCES" then
    return nil, nil, false
  end

  ---@type CfnLspResourceToImport[]
  local resources_to_import = {}
  ---@type { [string]: string[] }
  local discovered_resources = {}
  for _, importable_resource in ipairs(new_resources) do
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
    table.insert(resources_to_import, {
      ResourceType = importable_resource.type,
      LogicalResourceId = importable_resource.logicalId,
      ResourceIdentifier = resource_identifier_table,
    })
  end
  return nil, resources_to_import, nil
end

function M.create()
  coroutine.wrap(function()
    local registration_err, registration, template_path = util.get_template_registration()
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.error(registration_err or "no registration found")
      return
    end

    if credentials.current_profile() ~= registration.profile then
      credentials.set(registration.profile)
    end

    local stack_description_err, stack_description = lsp.stack.describe({ stackName = registration.stack_name })
    if stack_description_err ~= nil then
      if not string.find(stack_description_err, "does not exist") then
        notify.error("error describing stack: " .. (stack_description_err or "no result from lsp"))
        return
      end
    end

    local params_err, params = get_parameters(template_path, stack_description)
    if params_err ~= nil or params == nil then
      notify.error(params_err or "no parameters returned")
      return
    end

    local tag_err, tags = get_tags(stack_description)
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
    local create_validation_err, create_validation = lsp.validation.create({
      id = "cfn-nvim",
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
      notify.error("error checking changeset status: " .. (create_validation_err or "no result from lsp"))
      return
    end
    wait_for_changeset(registration, create_validation)
    state.active_changeset:set(vim.fn.fnamemodify(template_path, ":."), {
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
  end)()
end

return M
