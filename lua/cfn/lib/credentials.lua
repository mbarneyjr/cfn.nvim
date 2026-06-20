local M = {}

local cli = require("cfn.lib.cli")
local lsp = require("cfn.lib.lsp")
local progress = require("cfn.lib.progress")
local state = require("cfn.lib.state")

local SAFETY_BUFFER_SEC = 300

---@type table<string, uv.uv_timer_t>
local refresh_timers = {}
local current_profile = nil

local function stop_timer(profile)
  local t = refresh_timers[profile]
  if t then
    t:stop()
    t:close()
    refresh_timers[profile] = nil
  end
end

local function schedule_refresh(profile, expiryEpoch)
  stop_timer(profile)
  local ms = math.max(0, (expiryEpoch - os.time() - SAFETY_BUFFER_SEC) * 1000)
  refresh_timers[profile] = vim.defer_fn(function()
    coroutine.wrap(function()
      local err, creds = cli.profile.credentials(profile)
      if err or creds == nil then
        return
      end
      state.credentials:set(profile, creds)
      if current_profile == profile then
        lsp.credentials.iam.update(creds.jwe)
      end
      if creds.expiryEpoch and creds.expiryEpoch > 0 then
        schedule_refresh(profile, creds.expiryEpoch)
      end
    end)()
  end, ms)
end

---@param profile? string
function M.cancel(profile)
  if profile then
    stop_timer(profile)
    state.credentials:remove(profile)
    if current_profile == profile then
      current_profile = nil
    end
  else
    for p in pairs(refresh_timers) do
      stop_timer(p)
    end
    current_profile = nil
  end
end

---@param profile string
---@param refresh? boolean
---@return string? err
---@return CfnCredentials? credentials
function M.set(profile, refresh)
  assert(coroutine.running(), "cfn.lib.credentials.set must be called from a coroutine")

  local cached = state.credentials:get(profile)

  if refresh or cached == nil or (cached.expiryEpoch - os.time() > SAFETY_BUFFER_SEC) then
    local p = progress.send("loading credentials for profile " .. profile, true, {
      title = profile,
      status = "running",
    })

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
    state.credentials:set(profile, creds)
    current_profile = profile

    if creds.expiryEpoch and creds.expiryEpoch > 0 then
      schedule_refresh(profile, creds.expiryEpoch)
    end
  elseif profile ~= current_profile then
    local push_err = lsp.credentials.iam.update(cached.jwe)
    if push_err then
      return push_err, nil
    end
    current_profile = profile
  end

  progress.send("resolved credentials for profile " .. profile, true, {
    title = profile,
    status = "success",
  })
  return nil, state.credentials:get(profile)
end

---@return string?
function M.current_profile()
  return current_profile
end

return M
