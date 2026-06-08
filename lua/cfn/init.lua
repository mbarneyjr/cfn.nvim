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

M.fn = {
  register_template = require("cfn.core.template").register,
  unregister_template = require("cfn.core.template").unregister,
  load_profile = require("cfn.core.profile").load,
  toggle_status_window = require("cfn.lib.status.window").toggle,
}

return M
