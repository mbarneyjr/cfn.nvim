local M = {}

local notify = require("cfn.lib.notify")
local ui = require("cfn.lib.ui")
local treesitter = require("cfn.lib.treesitter")
local refactor_util = require("cfn.core.refactor.util")
local state = require("cfn.lib.state")
local util = require("cfn.lib.util")
local credentials = require("cfn.lib.credentials")

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

    if #new_name > 255 then
      notify.error("logical ids must be at most 255 characters")
      return
    end

    if tonumber(new_name) ~= nil and not vim.bo[bufnr].filetype:find("json") then
      notify.error("logical ids in a YAML template cannot be purely numeric")
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

    ---@type CfnLspResourceToImport?
    local marked_for_import = nil

    local _, template_registration, template_path = util.state.get_template_registration()
    if template_registration ~= nil and template_path ~= nil then
      credentials.set(template_registration.profile, template_registration.region)

      local import_registration = state.resources_to_import:get(template_path)
      for _, resource_to_import in ipairs(import_registration and import_registration.resources or {}) do
        if resource_to_import.LogicalResourceId == old_name then
          marked_for_import = resource_to_import
          break
        end
      end

      if marked_for_import ~= nil then
        marked_for_import.LogicalResourceId = new_name
        state.resources_to_import:set(template_path, import_registration)
      else
        local refactor_operation = state.refactor_operation:get("main") or { mappings = {}, stack_definitions = {} }
        local exists_err, exists =
          util.cfn.resource_exists_in_stack(template_registration.stack_name, old_name, refactor_operation)
        if exists_err ~= nil then
          notify.warn("not registering stack refactor: " .. exists_err)
        elseif exists then
          local err = refactor_util.reconcile_move({
            source = {
              stack_name = template_registration.stack_name,
              logical_id = old_name,
            },
            destination = {
              stack_name = template_registration.stack_name,
              logical_id = new_name,
            },
          }, refactor_operation)
          if err ~= nil then
            notify.warn("not registering stack refactor: " .. err)
          else
            state.refactor_operation:set("main", refactor_operation)
          end
        end
      end
    end

    for _, range in ipairs(ranges) do
      replace_range(bufnr, range, new_name)
    end

    if marked_for_import ~= nil then
      ui.template_highlight.clear(bufnr, old_name)
      local highlight_err = ui.template_highlight.highlight(
        bufnr,
        new_name,
        "DiagnosticVirtualTextInfo",
        "Import: " .. vim.fn.json_encode(marked_for_import.ResourceIdentifier),
        "Title"
      )
      if highlight_err ~= nil then
        notify.warn("cannot update import marker: " .. highlight_err)
      end
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
