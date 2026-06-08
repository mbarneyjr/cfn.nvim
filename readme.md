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

See [config.lua](./lua/cfn/config.lua) for all available configuration options.

## Keymaps

This plugin comes with a status pane to render relevant information about the CloudFormation templates in your project.
You can register a keymap to open the status pane like so:

```lua
vim.keymap.set("n", "<leader>cs", require("cfn").fn.toggle_status_window, {
  desc = "cfn.nvim: rename resource",
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
