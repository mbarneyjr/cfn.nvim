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
---@return string? err
---@return CfnCredentials? credentials
function M.credentials(profile)
  return rpc.run({ "profile", "credentials", "--profile", profile, "--key", state.encryption_key() })
end

return M
