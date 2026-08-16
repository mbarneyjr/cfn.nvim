local import = require("cfn.core.import")

---@param _ CfnHandlerOpts
local function import_resource(_)
  import.import()
end

---@param _ CfnHandlerOpts
local function remove_import(_)
  import.remove_import()
end

return import_resource
