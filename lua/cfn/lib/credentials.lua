local M = {}

local cli = require("cfn.lib.cli")
local lsp = require("cfn.lib.lsp")
local progress = require("cfn.lib.progress")
local state = require("cfn.lib.state")

local SAFETY_BUFFER_SEC = 300

---@type table<string, uv.uv_timer_t>
local refresh_timers = {}
local current_key = nil

---@param profile string
---@param region? string
---@return string
local function cache_key(profile, region)
  return profile .. "/" .. (region or "")
end

---@param credentials CfnCredentials
---@return boolean
local function expires_soon(credentials)
  if credentials.expiryEpoch == nil or credentials.expiryEpoch == 0 then
    return false
  end
  return credentials.expiryEpoch - os.time() < SAFETY_BUFFER_SEC
end

local function stop_timer(key)
  local t = refresh_timers[key]
  refresh_timers[key] = nil
  if t and not t:is_closing() then
    t:stop()
    t:close()
  end
end

local function schedule_refresh(key, profile, region, expiryEpoch)
  stop_timer(key)
  local ms = math.max(0, (expiryEpoch - os.time() - SAFETY_BUFFER_SEC) * 1000)
  refresh_timers[key] = vim.defer_fn(function()
    -- vim.defer_fn closes its own timer, so drop the handle before it goes stale
    refresh_timers[key] = nil
    coroutine.wrap(function()
      local err, creds = cli.profile.credentials(profile, region)
      if err or creds == nil then
        return
      end
      state.credentials:set(key, creds)
      if current_key == key then
        lsp.credentials.iam.update(creds.jwe)
      end
      if creds.expiryEpoch and creds.expiryEpoch > 0 then
        schedule_refresh(key, profile, region, creds.expiryEpoch)
      end
    end)()
  end, ms)
end

---@param profile? string
---@param region? string
function M.cancel(profile, region)
  if profile then
    local key = cache_key(profile, region)
    stop_timer(key)
    state.credentials:remove(key)
    if current_key == key then
      current_key = nil
    end
  else
    for key in pairs(refresh_timers) do
      stop_timer(key)
    end
    current_key = nil
  end
end

---@param profile string
---@param region? string overrides the profile's configured region
---@param refresh? boolean
---@return string? err
---@return CfnCredentials? credentials
function M.set(profile, region, refresh)
  assert(coroutine.running(), "cfn.lib.credentials.set must be called from a coroutine")

  local key = cache_key(profile, region)
  local cached = state.credentials:get(key)

  if refresh or cached == nil or expires_soon(cached) then
    local p = progress.send("loading credentials for profile " .. profile, true, {
      title = profile,
      status = "running",
    })

    progress.send("resolving credentials for profile", true, p)
    local err, creds = cli.profile.credentials(profile, region)
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
    state.credentials:set(key, creds)
    current_key = key

    if creds.expiryEpoch and creds.expiryEpoch > 0 then
      schedule_refresh(key, profile, region, creds.expiryEpoch)
    end
  elseif key ~= current_key then
    local push_err = lsp.credentials.iam.update(cached.jwe)
    if push_err then
      return push_err, nil
    end
    current_key = key
  end

  progress.send("resolved credentials for profile " .. profile, true, {
    title = profile,
    status = "success",
  })
  return nil, state.credentials:get(key)
end

return M
