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

---@param _ CfnHandlerOpts
function M.clear(_)
  refactor.clear()
end

M.stack = {}

---@param _ CfnHandlerOpts
function M.stack.add(_)
  refactor.add_stack()
end

---@param _ CfnHandlerOpts
function M.stack.remove(_)
  refactor.remove_stack()
end

return M
