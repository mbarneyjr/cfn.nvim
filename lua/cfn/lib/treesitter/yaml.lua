local M = {}

local range = require("cfn.lib.treesitter.range")
local QUERY = [[
  ;; query
  ;; short-form intrinsic tags: !Ref / !GetAtt / !Sub
  (tag) @tag
  ;; long-form keys: Ref: / Fn::GetAtt: / Fn::Sub: / DependsOn:
  (block_mapping_pair) @pair
  ;; inline long-form: { Ref: ... }
  (flow_pair) @pair
]]

local INTRINSIC_FUNCTIONS = {
  ["!Ref"] = "ref",
  ["Ref"] = "ref",
  ["!GetAtt"] = "getatt",
  ["Fn::GetAtt"] = "getatt",
  ["!Sub"] = "sub",
  ["Fn::Sub"] = "sub",
  ["DependsOn"] = "dependson",
} ---@param node TSNode
---@param bufnr integer
---@return string
---@return BufferRange
local function unquote_scalar(node, bufnr)
  local scalar = node
  if node:type() == "flow_node" then
    scalar = assert(node:named_child(0))
  end
  local scalar_range = range.node_to_range(scalar)
  local text = vim.treesitter.get_node_text(scalar, bufnr)
  local t = scalar:type()
  if t == "double_quote_scalar" or t == "single_quote_scalar" then
    scalar_range.start_pos.character = scalar_range.start_pos.character + 1
    scalar_range.end_pos.character = scalar_range.end_pos.character - 1
    return text:sub(2, -2), scalar_range
  end
  return text, scalar_range
end

---@class TSNodeSet
---@field bufnr integer
---@field nodes TSNode[]
---@field children_of_types fun(self: TSNodeSet, types: string[]): TSNodeSet
---@field field fun(self: TSNodeSet, name: string): TSNodeSet
---@field values_of_keys fun(self: TSNodeSet, keys: string[]): TSNodeSet
---@field keys fun(self: TSNodeSet): TSNodeSet
local TSNodeSet = {}
TSNodeSet.__index = TSNodeSet

---@param bufnr integer
---@param nodes TSNode[]
---@return TSNodeSet
local function wrap(bufnr, nodes)
  return setmetatable({
    bufnr = bufnr,
    nodes = nodes,
  }, TSNodeSet)
end

function TSNodeSet:children_of_types(types)
  local type_map = {}
  for _, t in ipairs(types) do
    type_map[t] = true
  end
  local out = {}
  for _, node in ipairs(self.nodes) do
    for child in node:iter_children() do
      if type_map[child:type()] then
        table.insert(out, child)
      end
    end
  end
  return wrap(self.bufnr, out)
end

function TSNodeSet:field(name)
  local out = {}
  for _, node in ipairs(self.nodes) do
    for _, c in ipairs(node:field(name)) do
      table.insert(out, c)
    end
  end
  return wrap(self.bufnr, out)
end

function TSNodeSet:values_of_keys(keys)
  local key_map = {}
  for _, t in ipairs(keys) do
    key_map[t] = true
  end
  local out = {}
  for _, node in ipairs(self.nodes) do
    for _, c in ipairs(node:field("key")) do
      if key_map[unquote_scalar(c, self.bufnr)] then
        for _, v in ipairs(node:field("value")) do
          table.insert(out, v)
        end
      end
    end
  end
  return wrap(self.bufnr, out)
end

function TSNodeSet:keys()
  local out = {}
  for _, node in ipairs(self.nodes) do
    for _, c in ipairs(node:field("key")) do
      table.insert(out, c)
    end
  end
  return wrap(self.bufnr, out)
end

---@param bufnr integer
---@return ResourceLocation[]
function M.list_resources(bufnr)
  ---@type ResourceLocation[]
  local resources = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or parser == nil then
    return resources
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  local resource_key_nodes = wrap(bufnr, { root })
    :children_of_types({ "document" })
    :children_of_types({ "block_node", "flow_node" })
    :children_of_types({ "block_mapping", "flow_mapping" })
    :children_of_types({ "block_mapping_pair", "flow_pair" })
    :values_of_keys({ "Resources" })
    :children_of_types({ "block_mapping", "flow_mapping" })
    :children_of_types({ "block_mapping_pair", "flow_pair" })
    :keys()

  for _, resource_key_node in ipairs(resource_key_nodes.nodes) do
    local resource_node = resource_key_node:parent()
    if resource_node == nil then
      goto continue
    end
    local key_text, key_range = unquote_scalar(resource_key_node, bufnr)
    local value_nodes = wrap(bufnr, { resource_key_node:parent() }):field("value")
    if #value_nodes.nodes == 0 then
      goto continue
    end

    local type_nodes = value_nodes
      :children_of_types({ "block_mapping", "flow_mapping" })
      :children_of_types({ "block_mapping_pair", "flow_pair" })
      :values_of_keys({ "Type" })
    if #type_nodes.nodes == 0 then
      goto continue
    end

    local type_text = unquote_scalar(type_nodes.nodes[1], bufnr)
    ---@type ResourceLocation
    local resource_location = {
      logical_id = {
        name = key_text,
        range = key_range,
      },
      type = type_text,
      range = range.node_to_range(resource_node),
    }
    table.insert(resources, resource_location)
    ::continue::
  end

  return resources
