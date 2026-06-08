local M = {}

local state = require("cfn.lib.state")
local config = require("cfn.lib.config")
local intro = require("cfn.lib.status.intro")
local template_registrations = require("cfn.lib.status.template_registrations")

---@class Highlight
---@field line integer
---@field col_start integer
---@field col_end integer
---@field hl_group string

---@class InteractivityHandlers
---@field open? fun(winid: integer?, bufnr: integer?)
---@field close? fun(winid: integer?, bufnr: integer?)
---@field enter? fun(winid: integer?, bufnr: integer?)

---@alias InteractivityMap { [integer]: InteractivityHandlers }

---@alias StatusWindowDataHandler fun(content: string[], highlights: Highlight[], interactivity_map: InteractivityMap)

local NS = vim.api.nvim_create_namespace("cfn.status")
---@type integer?
local winid = nil
---@type integer?
local bufnr = nil
---@type InteractivityMap
local interactivity_map = {}

---@param type "open" | "close" | "enter"
local handle_interaction = function(type)
  return function()
    local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    local interactions = interactivity_map[current_line]
    if interactions and interactions[type] then
      interactions[type](winid, bufnr)
      M.render()
    end
  end
end

local function window_is_open()
  return winid ~= nil and vim.api.nvim_win_is_valid(winid) and bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)
end

function M.open()
  if window_is_open() then
    vim.api.nvim_set_current_win(assert(winid))
    return
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "cfn-status"
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      winid = nil
      bufnr = nil
    end,
  })

  winid = vim.api.nvim_open_win(bufnr, false, {
    split = "above",
    win = -1,
    height = config.options.status_window.height,
  })
  vim.wo[winid].winfixheight = true
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].cursorline = false
  vim.wo[winid].signcolumn = "no"

  vim.api.nvim_set_current_win(winid)

  vim.keymap.set("n", ">", handle_interaction("open"), { buffer = bufnr, nowait = true, silent = true })
  vim.keymap.set("n", "<", handle_interaction("close"), { buffer = bufnr, nowait = true, silent = true })
  vim.keymap.set("n", "<CR>", handle_interaction("enter"), { buffer = bufnr, nowait = true, silent = true })

  M.render()
end

function M.close()
  if window_is_open() then
    vim.api.nvim_win_close(assert(winid), true)
  end
end

function M.toggle()
  if window_is_open() then
    M.close()
  else
    M.open()
  end
end

function M.render()
  if not window_is_open() then
    return
  end
  ---@type string[]
  local content = {}
  ---@type Highlight[]
  local highlights = {}
  interactivity_map = {}

  intro.get_status_window_data(content, highlights, interactivity_map)
  template_registrations.get_status_window_data(content, highlights, interactivity_map)

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(assert(bufnr), 0, -1, false, content)
  vim.api.nvim_buf_clear_namespace(assert(bufnr), NS, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(assert(bufnr), NS, hl.line, hl.col_start, {
      end_col = hl.col_end,
      hl_group = hl.hl_group,
    })
  end
  vim.bo[bufnr].modifiable = false
end

state.template_registration:on_change(M.render)

return M
