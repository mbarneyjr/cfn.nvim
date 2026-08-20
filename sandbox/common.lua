vim.g.mapleader = " "
vim.o.number = true
vim.o.signcolumn = "yes"
vim.o.swapfile = false

vim.pack.add({
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/folke/snacks.nvim" },
}, { confirm = false })
vim.cmd.colorscheme("tokyonight")

require("snacks").setup({
  picker = { enable = true },
  input = { enable = true },
})

vim.treesitter.language.register("yaml", "yaml.cloudformation")
vim.treesitter.language.register("json", "json.cloudformation")

local function is_template(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 64, false)) do
    if line:find("AWSTemplateFormatVersion", 1, true) then
      return true
    end
  end
  return false
end

vim.filetype.add({
  pattern = {
    [".*%.ya?ml"] = function(_, bufnr)
      return is_template(bufnr) and "yaml.cloudformation" or nil
    end,
    [".*%.json"] = function(_, bufnr)
      return is_template(bufnr) and "json.cloudformation" or nil
    end,
  },
})

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

vim.lsp.config("cfn_lsp", {
  cmd = { "cfn-lsp-server", "--stdio" },
  filetypes = { "yaml.cloudformation", "json.cloudformation" },
  root_markers = { ".git" },
  init_options = {
    aws = {
      encryption = { key = require("cfn").encryption_key() },
    },
  },
  settings = {
    aws = {
      cloudformation = {
        diagnostics = {
          cfnLint = { path = "cfn-lint" },
        },
      },
    },
  },
})
vim.lsp.enable("cfn_lsp")

local cfn = require("cfn")
cfn.setup()

vim.keymap.set("n", "<leader>cs", cfn.fn.toggle_status_window, { desc = "cfn.nvim: toggle status window" })
vim.keymap.set("n", "<leader>cr", cfn.fn.rename_resource, { desc = "cfn.nvim: rename resource" })
