---@class cfn.IconOpts
---@field arrow_closed? string
---@field arrow_open? string
---@class cfn.Icon
---@field arrow_closed string
---@field arrow_open string

---@class cfn.BinOpts
---@field path? string Override path to the cfn-nvim binary
---@class cfn.Bin
---@field path? string

---@class cfn.StatusWindowOpts
---@field height? integer the height for the status window
---@class cfn.StatusWindow
---@field height? integer the height for the status window

---@class cfn.SetupOpts
---@field lsp_client_name? string
---@field bin? cfn.BinOpts
---@field status_window? cfn.StatusWindowOpts
---@field icons? cfn.IconOpts

---@class cfn.Config
---@field lsp_client_name string
---@field bin cfn.Bin
---@field status_window cfn.StatusWindow
---@field icons cfn.Icon

---@type cfn.Config
local defaults = {
  lsp_client_name = "cfn_lsp",
  bin = {},
  status_window = {
    height = 15,
  },
  icons = {
    arrow_closed = "",
    arrow_open = "",
  },
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
