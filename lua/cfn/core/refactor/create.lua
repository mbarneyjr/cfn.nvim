local M = {}

local notify = require("cfn.lib.notify")

function M.create()
  coroutine.wrap(function()
    notify.error("not implemented")
  end)()
end

return M
