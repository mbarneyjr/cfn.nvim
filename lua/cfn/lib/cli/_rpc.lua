local M = {}

local bin = require("cfn.lib.cli._bin")

---@param args string[]
---@return string? err
---@return any? result
function M.run(args)
  local co = assert(coroutine.running(), "cfn.lib.cli.run functions must be called from a coroutine")
  vim.system({ bin.path(), unpack(args) }, { text = true }, function(result)
    vim.schedule(function()
      coroutine.resume(co, result)
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
