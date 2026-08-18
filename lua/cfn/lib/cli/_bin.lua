local M = {}

local config = require("cfn.lib.config")
local download = require("cfn.lib.cli._download")

---@type string?
local resolved = nil

---@return string? err
---@return string? path
function M.path()
  if resolved ~= nil then
    return nil, resolved
  end

  if config.options.bin.path then
    resolved = config.options.bin.path
    return nil, resolved
  end

  local built = vim.api.nvim_get_runtime_file("bin/cfn-nvim", false)[1]
  if built ~= nil then
    resolved = built
    return nil, resolved
  end

  local found = vim.fn.exepath("cfn-nvim")
  if found ~= "" then
    resolved = found
    return nil, resolved
  end

  local err, path = download.ensure()
  if err ~= nil then
    return "cannot find the cfn-nvim binary: "
      .. err
      .. ". Build it into the plugin's bin/ directory, put cfn-nvim on your PATH, "
      .. "or set bin.path in the cfn.nvim setup() function",
      nil
  end
  resolved = path
  return nil, resolved
end

return M
