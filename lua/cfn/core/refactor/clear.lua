local M = {}

local state = require("cfn.lib.state")

function M.clear()
  coroutine.wrap(function()
    state.refactor_operation:remove("main")
  end)()
end

return M
