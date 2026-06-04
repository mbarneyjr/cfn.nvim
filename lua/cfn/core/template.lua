local M = {}

---@param profile string | nil
---@param stack_name string | nil
function M.register(profile, stack_name)
  -- register the current file as a template
  -- prompt for stack to register to
  -- prompt for profile to register to
  vim.print("registering template: " .. vim.inspect(profile) .. "/" .. vim.inspect(stack_name))
end

function M.unregister()
  -- unregister a template
  vim.print("unregistering template")
end

return M
