local M = {}

local notify = require("cfn.lib.notify")

---@generic T
---@param items T[]
---@param opts vim.ui.select.Opts
---@return T?
function M.select(items, opts)
  local co = assert(coroutine.running(), "cfn.lib.ui.select must be called from a coroutine")
  vim.ui.select(items, opts or {}, function(choice)
    vim.schedule(function()
      local ok, co_err = coroutine.resume(co, choice)
      if not ok then
        notify.error(co_err)
      end
    end)
  end)
  return coroutine.yield()
end

return M
