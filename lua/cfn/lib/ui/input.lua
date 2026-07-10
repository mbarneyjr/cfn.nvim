local M = {}

local notify = require("cfn.lib.notify")

---@param opts vim.ui.input.Opts
---@return string
function M.input(opts)
  local co = assert(coroutine.running(), "cfn.lib.sleep must be called from a coroutine")
  vim.ui.input(opts or {}, function(result)
    vim.schedule(function()
      local ok, co_err = coroutine.resume(co, result)
      if not ok then
        notify.error(co_err)
      end
    end)
  end)
  return coroutine.yield()
end

return M
