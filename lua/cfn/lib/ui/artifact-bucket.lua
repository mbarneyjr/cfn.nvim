local M = {}

local ui_input = require("cfn.lib.ui.input")
local ui_select = require("cfn.lib.ui.select")
local lsp = require("cfn.lib.lsp")

---@return string? error
---@return string? artifact_bucket_name
function M.prompt_for_artifact_bucket()
  local bucket_err, bucket_response = lsp.resources.list_resources_all({
    { resourceType = "AWS::S3::Bucket" },
  })
  local bucket_names = {}
  if bucket_err ~= nil or bucket_response == nil or #bucket_response < 1 then
    return "could not list S3 buckets: " .. (bucket_err or "no result"), nil
  else
    bucket_names = bucket_response[1].resourceIdentifiers
  end
  ---@type string?
  local artifact_bucket_name
  if #bucket_names > 0 then
    artifact_bucket_name = ui_select.select(bucket_names, {
      prompt = "Template requires artifacts. Enter an S3 bucket name to upload artifacts to.",
    })
  else
    artifact_bucket_name = ui_input.input({
      prompt = "Template requires artifacts. Enter an S3 bucket name to upload artifacts to.",
      validate = function(input)
        if not input or input == "" then
          return "S3 bucket name cannot be empty"
        end
        return nil
      end,
    })
  end
  if artifact_bucket_name == nil then
    return "no S3 bucket chosen for artifacts", nil
  end
  return nil, artifact_bucket_name
end

return M
