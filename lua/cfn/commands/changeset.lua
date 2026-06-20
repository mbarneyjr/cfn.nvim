local M = {}

local changeset = require("cfn.core.changeset")

---@param _ CfnHandlerOpts
function M.create(_)
  changeset.create()
end

---@param _ CfnHandlerOpts
function M.load(_)
  changeset.load()
end

---@param _ CfnHandlerOpts
function M.execute(_)
  changeset.execute()
end

return M
