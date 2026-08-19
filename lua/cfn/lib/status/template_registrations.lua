local M = {}

local state = require("cfn.lib.state")
local arrow = require("cfn.lib.status.builder").arrow

---@type { [string]: boolean }
local open_templates = {}
---@type { [string]: boolean }
local open_imports = {}

---@param resource_identifier table<string,string>
local function resource_identifier_to_string(resource_identifier)
  local parts = {}
  for _, v in pairs(resource_identifier) do
    table.insert(parts, v)
  end
  return table.concat(parts, "|")
end

---@param path string
---@param winid integer?
local function edit_template(path, winid)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= winid and vim.api.nvim_win_get_config(w).relative == "" then
      vim.api.nvim_set_current_win(w)
      vim.cmd.edit(path)
      vim.api.nvim_win_close(assert(winid), true)
      return
    end
  end
  vim.cmd("botright split " .. vim.fn.fnameescape(path))
  vim.api.nvim_win_close(assert(winid), true)
end

---@type StatusWindowDataHandler
function M.get_status_window_data(builder)
  for key, value in pairs(state.template_registration:list()) do
    local path = vim.fn.fnamemodify(key, ":.")

    builder:line({
      { arrow(open_templates[path]) .. " " },
      { path, "String" },
      { ": " },
      { value.stack_name, "Normal" },
      { " " },
      { string.format("(%s/%s)", value.profile, value.region), "Comment" },
    }, {
      open = function()
        open_templates[path] = true
      end,
      close = function()
        open_templates[path] = false
      end,
      enter = function(winid)
        edit_template(path, winid)
      end,
    })

    if open_templates[path] then
      if value.artifact_bucket_name then
        builder:line({
          { "    " },
          { "saving artifacts to", "Label" },
          { ": s3://" .. value.artifact_bucket_name, "Normal" },
        })
      end

      local resources_to_import = state.resources_to_import:get(key)
      if resources_to_import ~= nil and #resources_to_import.resources > 0 then
        builder:line({
          { "  " .. arrow(open_imports[path]) .. " " },
          { "resources to import (" .. #resources_to_import.resources .. ")", "Label" },
        }, {
          open = function()
            open_imports[path] = true
          end,
          close = function()
            open_imports[path] = false
          end,
        })

        if open_imports[path] then
          for _, r in ipairs(resources_to_import.resources) do
            builder:line({
              { "      " },
              { r.LogicalResourceId .. " (" .. r.ResourceType .. ")", "Label" },
              { ": " .. resource_identifier_to_string(r.ResourceIdentifier), "Normal" },
            })
          end
        end
      end

      local active_changeset = state.active_changeset:get(path)
      if active_changeset ~= nil then
        builder:line({
          { "    " },
          { "loaded changeset", "Label" },
          { ": " .. active_changeset.changeSetName, "Normal" },
        })
      end
    end
  end
end

return M