end

---@param node TSNode  -- a block_scalar
---@param bufnr integer
---@return string? text  -- first non-blank content line, trimmed
---@return BufferRange?
local function block_scalar_token(node, bufnr)
  local srow = node:start()
  local erow = node:end_()
  -- content is everything after the header row (srow); body rows are srow+1 .. erow
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow + 1, erow + 1, false)
  for i, line in ipairs(lines) do
    local lead, token = line:match("^(%s*)(%S.*)$")
    if token then
      token = token:gsub("%s+$", "")
      local row, col = srow + i, #lead
      ---@type BufferRange
      local r = {
        start_pos = { line = row, character = col },
        end_pos = { line = row, character = col + #token },
      }
      return token, r
    end
  end
end

---@return string?, BufferRange?
local function scalar_value(node, bufnr)
  if node:type() == "block_scalar" then
    return block_scalar_token(node, bufnr)
  end
  return unquote_scalar(node, bufnr)
end

---@param sequence TSNode
---@return TSNode[]
local function sequence_items(sequence)
  local items = {}
  for child in sequence:iter_children() do
    if child:type() == "flow_node" then
      table.insert(items, child)
    elseif child:type() == "block_sequence_item" then
      local inner = child:named_child(0)
      if inner and inner:type() == "block_node" then
        inner = inner:named_child(0)
      end
      if inner then
        table.insert(items, inner)
      end
    end
  end
  return items
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_ref = function(bufnr, payload, out)
  local name, r = scalar_value(payload, bufnr)
  if payload:type() == "block_scalar" then
    name, r = block_scalar_token(payload, bufnr)
  else
    name, r = unquote_scalar(payload, bufnr)
  end
  if name ~= nil and r ~= nil then
    table.insert(out, { logical_id = name, range = r, kind = "ref" })
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_getatt = function(bufnr, payload, out)
  if payload:type() == "flow_sequence" or payload:type() == "block_sequence" then
    local first = sequence_items(payload)[1]
    if first then
      local name, r = scalar_value(first, bufnr)
      if name ~= nil and r ~= nil then
        table.insert(out, { logical_id = name, range = r, kind = "getatt" })
      end
    end
  else
    local name, r = scalar_value(payload, bufnr)
    if name ~= nil and r ~= nil then
      name = name:match("^[^.]+") or name
      r.end_pos.character = r.start_pos.character + #name
      table.insert(out, { logical_id = name, range = r, kind = "getatt" })
    end
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_dependson = function(bufnr, payload, out)
  if payload:type() == "flow_sequence" or payload:type() == "block_sequence" then
    for _, item in ipairs(sequence_items(payload)) do
      local name, r = scalar_value(item, bufnr)
      if name ~= nil and r ~= nil then
        table.insert(out, { logical_id = name, range = r, kind = "dependson" })
      end
    end
  else
    local name, r = scalar_value(payload, bufnr)
    if name ~= nil and r ~= nil then
      table.insert(out, { logical_id = name, range = r, kind = "dependson" })
    end
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
---@param ignore_map table<string, boolean>?
local extract_sub_block_scalar = function(bufnr, payload, out, ignore_map)
  local payload_start_line = payload:start()
  local payload_end_line = payload:end_()
  local lines = vim.api.nvim_buf_get_lines(bufnr, payload_start_line + 1, payload_end_line + 1, false)
  for i, line in ipairs(lines) do
    local sub_row = payload_start_line + i
    for sub_col = 1, #line do
      if line:sub(sub_col, sub_col) == "$" and line:sub(sub_col + 1, sub_col + 1) == "{" then
        local close = line:find("}", sub_col + 2, true)
        if close ~= nil then
          local variable_reference = line:sub(sub_col + 2, close - 1)
          local logical_id = variable_reference:match("^[^.!]+") or variable_reference
          if not (ignore_map and ignore_map[variable_reference]) then
            local id_start = sub_col + 1
            table.insert(out, {
              logical_id = logical_id,
              range = {
                start_pos = { line = sub_row, character = id_start },
                end_pos = { line = sub_row, character = id_start + #logical_id },
              },
              kind = "sub",
            })
          end
        end
      end
    end
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
---@param ignore_map table<string, boolean>?
local extract_sub_scalar = function(bufnr, payload, out, ignore_map)
  local name, r = scalar_value(payload, bufnr)
  if name == nil or r == nil then
    return
  end
  for sub_row, sub_line in ipairs(vim.split(name, "\n")) do
    for sub_col = 1, #sub_line do
      if sub_line:sub(sub_col, sub_col) == "$" and sub_line:sub(sub_col + 1, sub_col + 1) == "{" then
        local close = sub_line:find("}", sub_col + 2, true)
        if close ~= nil then
          local variable_reference = sub_line:sub(sub_col + 2, close - 1)
          local logical_id = variable_reference:match("^[^.!]+") or variable_reference
          if not (ignore_map and ignore_map[variable_reference]) then
            local base_char = sub_row == 1 and r.start_pos.character or 0
            local id_start = base_char + sub_col + 1
            table.insert(out, {
              logical_id = logical_id,
              range = {
                start_pos = { line = r.start_pos.line + (sub_row - 1), character = id_start },
                end_pos = { line = r.start_pos.line + (sub_row - 1), character = id_start + #logical_id },
              },
              kind = "sub",
            })
          end
          sub_col = sub_col + (close - sub_col)
        end
      end
    end
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_sub_sequence = function(bufnr, payload, out)
  local items = sequence_items(payload)
  if #items < 2 then
    return
  end

  -- capture all the keys in the second item, which should be ignored as matches in the first item
  local ignore_map = {}
  local sub_mapping_key_nodes =
    wrap(bufnr, { items[2] }):children_of_types({ "block_mapping_pair", "flow_pair" }):keys()
  for _, key_node in ipairs(sub_mapping_key_nodes.nodes) do
    ignore_map[unquote_scalar(key_node, bufnr)] = true
  end

  if items[1]:type() == "block_scalar" then
    extract_sub_block_scalar(bufnr, items[1], out, ignore_map)
  else
    extract_sub_scalar(bufnr, items[1], out, ignore_map)
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_sub = function(bufnr, payload, out)
  if payload:type() == "block_scalar" then
    extract_sub_block_scalar(bufnr, payload, out)
  elseif payload:type() == "block_sequence" or payload:type() == "flow_sequence" then
    extract_sub_sequence(bufnr, payload, out)
  else
    extract_sub_scalar(bufnr, payload, out)
  end
end

---@param kind string
---@param payload TSNode|nil
---@param bufnr integer
---@param out Reference[]
local function extract_references(kind, payload, bufnr, out)
  if not payload then
    return
  end
  local payload_type = payload:type()
  if payload_type == "flow_node" or payload_type == "block_node" then
    payload = payload:named_child(0) or payload
    payload_type = payload:type()
  end
  if kind == "ref" then
    extract_ref(bufnr, payload, out)
  elseif kind == "getatt" then
    extract_getatt(bufnr, payload, out)
  elseif kind == "dependson" then
    extract_dependson(bufnr, payload, out)
  elseif kind == "sub" then
    extract_sub(bufnr, payload, out)
  end
end

---@param bufnr integer
---@param logical_id string
---@return Reference[]
function M.list_references(bufnr, logical_id)
  ---@type Reference[]
  local references = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or parser == nil then
    return references
  end
  local tree = parser:parse()[1]
  local root = tree:root()
  local ts_query = vim.treesitter.query.parse(parser:lang(), QUERY)
  if ts_query == nil then
    return references
  end
  for _, match in ts_query:iter_matches(root, bufnr) do
    for captures_id, captures in pairs(match) do
      local capture_name = ts_query.captures[captures_id]
      if capture_name == "tag" then
        for _, tag in ipairs(captures) do
          local kind = INTRINSIC_FUNCTIONS[vim.treesitter.get_node_text(tag, bufnr)]
          if kind then
            extract_references(kind, tag:next_named_sibling(), bufnr, references)
          end
        end
      elseif capture_name == "pair" then
        for _, pair in ipairs(captures) do
          local key = pair:field("key")[1]
          if key then
            local kind = INTRINSIC_FUNCTIONS[unquote_scalar(key, bufnr)]
            local value = pair:field("value")[1]
            if kind and value then
              extract_references(kind, value, bufnr, references)
            end
          end
        end
      end
    end
  end

  local out = {}
  for _, ref in ipairs(references) do
    if ref.logical_id == logical_id then
      table.insert(out, ref)
    end
  end
  return out
end

return M
