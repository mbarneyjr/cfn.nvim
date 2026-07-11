local M = {}

local treesitter = require("cfn.lib.treesitter")

local NS = vim.api.nvim_create_namespace("cfn_resource_highlight")
---@type {[number]: {[string]:number}}
local extmarks = {}

---@param bufnr number
---@param logical_id string
local function get_extmark_id(bufnr, logical_id)
  return extmarks[bufnr] and extmarks[bufnr][logical_id] or nil
end

---@param bufnr number
---@param logical_id string
---@param extmark_id number
local function set_extmark_id(bufnr, logical_id, extmark_id)
  if not extmarks[bufnr] then
    extmarks[bufnr] = {}
    vim.api.nvim_buf_attach(bufnr, false, {
      on_detach = function()
        extmarks[bufnr] = nil
      end,
    })
  end
  extmarks[bufnr][logical_id] = extmark_id
end

---@param bufnr number
---@param logical_id? string
---@return string? err
function M.clear(bufnr, logical_id)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return "invalid buffer: " .. tostring(bufnr)
  end
  if logical_id ~= nil then
    local extmark_id = get_extmark_id(bufnr, logical_id)
    if extmark_id ~= nil then
      local ok, err = pcall(vim.api.nvim_buf_del_extmark, bufnr, NS, extmark_id)
      if not ok then
        return tostring(err)
      end
      extmarks[bufnr][logical_id] = nil
    end
  else
    local ok, err = pcall(vim.api.nvim_buf_clear_namespace, bufnr, NS, 0, -1)
    if not ok then
      return tostring(err)
    end
    if extmarks[bufnr] ~= nil then
      extmarks[bufnr] = {}
    end
  end
end

---@param bufnr number
---@param logical_id string
---@param logical_id_highlight_group HighlightGroupBuiltin
---@param message? string
---@param message_highlight_group? HighlightGroupBuiltin
---@return string? err
function M.highlight(bufnr, logical_id, logical_id_highlight_group, message, message_highlight_group)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return "invalid buffer: " .. tostring(bufnr)
  end
  local resource = treesitter.get_resource_by_logical_id(bufnr, logical_id)
  if resource == nil then
    return "resource not found for logical id: " .. logical_id
  end
  local ok, result = pcall(
    vim.api.nvim_buf_set_extmark,
    bufnr,
    NS,
    resource.logical_id.range.start_pos.line,
    resource.logical_id.range.start_pos.character,
    {
      id = get_extmark_id(bufnr, logical_id),
      end_col = resource.logical_id.range.end_pos.character,
      hl_group = logical_id_highlight_group,
      virt_text = message ~= nil and { { message, message_highlight_group or "Normal" } } or nil,
      virt_text_pos = message ~= nil and "eol" or nil,
      priority = vim.hl.priorities.user,
    }
  )
  if not ok then
    return "failed to set extmark: " .. tostring(result)
  end
  set_extmark_id(bufnr, logical_id, result)
end

return M
