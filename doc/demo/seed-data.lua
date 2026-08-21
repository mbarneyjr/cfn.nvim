local demo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local templates = demo_root .. "/templates"

local state = require("cfn.lib.state")

for path in pairs(state.template_registration:list()) do
  state.template_registration:remove(path)
end

local storage_path = templates .. "/prod/storage.yml"
state.template_registration:set(storage_path, {
  profile = "prod",
  region = "us-west-2",
  stack_name = "app-storage",
  artifact_bucket_name = "cicd-artifacts",
})
state.active_changeset:set(vim.fn.fnamemodify(storage_path, ":."), {
  stackName = "app-storage",
  changeSetName = "cfn.nvim-2026-08-19T21:30:00Z",
})
state.resources_to_import:set(storage_path, {
  resources = {
    {
      LogicalResourceId = "Bucket",
      ResourceIdentifier = {
        BucketName = "app-storage-assets",
      },
      ResourceType = "AWS::S3::Bucket",
    },
  },
})

state.active_refactor:set("main", {
  profile = "dev",
  region = "us-west-2",
  stack_refactor_id = "5d608fe5-6e58-44c7-a64c-80a11a50bfca",
})
state.refactor_operation:set("main", {
  stack_definitions = {
    {
      stack_name = "app-database",
      template_path = vim.fn.fnamemodify(templates .. "/dev/database.yml", ":."),
    },
    {
      stack_name = "app-database-v2",
      template_path = vim.fn.fnamemodify(templates .. "/dev/database-v2.yml", ":."),
    },
  },
  mappings = {
    {
      source = {
        stack_name = "app-database",
        logical_id = "Bar",
      },
      destination = {
        stack_name = "app-database-v2",
        logical_id = "Bar",
      },
    },
  },
})
