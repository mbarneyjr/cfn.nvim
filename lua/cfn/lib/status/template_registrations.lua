local M = {}

local state = require("cfn.lib.state")
local config = require("cfn.lib.config")

---@type { [string]: boolean }
local open_templates = {}

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

    -- if the current template is expanded
    if open_templates[path] then
      current_line_number = #content
      line_content = "  "

      local content2 = "  more information to come in a future update"
      table.insert(highlights, {
        line = current_line_number,
        col_start = #line_content,
        col_end = #line_content + #content2,
        hl_group = "Comment",
      })
      line_content = line_content .. content2
      table.insert(content, line_content)
      interactivity_map[current_line_number] = {
        open = function()
          open_templates[path] = true
        end,
        close = function()
          open_templates[path] = false
        end,
      }
    end
  end
end

return M
