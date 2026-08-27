local M = {}

local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")

function M.clear()
  coroutine.wrap(function()
    if state.refactor_operation:get("main") == nil then
      return notify.warn("no pending refactor to clear")
    end
    state.refactor_operation:remove("main")
    state.active_refactor:remove("main")
    notify.info("cleared pending refactor")
  end)()
end

return M
