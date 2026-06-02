local M = {}

local config = require("cfn.lib.config")

function M.path()
  if config.options.bin.path then
    return config.options.bin.path
  end
  error("cfn-nvim binary path is not set. Please set it in the cfn.nvim setup() function.")
end

return M
