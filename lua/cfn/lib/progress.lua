local M = {}

---@class ProgressOpts
---@field id? string|integer
---@field title string
---@field percent? integer
---@field status?
---| "running" # Process is ongoing
---| "success" # Process completed successfully
---| "failed" # Process failed
---| "cancel" # Process should be cancelled; the progress owner must handle the |Progress| event to perform the cancellation

---@param message string
---@param history boolean
---@param opts ProgressOpts
M.send = function(message, history, opts)
  if opts.status == "running" and opts.percent == nil then
    vim.api.nvim_ui_send("\027]9;4;3\027\\")
    local progress_id = vim.api.nvim_echo(
      {
        { opts.title, "Title" },
        { ": " .. message },
      },
      history,
      {
        kind = "echo",
      }
    )
    opts.id = progress_id
  else
    local progress_id = vim.api.nvim_echo({ { message } }, history, {
      kind = "progress",
      source = "cfn.nvim",
      title = opts.title,
      status = opts.status,
      percent = opts.percent,
    })
    opts.id = progress_id
  end

  return opts
end

M.clear = function()
  vim.api.nvim_ui_send("\027]9;4;0;0\027\\")
end

return M
