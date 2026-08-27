local M = {}

local range = require("cfn.lib.treesitter.range")

local RESOURCES_QUERY = [[
  ;;query
  (document
    (object
      (pair
        key: (string (string_content) @_resourceskey)
        value: (object
          (pair
            key: (string (string_content) @logicalid)
            value: (object
              (pair
                key: (string (string_content) @_typekey)
                value: (string (string_content) @type)
              )
            )
          ) @resource
        )
      )
    )
   (#eq? @_resourceskey "Resources")
   (#eq? @_typekey "Type")
  )
]]

local REFERENCES_QUERY = [[
  ;; query
  ((pair key: (string (string_content) @_k) value: (string (_) @ref)) (#eq? @_k "Ref"))
  ((pair key: (string (string_content) @_k) value: (array . (string (_) @getatt))) (#eq? @_k "Fn::GetAtt"))
  ((pair key: (string (string_content) @_k) value: (string (_) @getatt)) (#eq? @_k "Fn::GetAtt"))
  ((pair key: (string (string_content) @_k) value: (string (_) @sub)) (#eq? @_k "Fn::Sub"))
  ((pair key: (string (string_content) @_k) value: (array) @sub) (#eq? @_k "Fn::Sub"))
  ((pair key: (string (string_content) @_k) value: (array (string (_) @dependson ) )) (#eq? @_k "DependsOn"))
  ((pair key: (string (string_content) @_k) value: (string (_) @dependson)) (#eq? @_k "DependsOn"))
]]

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
  local ts_query = vim.treesitter.query.parse(parser:lang(), RESOURCES_QUERY)
  if ts_query == nil then
    return resources
  end
  for _, match in ts_query:iter_matches(root, bufnr) do
    local logicalid_node, resource_node, typevalue_node
    for id, nodes in pairs(match) do
      local name = ts_query.captures[id]
      if name == "logicalid" then
        logicalid_node = nodes[#nodes]
      elseif name == "resource" then
        resource_node = nodes[#nodes]
      elseif name == "type" then
        typevalue_node = nodes[#nodes]
      end
    end
    if logicalid_node and resource_node and typevalue_node then
      table.insert(resources, {
        logical_id = {
          name = vim.treesitter.get_node_text(logicalid_node, bufnr),
          range = range.node_to_range(logicalid_node),
        },
        type = vim.treesitter.get_node_text(typevalue_node, bufnr),
        range = range.node_to_range(resource_node),
      })
    end
  end
  return resources
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_ref = function(bufnr, payload, out)
  local ref_range = range.node_to_range(payload)
  local ref_name = vim.treesitter.get_node_text(payload, bufnr)
  ref_name = ref_name:match("^[^.]+") or ref_name
  ref_range.end_pos.character = ref_range.start_pos.character + #ref_name
  table.insert(out, {
    logical_id = ref_name,
    range = ref_range,
    kind = "ref",
  })
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_getatt = function(bufnr, payload, out)
  local ref_range = range.node_to_range(payload)
  local ref_name = vim.treesitter.get_node_text(payload, bufnr)
  -- match ${LogicalId} or ${LogicalId.attr}, and the plain "LogicalId.Attr" form
  ref_name = ref_name:match("%${([^.}]+)") or ref_name:match("^([^.]+)")
  ref_range.end_pos.character = ref_range.start_pos.character + #ref_name
  table.insert(out, {
    logical_id = ref_name,
    range = ref_range,
    kind = "getatt",
  })
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_dependson = function(bufnr, payload, out)
  local ref_range = range.node_to_range(payload)
  local ref_name = vim.treesitter.get_node_text(payload, bufnr)
  table.insert(out, {
    logical_id = ref_name,
    range = ref_range,
    kind = "dependson",
  })
end

---@param node TSNode  -- a string node
---@return TSNode?
local string_content_of = function(node)
  for child in node:iter_children() do
    if child:type() == "string_content" then
      return child
    end
  end
end

---@param array TSNode
---@return TSNode[]
local array_items = function(array)
  local items = {}
  for _, child in ipairs(array:named_children()) do
    table.insert(items, child)
  end
  return items
end

---@param bufnr integer
---@param content TSNode  -- a string_content node
---@param out Reference[]
---@param ignore_map table<string, boolean>?
local extract_sub_string_content = function(bufnr, content, out, ignore_map)
  local content_range = range.node_to_range(content)
  local text = vim.treesitter.get_node_text(content, bufnr)
  local base_line = content_range.start_pos.line
  local base_char = content_range.start_pos.character
  local col = 1
  while col <= #text do
    if text:sub(col, col) == "$" and text:sub(col + 1, col + 1) == "{" then
      local close = text:find("}", col + 2, true)
      if close == nil then
        break
      end
      local variable_reference = text:sub(col + 2, close - 1)
      local logical_id = variable_reference:match("^[^.!]+") or variable_reference
      if not (ignore_map and ignore_map[variable_reference]) then
        local id_start = base_char + col + 1
        table.insert(out, {
          logical_id = logical_id,
          range = {
            start_pos = { line = base_line, character = id_start },
            end_pos = { line = base_line, character = id_start + #logical_id },
          },
          kind = "sub",
        })
      end
      col = close + 1
    else
      col = col + 1
    end
  end
end

---@param bufnr integer
---@param payload TSNode  -- an array node
---@param out Reference[]
local extract_sub_array = function(bufnr, payload, out)
  local items = array_items(payload)
  local template = items[1]
  if template == nil or template:type() ~= "string" then
    return
  end

  -- keys defined in the second item are local Sub variables, not references
  local ignore_map = {}
  if items[2] and items[2]:type() == "object" then
    for pair in items[2]:iter_children() do
      if pair:type() == "pair" then
        local key = pair:field("key")[1]
        local key_content = key and string_content_of(key)
        if key_content then
          ignore_map[vim.treesitter.get_node_text(key_content, bufnr)] = true
        end
      end
    end
  end

  -- a string with escape sequences (e.g. \n) is split into multiple
  -- string_content nodes; scan each segment
  for child in template:iter_children() do
    if child:type() == "string_content" then
      extract_sub_string_content(bufnr, child, out, ignore_map)
    end
  end
end

---@param bufnr integer
---@param payload TSNode
---@param out Reference[]
local extract_sub = function(bufnr, payload, out)
  if payload:type() == "array" then
    extract_sub_array(bufnr, payload, out)
  else
    extract_sub_string_content(bufnr, payload, out)
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
  local ts_query = vim.treesitter.query.parse(parser:lang(), REFERENCES_QUERY)
  if ts_query == nil then
    return references
  end
  for _, match in ts_query:iter_matches(root, bufnr) do
    for captures_id, captures in pairs(match) do
      local capture_name = ts_query.captures[captures_id]
      if capture_name == "ref" then
        for _, ref_node in ipairs(captures) do
          extract_ref(bufnr, ref_node, references)
        end
      elseif capture_name == "getatt" then
        for _, ref_node in ipairs(captures) do
          extract_getatt(bufnr, ref_node, references)
        end
      elseif capture_name == "dependson" then
        for _, ref_node in ipairs(captures) do
          extract_dependson(bufnr, ref_node, references)
        end
      elseif capture_name == "sub" then
        for _, ref_node in ipairs(captures) do
          extract_sub(bufnr, ref_node, references)
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
