---@class cfn.BinOpts
---@field path? string Override path to the cfn-nvim binary

---@class cfn.SetupOpts
---@field lsp_client_name? string
---@field bin? cfn.BinOpts

---@class cfn.Bin
---@field path? string

---@class cfn.Config
---@field lsp_client_name string
---@field bin cfn.Bin

---@type cfn.Config
local defaults = {
  lsp_client_name = "cfn_lsp",
  bin = {},
}

local M = {}

---@type cfn.Config
M.options = vim.deepcopy(defaults)

---@param opts? cfn.SetupOpts
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {}) --[[@as cfn.Config]]
  vim.validate("lsp_client_name", M.options.lsp_client_name, "string", "lsp_client_name must be a string")
end

return M
