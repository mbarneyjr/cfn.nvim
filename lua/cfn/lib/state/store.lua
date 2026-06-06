local M = {}

function M.get_store_dir()
  local cwd = assert(vim.uv.cwd())
  local real = vim.uv.fs_realpath(cwd)
  if type(real) == "string" then
    cwd = real
  end
  local hash = vim.fn.sha256(cwd)
  local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "cfn.nvim", "projects", hash)
  vim.fn.mkdir(dir, "p")
  return dir
end

return M
