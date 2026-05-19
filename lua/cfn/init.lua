local M = {}

local config = require("cfn.lib.config")

---@param opts? cfn.SetupOpts
function M.setup(opts)
  config.setup(opts)
end

return M
