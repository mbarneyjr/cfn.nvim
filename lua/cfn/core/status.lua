local M = {}

local status = require("cfn.lib.status")

function M.show()
  coroutine.wrap(function()
    status.show()
  end)()
end

return M
