local M = {}

local ui = require("cfn.lib.ui")

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
