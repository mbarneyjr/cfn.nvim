local M = {}

local buffer = require("cfn.lib.buffer")
local state = require("cfn.lib.state")
local ui = require("cfn.lib.ui")

---@param bufnr? number
---@return string? error
---@return TemplateRegistration? registration
---@return string? template_path
function M.get_template_registration(bufnr)
  local template_path_err, template_path = buffer.get_current_buffer_template_path(bufnr)
  if template_path_err ~= nil or not template_path then
    return "cannot load profile: " .. (template_path_err or "no template path"), nil, nil
  end

  local registration = state.template_registration:get(template_path)
  if registration == nil then
    return "current template is not registered, please run :Cfn template register", nil, nil
  end

  return nil, registration, template_path
end

function M.clear_highlight(bufnr)
  local clear_err = ui.template_highlight.clear(bufnr)
  if clear_err ~= nil then
    return "cannot clear resource highlights: " .. clear_err
  end
end

---@type { [CfnLspChangeAction]: HighlightGroupBuiltin}
local action_map = {
  Add = "DiagnosticVirtualTextHint",
  Modify = "DiagnosticVirtualTextWarn",
  Remove = "DiagnosticVirtualTextError",
  Import = "DiagnosticVirtualTextInfo",
  Dynamic = "DiagnosticVirtualTextWarn",
  SyncWithActual = "DiagnosticVirtualTextOk",
}
---@param bufnr number
---@param changeSet CfnLspStackValidationDescribeResult | CfnLspDescribeChangeSetResult
---@return string? error
function M.highlight_changeset(bufnr, changeSet)
  local clear_err = ui.template_highlight.clear(bufnr)
  if clear_err ~= nil then
    return "cannot clear resource highlights: " .. clear_err
  end
  for _, change in ipairs(changeSet.changes or {}) do
    if change.resourceChange ~= nil then
      local logical_id = change.resourceChange.logicalResourceId
      local action = change.resourceChange.action
      if logical_id ~= nil and action ~= nil then
        local highlight_err = ui.template_highlight.highlight(
          bufnr,
          logical_id,
          action_map[action] or "Normal",
          "Change Type: " .. action,
          "Title"
        )
        if highlight_err ~= nil and not highlight_err:find("resource not found for logical id") then
          return "cannot highlight resource: " .. highlight_err
        end
      end
    end
  end
end

return M
