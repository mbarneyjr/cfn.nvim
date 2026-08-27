local M = {}

local notify = require("cfn.lib.notify")

---@class CfnHandlerOpts
---@field args string[]   args after the namespace + action
---@field bang boolean
---@alias CfnHandler fun(opts: CfnHandlerOpts)
---@class CommandTable : { [string]: CommandTable | CfnHandler }

---@type CommandTable | CfnHandler
M.commands = {
  template = require("cfn.commands.template"),
  profile = require("cfn.commands.profile"),
  status = require("cfn.commands.status"),
  rename = require("cfn.commands.rename"),
  import = require("cfn.commands.import"),
  unimport = require("cfn.commands.unimport"),
  changeset = require("cfn.commands.changeset"),
  refactor = require("cfn.commands.refactor"),
}

---@param args string[] the raw list of space-separated args after the command name
---@param options vim.api.keyset.create_user_command.command_args the full options table passed to the user command
local function dispatch(args, options)
  if #args == 0 then
    return notify.error("missing subcommand")
  end

  --- @type any
  local current_command = M.commands
  for i, arg in ipairs(args) do
    current_command = current_command[arg]
    if current_command == nil then
      return notify.error("unknown command '" .. table.concat(vim.list_slice(args, 1, i), " ") .. "'")
    elseif type(current_command) == "function" then
      return current_command({ args = vim.list_slice(args, i + 1), bang = options.bang })
    end
  end
  local actions = vim.tbl_keys(current_command)
  table.sort(actions)
  return notify.error(
    "incomplete command '" .. table.concat(args, " ") .. "', expected one of: " .. table.concat(actions, ", ")
  )
end

---@param candidates string[]
---@param argument_lead string
---@return string[]
local function filter_starts_with(candidates, argument_lead)
  ---@type string[]
  local matches = {}
  for _, candidate in ipairs(candidates) do
    if vim.startswith(candidate, argument_lead) then
      matches[#matches + 1] = candidate
    end
  end
  return matches
end

---@param argument_lead string the partial word currently being typed
---@param command_line string the full command line so far
---@return string[]
local function complete(argument_lead, command_line)
  local args = vim.split(command_line, "%s+", { trimempty = false })

  local current_command = M.commands
  -- args[1] is the command name itself, and the last entry is the word being typed
  for i = 2, #args - 1 do
    current_command = current_command[args[i]]
    if type(current_command) ~= "table" then
      return {}
    end
  end
  return filter_starts_with(vim.tbl_keys(current_command), argument_lead)
end

function M.register()
  vim.api.nvim_create_user_command("Cfn", function(command_options)
    dispatch(command_options.fargs, command_options)
  end, {
    nargs = "*",
    bang = true,
    desc = "cfn.nvim",
    complete = complete,
  })
end

return M
