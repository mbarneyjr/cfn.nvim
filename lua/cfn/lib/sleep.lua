local M = {}

local notify = require("cfn.lib.notify")

---@param ms number
function M.sleep(ms)
  local co = assert(coroutine.running())
  vim.defer_fn(function()
    local ok, co_err = coroutine.resume(co)
    if not ok then
      notify.error(co_err)
    end
  end, ms)
  return coroutine.yield()
end

return M
