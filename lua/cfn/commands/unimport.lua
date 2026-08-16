local unimport = require("cfn.core.unimport")
---
---@param _ CfnHandlerOpts
local function unimport_resource(_)
  unimport.unimport()
end

return unimport_resource
