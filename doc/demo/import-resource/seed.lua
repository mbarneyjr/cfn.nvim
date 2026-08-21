local demo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local templates = demo_root .. "/templates"

local state = require("cfn.lib.state")

state.template_registration:set(templates .. "/dev/feature-flags.yml", {
  profile = "dev",
  region = "us-west-2",
  stack_name = "appfeatureflags",
})
