local M = {}

local state = require("cfn.lib.state")
local notify = require("cfn.lib.notify")
local buffer = require("cfn.lib.buffer")
local ui = require("cfn.lib.ui")
local treesitter = require("cfn.lib.treesitter")

function M.unimport()
  coroutine.wrap(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local template_path_err, template_path = buffer.get_current_buffer_template_path(bufnr)
    if template_path_err ~= nil or not template_path then
      return notify.error("cannot unimport resource in template: " .. (template_path_err or "no template path"))
    end

    local resources_to_import_registration = state.resources_to_import:get(template_path)
    local resource = treesitter.resource_at_cursor(bufnr)
    if resource == nil then
      return notify.error("no resource found under cursor")
    end
    if resources_to_import_registration == nil then
      return notify.warn("resource " .. resource.logical_id.name .. " is not marked for import")
    end
    local found = false
    for i, resource_to_import in pairs(resources_to_import_registration.resources or {}) do
      if resource_to_import.LogicalResourceId == resource.logical_id.name then
        table.remove(resources_to_import_registration.resources, i)
        found = true
        break
      end
    end
    if not found then
      return notify.warn("resource " .. resource.logical_id.name .. " is not marked for import")
    end

    ui.template_highlight.clear(bufnr)
    for _, resource_to_highlight in ipairs(resources_to_import_registration.resources or {}) do
      local highlight_err = ui.template_highlight.highlight(
        bufnr,
        resource_to_highlight.LogicalResourceId,
        "DiagnosticVirtualTextInfo",
        "Import: " .. vim.fn.json_encode(resource_to_highlight.ResourceIdentifier),
        "Title"
      )
      if highlight_err ~= nil and not highlight_err:find("resource not found for logical id") then
        return notify.error("cannot highlight resource: " .. highlight_err)
      end
    end
    state.resources_to_import:set(template_path, resources_to_import_registration)
    notify.info("unimported " .. resource.logical_id.name)
  end)()
end

return M
