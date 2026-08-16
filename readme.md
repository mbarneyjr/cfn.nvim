# cfn.nvim

Neovim plugin for working with AWS CloudFormation templates.

## Requirements

- Neovim 0.12+
- The CloudFormation language server
  - https://github.com/aws-cloudformation/cloudformation-languageserver
  - follow the instructions in that repo, you should have a `"cfn_lsp"` server configured

## Setup

```lua
require("cfn").setup()
```

See [config.lua](./lua/cfn/lib/config.lua) for all available configuration options.

## Keymaps

This plugin comes with a status pane to render relevant information about the CloudFormation templates in your project.
You can register a keymap to open the status pane like so:

```lua
vim.keymap.set("n", "<leader>cs", require("cfn").fn.toggle_status_window, {
  desc = "cfn.nvim: rename resource",
})
```

The CloudFormation language server doesn't implement `textDocument/rename`.
This means `vim.lsp.buf.rename` won't do anything in a template buffer.
We recommend that you override your rename keymap to call `require("cfn").fn.rename_resource` instead.
This will handle renaming a resource within your template, making sure to update all references to that resource.
The following assumes you have `yaml.cloudformation`/`json.cloudformation` as registered filetypes for CloudFormation.

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "yaml.cloudformation", "json.cloudformation" },
  callback = function(args)
    vim.keymap.set("n", "<leader>cr", require("cfn").fn.rename_resource, {
      buffer = args.buf,
      desc = "cfn.nvim: rename resource",
    })
  end,
})
```

## Development

Source the following lua code.
It's recommended to add it to your `.nvim.lua` (assuming you have `exrc` enabled).

```lua
local here = vim.fn.fnamemodify(debug.getinfo(1, "s").source:sub(2), ":p:h")
vim.opt.runtimepath:prepend(here)

vim.lsp.config("cfn_lsp", {
  init_options = {
    aws = {
      encryption = { key = require("cfn").encryption_key() },
    },
  },
  -- ...other settings as needed
})
vim.lsp.enable("cfn_lsp")
require("cfn").setup({
  bin = {
    path = "./result/bin/cfn-nvim",
  },
})
```
