local demo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local templates = demo_root .. "/templates"

local state = require("cfn.lib.state")

local database_path = templates .. "/dev/database.yml"
local database_v2_path = templates .. "/dev/database-v2.yml"

state.template_registration:set(database_path, {
  profile = "dev",
  region = "us-west-2",
  stack_name = "app-database",
})
state.template_registration:set(database_v2_path, {
  profile = "dev",
  region = "us-west-2",
  stack_name = "app-database-v2",
})

state.refactor_operation:set("main", {
  mappings = {},
  stack_definitions = {
    { stack_name = "app-database", template_path = database_path },
    { stack_name = "app-database-v2", template_path = database_v2_path },
  },
})
