local M = {}

local yaml = require("cfn.lib.treesitter.yaml")
local json = require("cfn.lib.treesitter.json")

---@class BufferRange
---@field start_pos { line: integer, character: integer }
---@field end_pos { line: integer, character: integer }

---@class ResourceLocation
---@field logical_id { name: string, range: BufferRange }
---@field type string
---@field range BufferRange

---@class Reference
---@field logical_id string the id this reference points at
---@field kind "ref" | "getatt" | "sub" | "dependson"
---@field range BufferRange exact, end-exclusive span of the id token

---@param line integer 0-indexed
---@param col integer 0-indexed
---@param range BufferRange
---@return boolean
local function cursor_in_range(line, col, range)
  if line < range.start_pos.line or line > range.end_pos.line then
    return false
  end
  if line == range.start_pos.line and col < range.start_pos.character then
    return false
  end
  if line == range.end_pos.line and col > range.end_pos.character then
    return false
  end
  return true
end

---@param bufnr integer
---@return string?
local function get_buffer_treesitter_language(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or parser == nil then
    return nil
  end
  return parser:lang()
end

---@param bufnr integer
---@return ResourceLocation[]
function M.list_resources(bufnr)
  local lang = get_buffer_treesitter_language(bufnr)
  if lang == "yaml" then
    return yaml.list_resources(bufnr)
  elseif lang == "json" then
    return json.list_resources(bufnr)
  end
  return {}
end

---@param bufnr integer
---@return ResourceLocation?
function M.resource_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local col = cursor[2]
  for _, resource in ipairs(M.list_resources(bufnr)) do
    if cursor_in_range(line, col, resource.range) then
      return resource
    end
  end
  return nil
end

---@param bufnr integer
---@param logical_id string
---@return ResourceLocation?
function M.get_resource_by_logical_id(bufnr, logical_id)
  for _, resource in ipairs(M.list_resources(bufnr)) do
    if resource.logical_id.name == logical_id then
      return resource
    end
  end
  return nil
end

---@param bufnr integer
---@param logical_id string
---@return Reference[]
function M.list_references(bufnr, logical_id)
  local lang = get_buffer_treesitter_language(bufnr)
  if lang == "yaml" then
    return yaml.list_references(bufnr, logical_id)
  elseif lang == "json" then
    return json.list_references(bufnr, logical_id)
  end
  return {}
end

return M
