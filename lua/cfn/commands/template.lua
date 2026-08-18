local M = {}

local template = require("cfn.core.template")

---@param opts CfnHandlerOpts
function M.register(opts)
  ---@type string | nil
  local profile = opts.args[1]
  ---@type string | nil
  local stack_name = opts.args[2]
  ---@type string | nil
  local region = opts.args[3]
  template.register(profile, stack_name, region)
end

---@param _ CfnHandlerOpts
function M.unregister(_)
  template.unregister()
end

return M
