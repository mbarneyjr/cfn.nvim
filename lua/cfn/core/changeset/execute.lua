local M = {}

local credentials = require("cfn.lib.credentials")
local notify = require("cfn.lib.notify")
local progress = require("cfn.lib.progress")
local lsp = require("cfn.lib.lsp")
local state = require("cfn.lib.state")
local sleep = require("cfn.lib.sleep")
local util = require("cfn.core.changeset.util")

---@param registration TemplateRegistration
---@param deployment CfnLspStackDeploymentCreateResult
local function wait_for_deployment(registration, deployment)
  local progress_report = progress.send("executing changeset", true, {
    title = registration.stack_name,
    status = "running",
  })
  ---@type CfnLspStackDeploymentDescribeResult?
  local description
  ---@type string?
  local describe_err
  ---@type string?
  local events_err
  ---@type CfnLspOperationEvent[]?
  local events
  ---@type string?
  local marker
  ---@type CfnLspEventsFilter
  local filter = {
    clientRequestToken = deployment.id,
  }
  while true do
    events_err, events, marker = lsp.stack.events_describe_until({
      stackName = registration.stack_name,
    }, filter, marker)
    if events_err ~= nil or events == nil then
      progress_report.status = "failed"
      progress.send("error checking deployment status: " .. (events_err or "no events from lsp"), true, progress_report)
      return
    end

    for i = #events, 1, -1 do
      local event = events[i]
      if filter.operationId == nil and event.OperationId ~= nil then
        filter.operationId = event.OperationId
      end
      if event.EventType ~= "PROGRESS" then
        goto continue
      end
      if event.LogicalResourceId ~= nil and event.ResourceType ~= nil and event.ResourceStatus ~= nil then
        progress.send(
          "resource " .. event.LogicalResourceId .. " (" .. event.ResourceType .. ") is " .. event.ResourceStatus,
          true,
          progress_report
        )
      end
      ::continue::
    end
    describe_err, description = lsp.deployment.describe({
      id = deployment.id,
    })
    if describe_err ~= nil or description == nil then
      progress_report.status = "failed"
      progress.send(
        "error checking deployment status: " .. (describe_err or "no description from lsp"),
        true,
        progress_report
      )
      return
    end
    if description.state ~= "IN_PROGRESS" then
      break
    end
    sleep.sleep(1000)
  end
  if assert(description).state == "FAILED" then
    progress_report.status = "failed"
    progress.send(
      "changeset execution failed: " .. (assert(description).FailureReason or "unknown error"),
      true,
      progress_report
    )
    return
  end
  progress_report.status = "success"
  progress.send("executed changeset", true, progress_report)
end

function M.execute()
  coroutine.wrap(function()
    local registration_err, registration, template_path = util.get_template_registration()
    if registration_err ~= nil or registration == nil or template_path == nil then
      notify.error(registration_err or "no registration found")
      return
    end

    if credentials.current_profile() ~= registration.profile then
      credentials.set(registration.profile)
    end

    local active_changeset = state.active_changeset:get(vim.fn.fnamemodify(template_path, ":."))
    if active_changeset == nil then
      notify.error("no active changeset found, please run :Cfn changeset load or :Cfn changeset create")
      return
    end

    local raw = vim.fn.reltimestr(vim.fn.reltime())
    local id = "cfn-nvim-" .. raw:gsub("%s", ""):gsub("%.", "")
    local deployment_err, deployment = lsp.deployment.create({
      changeSetName = active_changeset.changeSetName,
      stackName = active_changeset.stackName,
      id = id,
    })

    if deployment_err ~= nil or deployment == nil then
      notify.error("cannot execute changeset: " .. (deployment_err or "no deployment found"))
      return
    end
    wait_for_deployment(registration, deployment)
    state.active_changeset:remove(vim.fn.fnamemodify(template_path, ":."))
  end)()
end

return M
