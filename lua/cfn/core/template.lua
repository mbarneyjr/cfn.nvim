local M = {}

local notify = require("cfn.lib.notify")
local state = require("cfn.lib.state")
local lsp = require("cfn.lib.lsp")
local cli = require("cfn.lib.cli")
local ui = require("cfn.lib.ui")
local credentials = require("cfn.lib.credentials")
local buffer = require("cfn.lib.buffer")
local util = require("cfn.lib.util")

---@param template_path string
---@return string? error
---@return boolean?
local function template_requires_artifacts(template_path)
  local artifacts_err, artifacts = lsp.template.artifacts(vim.uri_from_fname(template_path))
  if artifacts_err ~= nil or artifacts == nil then
    return "error getting template artifacts: " .. (artifacts_err or "no result from lsp"), nil
  end
  return nil, #artifacts.artifacts > 0
end

---@param profile string | nil
---@param stack_name string | nil
function M.register(profile, stack_name)
  coroutine.wrap(function()
    local template_path_err, template_path = buffer.get_current_buffer_template_path()
    if template_path_err ~= nil or not template_path then
      notify.error("cannot register template: " .. (template_path_err or "no template path"))
      return
    end

    local current_registration = state.template_registration:get(template_path)

    if not profile then
      local err, response = cli.profile.list()
      if err ~= nil or not response then
        return notify.error("error registering template: " .. (err or "invalid response from cli helper"))
      end
      profile = ui.select(response.profiles, {
        prompt = "Choose an AWS profile",
        format_item = function(item)
          if current_registration ~= nil and item == current_registration.profile then
            return item .. " [Current Registration]"
          end
          return item
        end,
      })
      if not profile then
        return notify.warn("template registration cancelled: no profile chosen")
      end
    end
    local creds_err, creds = credentials.set(profile)
    if creds_err or not creds then
      return notify.error(
        "error setting credentials for profile " .. profile .. ": " .. (creds_err or "no credentials returned")
      )
    end
    if not stack_name then
      local err, stacks = lsp.cfn.stacks_all({ statusToExclude = util.cfn.UNAVAILABLE_STACK_STATUSES })
      if err or stacks == nil then
        notify.error("could not list CloudFormation stacks: " .. (err or "no result"))
        return
      end

      local new_stack = {
        StackName = "[NEW STACK]",
        StackStatus = "",
      }
      ---@type { StackName: string, StackStatus: string }[]
      local items = { new_stack }
      for _, stack in ipairs(stacks) do
        table.insert(items, stack)
      end
      local picked = ui.select(items, {
        prompt = "Choose a stack to register this template to",
        format_item = function(item)
          if item == new_stack then
            return "[NEW STACK]"
          end
          if current_registration ~= nil and item.StackName == current_registration.stack_name then
            return item.StackName .. " [" .. item.StackStatus .. "] [Current Registration]"
          end
          return item.StackName .. " [" .. item.StackStatus .. "]"
        end,
      })
      if picked == nil then
        return notify.warn("template registration cancelled: no stack name chosen")
      elseif picked == new_stack then
        stack_name = ui.input({
          prompt = "Enter a name for the new stack",
          default = current_registration and current_registration.stack_name or nil,
          validate = function(input)
            if not input or input == "" then
              return "Stack name cannot be empty"
            end
            return nil
          end,
        })
      else
        stack_name = picked.StackName
      end
    end

    local requires_artifacts_err, requires_artifacts = template_requires_artifacts(template_path)
    if requires_artifacts_err ~= nil or requires_artifacts == nil then
      return notify.error(
        "error checking if template requires artifacts: " .. (requires_artifacts_err or "no result from lsp")
      )
    end
    ---@type string?
    local register_err, artifact_bucket_name
    if requires_artifacts then
      register_err, artifact_bucket_name = ui.artifact_bucket.prompt_for_artifact_bucket()
      if register_err ~= nil or artifact_bucket_name == nil then
        return notify.error("error registering artifact bucket: " .. (register_err or "no bucket name returned"))
      end
    end

    state.template_registration:set(template_path, {
      profile = profile,
      region = creds.region,
      stack_name = stack_name,
      artifact_bucket_name = artifact_bucket_name,
    })
    notify.info("registering template: " .. profile .. "/" .. stack_name)
  end)()
end

function M.unregister()
  local template_path_err, template_path = buffer.get_current_buffer_template_path()
  if template_path_err ~= nil or not template_path then
    notify.error("cannot register template: " .. (template_path_err or "no template path"))
    return
  end
  state.template_registration:remove(template_path)
end

return M
