local M = {}

local notify = require("cfn.lib.notify")

M.CANCELLED = "tag input cancelled"

local ns = vim.api.nvim_create_namespace("cfn_tag_form")
---@type integer?
local bufnr
---@type integer?
local winid
---@type boolean
local submitted = false
---@type boolean
local reconcile_scheduled = false

---@alias TagObject { [string]: string }

local function window_is_open()
  return winid ~= nil and vim.api.nvim_win_is_valid(winid) and bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)
end

---@param tag_object TagObject
---@return CfnLspTag[]
function M.to_array(tag_object)
  ---@type CfnLspTag[]
  local tags = {}
  for key, value in pairs(tag_object) do
    table.insert(tags, { Key = key, Value = value })
  end
  return tags
end

---@param tag_array CfnLspTag[]
---@return TagObject
function M.to_object(tag_array)
  ---@type TagObject
  local tags = {}
  for _, tag in ipairs(tag_array) do
    tags[tag.Key] = tag.Value
  end
  return tags
end

---@return { [number]: string } errors keyed by 1-based line number
local function validate_window_state()
  if not window_is_open() then
    return { [1] = "window not open" }
  end
  ---@type { [number]: string }
  local errors = {}
  local lines = vim.api.nvim_buf_get_lines(assert(bufnr), 0, -1, false)
  ---@type { [string]: boolean }
  local seen_keys = {}
  for line_no, line in ipairs(lines) do
    if line == "" then
      goto continue
    end
    if not line:find("=", 1, true) then
      errors[line_no] = "line is missing = (key=value expected)"
      goto continue
    end
    local key, value = line:match("^(.-)=(.*)$")
    if key == "" then
      errors[line_no] = "key or value is empty"
      goto continue
    end
    if #key > 128 then
      errors[line_no] = "key is longer than 128 characters"
      goto continue
    end
    if #value > 256 then
      errors[line_no] = "value is longer than 256 characters"
      goto continue
    end
    if seen_keys[key] then
      errors[line_no] = "duplicate key: " .. key
      goto continue
    end
    seen_keys[key] = true
    ::continue::
  end
  return errors
end


---@param validation_errs { [number]: string }?
local function render_decorations(validation_errs)
  vim.api.nvim_buf_clear_namespace(assert(bufnr), ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(assert(bufnr), 0, -1, false)
  if #lines == 1 and lines[1] == "" then
    vim.api.nvim_buf_set_extmark(assert(bufnr), ns, 0, 0, {
      virt_text = { { "one key=value per line (i.e. Environment=production)", "Comment" } },
      virt_text_pos = "overlay",
    })
    return
  end
  for i, line in ipairs(lines) do
    local eq = line:find("=", 1, true)
    if eq then
      vim.api.nvim_buf_set_extmark(assert(bufnr), ns, i - 1, 0, {
        end_col = eq - 1,
        end_right_gravity = true,
        hl_group = "Label",
      })
    end
  end
  for line_no, err in pairs(validation_errs or {}) do
    vim.api.nvim_buf_set_extmark(assert(bufnr), ns, line_no - 1, 0, {
      virt_text = { { err, "DiagnosticError" } },
      virt_text_pos = "eol",
    })
  end
end

---@param tags TagObject
local function reconcile(tags)
  reconcile_scheduled = false
  if not window_is_open() then
    return
  end
  for key in pairs(tags) do
    tags[key] = nil
  end
  local validation_errs = validate_window_state()
  render_decorations(validation_errs)
  if next(validation_errs) == nil then
    local lines = vim.api.nvim_buf_get_lines(assert(bufnr), 0, -1, false)
    for _, line in ipairs(lines) do
      local key, value = line:match("^(.-)=(.*)$")
      if key ~= nil and key ~= "" then
        tags[key] = value
      end
    end
  end
end

---@param tags CfnLspTag[]?
---@return string? error_message
---@return CfnLspTag[]?
function M.collect_tags(tags)
  local tag_object = M.to_object(tags or {})
  local co = assert(coroutine.running(), "collect_tags must be called from a coroutine")
  if window_is_open() then
    vim.api.nvim_set_current_win(assert(winid))
    return "tag collection already in progress"
  end
  submitted = false

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      winid = nil
      bufnr = nil
      local err, values
      if submitted then
        values = M.to_array(tag_object)
      else
        err = M.CANCELLED
      end
      vim.schedule(function()
        local ok, resume_err = coroutine.resume(co, err, values)
        if not ok then
          notify.error(resume_err)
        end
      end)
    end,
  })
  local cols = vim.o.columns
  local rows = vim.o.lines
  local width = math.min(80, cols - 4)
  local height = math.min(20, rows - 6)
  local row = math.floor((rows - height) / 2)
  local col = math.floor((cols - width) / 2)
  winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    title = "Tags",
    border = "rounded",
    footer = "q=close <C-s>=submit",
    footer_pos = "left",
  })
  vim.api.nvim_set_current_win(winid)
  local undolevels = vim.bo[bufnr].undolevels
  vim.bo[bufnr].undolevels = -1
  local initial_buffer = {}
  for key, value in pairs(tag_object) do
    table.insert(initial_buffer, key .. "=" .. tostring(value))
  end
  if #initial_buffer > 0 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_buffer)
  end
  vim.bo[bufnr].undolevels = undolevels
  reconcile(tag_object)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      if not reconcile_scheduled then
        reconcile_scheduled = true
        vim.schedule(function()
          reconcile(tag_object)
        end)
      end
    end,
  })
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(winid, true)
  end, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-s>", function()
    local validation_errs = validate_window_state()
    if next(validation_errs) ~= nil then
      notify.error("cannot submit tags:\n" .. table.concat(vim.tbl_values(validation_errs), "\n"))
      return
    end
    reconcile(tag_object)
    submitted = true
    vim.api.nvim_win_close(winid, true)
  end, { buffer = bufnr, nowait = true, desc = "submit tags" })
  return coroutine.yield()
end

return M
