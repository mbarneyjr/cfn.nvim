local M = {}

M.cfn = require("cfn.lib.lsp.cfn")
M.credentials = require("cfn.lib.lsp.credentials")
M.validation = require("cfn.lib.lsp.validation")
M.stack = require("cfn.lib.lsp.stack")
M.resources = require("cfn.lib.lsp.resources")
M.template = require("cfn.lib.lsp.template")
M.import = require("cfn.lib.lsp.import")

return M
