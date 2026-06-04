local M = {}

local config = require("cfn.lib.config")
local commands = require("cfn.commands")

---@param opts? cfn.SetupOpts
function M.setup(opts)
  config.setup(opts)
  commands.register()
end

return M
