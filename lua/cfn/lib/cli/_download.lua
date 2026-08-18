local M = {}

local notify = require("cfn.lib.notify")

local repo = "mbarneyjr/cfn.nvim"
local plugin_file = debug.getinfo(1, "S").source:sub(2)

---@param cmd string[]
---@return vim.SystemCompleted
local function system(cmd)
  local co = assert(coroutine.running(), "cfn.lib.cli._download functions must be called from a coroutine")
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      local ok, co_err = coroutine.resume(co, result)
      if not ok then
        notify.error(co_err)
      end
    end)
  end)
  return coroutine.yield()
end

---@return string? target
local function target()
  local uname = vim.uv.os_uname()
  local os_name = ({ Darwin = "darwin", Linux = "linux" })[uname.sysname]
  local arch = ({ arm64 = "arm64", aarch64 = "arm64", x86_64 = "amd64" })[uname.machine]
  if os_name == nil or arch == nil then
    return nil
  end
  return os_name .. "-" .. arch
end

---@return string? err
---@return string? tag
local function tag()
  local root = vim.fs.root(plugin_file, ".git")
  if root == nil then
    return "cannot detect the plugin version, the plugin directory is not a git repository", nil
  end
  local result = system({ "git", "-C", root, "describe", "--tags", "--exact-match" })
  if result.code ~= 0 then
    return "the plugin is not checked out at a release tag", nil
  end
  return nil, vim.trim(result.stdout)
end

---@param url string
---@param out string
---@return string? err
local function fetch(url, out)
  local result = system({
    "curl",
    "--fail",
    "--location",
    "--silent",
    "--show-error",
    "--create-dirs",
    "--output",
    out,
    url,
  })
  if result.code ~= 0 then
    return "failed to download " .. url .. ": " .. vim.trim(result.stderr)
  end
  return nil
end

---@param path string
---@return string? err
---@return string? checksum nil when no checksum tool is available
local function checksum(path)
  local cmd
  if vim.fn.executable("sha256sum") == 1 then
    cmd = { "sha256sum", path }
  elseif vim.fn.executable("shasum") == 1 then
    cmd = { "shasum", "-a", "256", path }
  else
    return nil, nil
  end
  local result = system(cmd)
  if result.code ~= 0 then
    return "failed to checksum " .. path .. ": " .. vim.trim(result.stderr), nil
  end
  return nil, vim.split(vim.trim(result.stdout), "%s+")[1]
end

---@param path string
---@param url string
---@return string? err
local function verify(path, url)
  local err, actual = checksum(path)
  if err ~= nil then
    return err
  end
  if actual == nil then
    return nil
  end

  local expected_path = path .. ".sha256"
  local fetch_err = fetch(url .. ".sha256", expected_path)
  if fetch_err ~= nil then
    return fetch_err
  end
  local expected = vim.split(vim.trim(vim.fn.readfile(expected_path)[1] or ""), "%s+")[1]
  vim.uv.fs_unlink(expected_path)

  if actual ~= expected then
    return "checksum mismatch, expected " .. expected .. " but got " .. actual
  end
  return nil
end

---@return string? err
---@return string? path
function M.ensure()
  local platform = target()
  if platform == nil then
    local uname = vim.uv.os_uname()
    return "no prebuilt cfn-nvim binary for " .. uname.sysname .. "/" .. uname.machine, nil
  end
  if vim.fn.executable("curl") == 0 then
    return "curl is required to download the cfn-nvim binary", nil
  end

  local err, version = tag()
  if err ~= nil then
    return err, nil
  end

  local path = vim.fs.joinpath(vim.fn.stdpath("data"), "cfn.nvim", "bin", version, "cfn-nvim")
  if vim.uv.fs_stat(path) ~= nil then
    return nil, path
  end

  local url = ("https://github.com/%s/releases/download/%s/cfn-nvim-%s"):format(repo, version, platform)
  local tmp = path .. ".tmp"
  notify.info("downloading cfn-nvim " .. version)

  local fetch_err = fetch(url, tmp)
  if fetch_err ~= nil then
    return fetch_err, nil
  end
  local verify_err = verify(tmp, url)
  if verify_err ~= nil then
    vim.uv.fs_unlink(tmp)
    return verify_err, nil
  end

  vim.uv.fs_chmod(tmp, 493)
  local renamed, rename_err = vim.uv.fs_rename(tmp, path)
  if not renamed then
    return "failed to install cfn-nvim: " .. tostring(rename_err), nil
  end

  notify.info("downloaded cfn-nvim " .. version)
  return nil, path
end

return M
