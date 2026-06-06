local M = {}

local config = require("cfn.lib.config")
local state = require("cfn.lib.state")
local commands = require("cfn.commands")

---@param opts? cfn.SetupOpts
function M.setup(opts)
  config.setup(opts)
  commands.register()
end

M.encryption_key = state.encryption_key

return M
