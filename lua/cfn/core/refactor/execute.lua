local M = {}

local cli = require("cfn.lib.cli")
local notify = require("cfn.lib.notify")
local state = require("cfn.lib.state")
local refactor_util = require("cfn.core.refactor.util")

function M.execute()
  coroutine.wrap(function()
    local active_refactor = state.active_refactor:get("main")
    if active_refactor == nil then
      return notify.error("no active stack refactor, please run :Cfn refactor create")
    end

    local execute_err =
      cli.refactor.execute(active_refactor.profile, active_refactor.region, active_refactor.stack_refactor_id)
    if execute_err ~= nil then
      return notify.error("cannot execute stack refactor: " .. execute_err)
    end

    local success = refactor_util.wait(
      active_refactor,
      "stack refactor execution",
      "EXECUTE_COMPLETE",
      function(described)
        return described.executionStatus, described.executionStatusReason
      end
    )
    if not success then
      return
    end

    state.active_refactor:remove("main")
    state.refactor_operation:remove("main")
    notify.info("executed stack refactor: " .. active_refactor.stack_refactor_id)
  end)()
end

return M
