local status = require("cfn.core.status")

---@param _ CfnHandlerOpts
local function show_status_window(_)
  status.show()
end

return show_status_window
