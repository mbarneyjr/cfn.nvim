local M = {}

local cli = require("cfn.lib.cli")
local notify = require("cfn.lib.notify")
local state = require("cfn.lib.state")
local refactor_util = require("cfn.core.refactor.util")

function M.create()
  coroutine.wrap(function()
    local refactor_operation = state.refactor_operation:get("main")
    if refactor_operation == nil or #refactor_operation.mappings == 0 then
      return notify.error("no pending refactor, please run :Cfn refactor move")
    end
    if state.active_refactor:get("main") ~= nil then
      return notify.error("a stack refactor already exists, please run :Cfn refactor execute")
    end

    local registration_err, registration = refactor_util.get_registration(refactor_operation)
    if registration_err ~= nil or registration == nil then
      return notify.error(registration_err or "no registration found")
    end

    local unsaved_template = refactor_util.unsaved_template(refactor_operation)
    if unsaved_template ~= nil then
      return notify.error("template has unsaved changes: " .. unsaved_template)
    end

    local create_err, created = cli.refactor.create(registration.profile, registration.region, refactor_operation)
    if create_err ~= nil or created == nil then
      return notify.error("cannot create stack refactor: " .. (create_err or "no result from cli"))
    end

    ---@type ActiveRefactor
    local active_refactor = {
      stack_refactor_id = created.stackRefactorId,
      profile = registration.profile,
      region = registration.region,
    }
    local success = refactor_util.wait(
      active_refactor,
      "stack refactor creation",
      "CREATE_COMPLETE",
      function(described)
        return described.status, described.statusReason
      end
    )
    if not success then
      return
    end

    state.active_refactor:set("main", active_refactor)
    notify.info("created stack refactor: " .. active_refactor.stack_refactor_id)
  end)()
end

return M
