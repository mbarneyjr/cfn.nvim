local rename = require("cfn.core.rename")

---@param _ CfnHandlerOpts
local function rename_resource(_)
  rename.rename()
end

return rename_resource
