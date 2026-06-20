local M = {}

local lsp = require("cfn.lib.lsp")
local state = require("cfn.lib.state")
local buffer = require("cfn.lib.buffer")
local notify = require("cfn.lib.notify")
local progress = require("cfn.lib.progress")
local credentials = require("cfn.lib.credentials")

function M.create()
  coroutine.wrap(function()
    local template_path_err, template_path = buffer.get_current_buffer_template_path()
    if template_path_err ~= nil or not template_path then
      notify.error("cannot load profile: " .. (template_path_err or "no template path"))
      return
    end
    local registration = state.template_registration:get(template_path)
    if registration == nil then
      notify.error("current template is not registered, please run :Cfn template register")
      return
    end

    local stack_parameters_err, stack_parameters_response = lsp.stack.parameters(vim.uri_from_fname(template_path))
    if stack_parameters_err ~= nil or stack_parameters_response == nil then
      notify.error("error getting template parameters: " .. (stack_parameters_err or "no result from lsp"))
      return
    end
    vim.print(vim.inspect(stack_parameters_response.parameters))
    error("done")

    if credentials.current_profile() ~= registration.profile then
      credentials.set(registration.profile)
    end

    local create_validation_err, create_validation_response = lsp.validation.create({
      id = "cfn-nvim",
      stackName = registration.stack_name,
      uri = vim.uri_from_fname(template_path),
      keepChangeSet = true,
    })

    if create_validation_err ~= nil or create_validation_response == nil then
      notify.error("error checking changeset status: " .. (create_validation_err or "no result from lsp"))
      return
    end

    local done = false
    local progress_report = progress.send("creating changeset", true, {
      title = registration.stack_name,
      status = "running",
    })
    while not done do
      local err, result = lsp.validation.status({
        id = create_validation_response.id,
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
      id = create_validation_response.id,
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
  end)()
end

function M.load()
  coroutine.wrap(function()
    vim.print("loading changeset")
  end)()
end

function M.execute()
  coroutine.wrap(function()
    vim.print("executing changeset")
  end)()
end

return M
