local M = {}

local profile = require("cfn.core.profile")

---@param _ CfnHandlerOpts
function M.load(_)
  profile.load()
end

return M
