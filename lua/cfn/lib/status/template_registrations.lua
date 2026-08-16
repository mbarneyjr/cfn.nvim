local M = {}

local state = require("cfn.lib.state")
local config = require("cfn.lib.config")

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

---@type StatusWindowDataHandler
function M.get_status_window_data(content, highlights, interactivity_map)
  local template_registrations = state.template_registration:list()
  for key, value in pairs(template_registrations) do
    local current_line_number = #content
    local path = vim.fn.fnamemodify(key, ":.")
    local line_content = open_templates[path] and config.options.icons.arrow_open .. " "
      or config.options.icons.arrow_closed .. " "

    table.insert(highlights, {
      line = current_line_number,
      col_start = #line_content,
      col_end = #line_content + #path,
      hl_group = "String",
    })
    line_content = line_content .. path

    line_content = line_content .. ": "

    table.insert(highlights, {
      line = current_line_number,
      col_start = #line_content,
      col_end = #line_content + #value.stack_name,
      hl_group = "Normal",
    })
    line_content = line_content .. value.stack_name

    line_content = line_content .. " "

    local profile_region = string.format("(%s/%s)", value.profile, value.region)
    table.insert(highlights, {
      line = current_line_number,
      col_start = #line_content,
      col_end = #line_content + #profile_region,
      hl_group = "Comment",
    })
    line_content = line_content .. profile_region
    table.insert(content, line_content)

    interactivity_map[current_line_number] = {
      open = function()
        open_templates[path] = true
      end,
      close = function()
        open_templates[path] = false
      end,
      enter = function(winid)
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
      end,
    }
    current_line_number = #content

    -- if the current template is expanded
    if open_templates[path] then
      current_line_number = #content
      if value.artifact_bucket_name then
        line_content = "  "
        local artifact_subtitle = "  saving artifacts to"
        table.insert(highlights, {
          line = current_line_number,
          col_start = #line_content,
          col_end = #line_content + #artifact_subtitle,
          hl_group = "Label",
        })
        line_content = line_content .. artifact_subtitle

        local artifact_bucket_name = ": s3://" .. value.artifact_bucket_name
        table.insert(highlights, {
          line = current_line_number,
          col_start = #line_content,
          col_end = #line_content + #artifact_bucket_name,
          hl_group = "Normal",
        })
        line_content = line_content .. artifact_bucket_name

        table.insert(content, line_content)
        current_line_number = #content
      end

      local resources_to_import = state.resources_to_import:get(key)
      if resources_to_import ~= nil and #resources_to_import.resources > 0 then
        line_content = "  "
          .. (open_imports[path] == true and config.options.icons.arrow_open or config.options.icons.arrow_closed)
          .. " "
        local imports_subtitle = "resources to import (" .. #resources_to_import.resources .. ")"
        table.insert(highlights, {
          line = current_line_number,
          col_start = #line_content,
          col_end = #line_content + #imports_subtitle,
          hl_group = "Label",
        })
        line_content = line_content .. imports_subtitle
        table.insert(content, line_content)
        interactivity_map[current_line_number] = {
          open = function()
            open_imports[path] = true
          end,
          close = function()
            open_imports[path] = false
          end,
        }
        current_line_number = #content

        if open_imports[path] then
          for _, r in ipairs(resources_to_import.resources) do
            current_line_number = #content
            local current_column_number = 0
            local line = "      " .. r.LogicalResourceId .. " (" .. r.ResourceType .. ")"
            table.insert(
              highlights,
              { line = current_line_number, col_start = current_column_number, col_end = #line, hl_group = "Label" }
            )
            current_column_number = #line

            line = line .. ": " .. resource_identifier_to_string(r.ResourceIdentifier)
            table.insert(
              highlights,
              { line = current_line_number, col_start = current_column_number, col_end = #line, hl_group = "Normal" }
            )
            current_column_number = #line
            table.insert(content, line)
          end
        end
      end

      local active_changeset = state.active_changeset:get(path)
      if active_changeset ~= nil then
        line_content = "  "
        local changeset_subtitle = "  loaded changeset"
        table.insert(highlights, {
          line = current_line_number,
          col_start = #line_content,
          col_end = #line_content + #changeset_subtitle,
          hl_group = "Label",
        })
        line_content = line_content .. changeset_subtitle

        local changeset_name = ": " .. active_changeset.changeSetName
        table.insert(highlights, {
          line = current_line_number,
          col_start = #line_content,
          col_end = #line_content + #changeset_name,
          hl_group = "Normal",
        })
        line_content = line_content .. changeset_name

        table.insert(content, line_content)
        current_line_number = #content
      end
    end
  end
end

return M
