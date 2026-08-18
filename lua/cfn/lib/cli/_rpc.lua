local M = {}

local bin = require("cfn.lib.cli._bin")
local notify = require("cfn.lib.notify")

---@param args string[]
---@return string? err
---@return any? result
function M.run(args)
  local co = assert(coroutine.running(), "cfn.lib.cli.run functions must be called from a coroutine")
  local bin_err, bin_path = bin.path()
  if bin_err ~= nil or bin_path == nil then
    return bin_err, nil
  end
  vim.system({ bin_path, unpack(args) }, { text = true }, function(result)
    vim.schedule(function()
      local ok, co_err = coroutine.resume(co, result)
      if not ok then
        notify.error(co_err)
      end
    end)
  end)
  local result = coroutine.yield()
  if result.code ~= 0 then
    local err = result.stderr ~= "" and vim.trim(result.stderr) or ("exit " .. result.code)
    return err, nil
  end
  local ok, parsed = pcall(vim.json.decode, result.stdout)
  if not ok then
    return "invalid JSON from cfn-nvim CLI helper: " .. tostring(parsed), nil
  end
  return nil, parsed
end

return M
