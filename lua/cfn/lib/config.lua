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

---@class cfn.HookContext
---@field template_path string
---@field stack_name string
---@field profile string
---@field region string
---@field stack? CfnLspDescribeStackData existing stack, nil when the stack does not exist

---@alias cfn.Hook fun(ctx: cfn.HookContext): table<string, string>? values keyed by name, used to pre-populate the form

---@class cfn.Hooks
---@field parameters? cfn.Hook
---@field tags? cfn.Hook

---@alias cfn.CallHook fun(name: "parameters"|"tags", ctx: cfn.HookContext): table<string, string>? nil when no hook is set or the hook fails

---@class cfn.SetupOpts
---@field lsp_client_name? string
---@field bin? cfn.BinOpts
---@field status_window? cfn.StatusWindowOpts
---@field icons? cfn.IconOpts
---@field hooks? cfn.Hooks

---@class cfn.Config
---@field lsp_client_name string
---@field bin cfn.Bin
---@field status_window cfn.StatusWindow
---@field icons cfn.Icon
---@field hooks cfn.Hooks

---@type cfn.Config
local defaults = {
  lsp_client_name = "cfn_lsp",
  bin = {},
  status_window = {
    height = 15,
  },
  hooks = {},
  icons = {
    arrow_closed = "",
    arrow_open = "",
  },
}

local M = {}

local notify = require("cfn.lib.notify")

---@type cfn.Config
M.options = vim.deepcopy(defaults)

---@type cfn.CallHook
function M.call_hook(name, ctx)
  local hook = M.options.hooks[name]
  if hook == nil then
    return nil
  end
  local ok, result = pcall(hook, ctx)
  if not ok then
    notify.error(name .. " hook failed: " .. tostring(result))
    return nil
  end
  if result ~= nil and type(result) ~= "table" then
    notify.error(name .. " hook must return a table or nil")
    return nil
  end
  for key, value in pairs(result or {}) do
    if type(value) ~= "string" then
      notify.error(name .. " hook returned a " .. type(value) .. " for '" .. tostring(key) .. "', expected a string")
      return nil
    end
  end
  return result
end

---@param opts? cfn.SetupOpts
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {}) --[[@as cfn.Config]]
  vim.validate("lsp_client_name", M.options.lsp_client_name, "string", "lsp_client_name must be a string")
  vim.validate("hooks.parameters", M.options.hooks.parameters, "function", true)
  vim.validate("hooks.tags", M.options.hooks.tags, "function", true)
end

return M
