local M = {}

local notify = require("cfn.lib.notify")

function M.execute()
  coroutine.wrap(function()
    notify.error("not implemented")
  end)()
end

return M
