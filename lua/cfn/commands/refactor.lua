local M = {}

local refactor = require("cfn.core.refactor")

---@param _ CfnHandlerOpts
function M.create(_)
  refactor.create()
end

---@param _ CfnHandlerOpts
function M.execute(_)
  refactor.execute()
end

---@param _ CfnHandlerOpts
function M.move(_)
  refactor.move()
end

return M
