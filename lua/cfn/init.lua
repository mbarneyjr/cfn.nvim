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
  rename_resource = require("cfn.core.rename").rename,
  create_changeset = require("cfn.core.changeset").create,
  execute_changeset = require("cfn.core.changeset").execute,
  open_changeset = require("cfn.core.changeset").open,
  load_changeset = require("cfn.core.changeset").load,
  unload_changeset = require("cfn.core.changeset").unload,
  import_resource = require("cfn.core.import").import,
  move_resource = require("cfn.core.refactor").move,
  create_refactor = require("cfn.core.refactor").create,
  execute_refactor = require("cfn.core.refactor").execute,
  clear_refactor = require("cfn.core.refactor").clear,
  get_status = require("cfn.lib.status.line").get,
}

return M
