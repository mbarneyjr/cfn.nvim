local M = {}

M.select = require("cfn.lib.ui.select").select
M.input = require("cfn.lib.ui.input").input
M.parameter_form = require("cfn.lib.ui.parameter-form")
M.tag_form = require("cfn.lib.ui.tag-form")
M.artifact_bucket = require("cfn.lib.ui.artifact-bucket")
M.template_highlight = require("cfn.lib.ui.template-highlight")

return M
