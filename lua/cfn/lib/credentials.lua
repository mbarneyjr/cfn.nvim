local M = {}

local cli = require("cfn.lib.cli")
local lsp = require("cfn.lib.lsp")
local progress = require("cfn.lib.progress")

local SAFETY_BUFFER_SEC = 300

local refresh_timer = nil

function M.cancel()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

---@param profile string
---@return string? err
---@return CfnCredentials? credentials
function M.set(profile)
  assert(coroutine.running(), "cfn.lib.credentials.set must be called from a coroutine")
  local p = progress.send("loading credentials for profile " .. profile, true, {
    title = profile,
    status = "running",
  })

  M.cancel()

  progress.send("resolving credentials for profile", true, p)
  local err, creds = cli.profile.credentials(profile)
  if err or creds == nil then
    p.status = "failed"
    progress.send("failed to resolve credentials for profile", true, p)
    return err or "failed to resolve credentials", nil
  end
  progress.send("credentials resolved for profile, sending to language server", true, p)

  local push_err = lsp.credentials.iam.update(creds.jwe)
  if push_err then
    p.status = "failed"
    progress.send(push_err, true, p)
    return push_err, nil
  end

  p.status = "success"
  progress.send("resolved credentials for profile " .. profile, true, p)

  if creds.expiryEpoch and creds.expiryEpoch > 0 then
    local ms = math.max(0, (creds.expiryEpoch - os.time() - SAFETY_BUFFER_SEC) * 1000)
    refresh_timer = vim.defer_fn(function()
      coroutine.wrap(function()
        M.set(profile)
      end)()
    end, ms)
  end

  return nil, creds
end

return M
