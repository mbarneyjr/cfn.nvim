local M = {}

local config = require("cfn.lib.config")

---@param open boolean?
function M.arrow(open)
  return open and config.options.icons.arrow_open or config.options.icons.arrow_closed
end

---@class StatusSegment
---@field [1] string
---@field [2]? HighlightGroupBuiltin

---@class StatusBuilder
---@field content string[]
---@field highlights Highlight[]
---@field interactivity_map InteractivityMap
local Builder = {}
Builder.__index = Builder

---@return StatusBuilder
function M.new()
  return setmetatable({ content = {}, highlights = {}, interactivity_map = {} }, Builder)
end

---@param segments StatusSegment[]
---@param handlers? InteractivityHandlers
---@return integer line
function Builder:line(segments, handlers)
  local line = #self.content
  local text = ""
  for _, segment in ipairs(segments) do
    if segment[2] and #segment[1] > 0 then
      table.insert(self.highlights, {
        line = line,
        col_start = #text,
        col_end = #text + #segment[1],
        hl_group = segment[2],
      })
    end
    text = text .. segment[1]
  end
  table.insert(self.content, text)
  if handlers then
    self.interactivity_map[line] = handlers
  end
  return line
end

return M
