local M = {}

---@generic T
---@param items T[]
---@param opts vim.ui.select.Opts
---@return T?
function M.select(items, opts)
  local co = assert(coroutine.running(), "cfn.lib.ui.select must be called from a coroutine")
  vim.ui.select(items, opts or {}, function(choice)
    vim.schedule(function()
      coroutine.resume(co, choice)
    end)
  end)
  return coroutine.yield()
end

---@param opts vim.ui.input.Opts
---@return string
function M.input(opts)
  local co = assert(coroutine.running(), "cfn.lib.ui.input must be called from a coroutine")
  vim.ui.input(opts or {}, function(result)
    vim.schedule(function()
      coroutine.resume(co, result)
    end)
  end)
  return coroutine.yield()
end

return M
