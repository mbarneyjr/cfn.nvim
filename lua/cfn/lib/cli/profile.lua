local M = {}

local rpc = require("cfn.lib.cli._rpc")
local state = require("cfn.lib.state")

---@class ProfileListResult
---@field profiles string[]

---@return string? err
---@return ProfileListResult? profiles
function M.list()
  return rpc.run({ "profile", "list" })
end

---@class CfnCredentials
---@field jwe string
---@field region string
---@field accountId string
---@field expiry? string
---@field expiryEpoch? integer

---@param profile string
---@param region? string overrides the profile's configured region
---@return string? err
---@return CfnCredentials? credentials
function M.credentials(profile, region)
  local args = { "profile", "credentials", "--profile", profile, "--key", state.encryption_key() }
  if region ~= nil and region ~= "" then
    vim.list_extend(args, { "--region", region })
  end
  return rpc.run(args)
end

return M
