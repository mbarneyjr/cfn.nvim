local M = {}

local notify = require("cfn.lib.notify")
local ui = require("cfn.lib.ui")
local treesitter = require("cfn.lib.treesitter")

---@param a BufferRange
---@param b BufferRange
---@return boolean true when `a` starts after `b` in the buffer
local function starts_after(a, b)
  if a.start_pos.line ~= b.start_pos.line then
    return a.start_pos.line > b.start_pos.line
  end
  return a.start_pos.character > b.start_pos.character
end

---Replace the text spanned by `range` (0-indexed, end-exclusive) with `text`.
---@param bufnr integer
---@param range BufferRange
---@param text string
local function replace_range(bufnr, range, text)
  vim.api.nvim_buf_set_text(
    bufnr,
    range.start_pos.line,
    range.start_pos.character,
    range.end_pos.line,
    range.end_pos.character,
    { text }
  )
end

function M.rename()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()

    local resource = treesitter.resource_at_cursor(bufnr)
    if resource == nil then
      notify.error("no resource found under cursor")
      return
    end

    local old_name = resource.logical_id.name
    local new_name = ui.input({ prompt = "New Logical ID", default = old_name })
    if new_name == nil or new_name == "" or new_name == old_name then
      notify.info("rename cancelled")
      return
    end

    if new_name:match("^%w+$") == nil then
      notify.error("logical ids must be alphanumeric")
      return
    end

    if treesitter.get_resource_by_logical_id(bufnr, new_name) ~= nil then
      notify.error(string.format("a resource named %q already exists", new_name))
      return
    end

    local references = treesitter.list_references(bufnr, old_name)

    local ranges = { resource.logical_id.range }
    for _, reference in ipairs(references) do
      table.insert(ranges, reference.range)
    end
    table.sort(ranges, starts_after)

    for _, range in ipairs(ranges) do
      replace_range(bufnr, range, new_name)
    end

    notify.info(
      string.format(
        "renamed %s to %s (%d reference%s)",
        old_name,
        new_name,
        #references,
        #references == 1 and "" or "s"
      )
    )
  end)()
end

return M
