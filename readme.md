# cfn.nvim

Neovim plugin for working with AWS CloudFormation templates.

## Features

- Status Window: A live view into registered templates/stacks, imports, changesets, and refactors: `:Cfn status`
- Template Registration: Link a template to a profile/stack/region: `:Cfn template register`
- Resource Renaming: Rename a logical ID and update all references in the buffer: `:Cfn rename`
- Resource Import: Import a physical resource into the stack: `:Cfn import`
- ChangeSet Creation: Create a changeset with parameter/tag forms: `:Cfn changeset create`
- ChangeSet Execution: Execute a changeset and stream live resource deployment status: `:Cfn changeset execute`
- ChangeSet Opening: Open the changeset in the AWS Console: `:Cfn changeset open`
- Template Highlighting: Show imported resources, change set actions, and live status during stack operations.
- StackRefactor Moving: Move a resource from one logical ID in one stack to another: `:Cfn refactor move`
- StackRefactor Refresh: Infer moves by comparing the templates against the deployed stacks: `:Cfn refactor refresh`
- StackRefactor Creation: Create a new StackRefactor based on resource moves/renames: `:Cfn refactor create`
- StackRefactor Execution: Execute a StackRefactor and stream live resource deployment status: `:Cfn refactor execute`
- Parameter/Tag Hooks: Pre-populate parameter and tag forms with values returned from a lua function.

## Requirements

- Neovim 0.12+
- The CloudFormation language server
  - https://github.com/aws-cloudformation/cloudformation-languageserver
  - follow the instructions in that repo, you should have a `"cfn_lsp"` server configured

## Installation

The plugin needs the `cfn-nvim` helper binary.
It finds the binary in this order:

1. `bin.path` from `setup()`
1. `bin/cfn-nvim` inside the plugin directory
1. `cfn-nvim` on your `PATH`
1. a copy downloaded from the GitHub release that matches the checked out tag

A tagged install needs no extra setup.
The plugin reads its version with `git describe --tags --exact-match` and downloads that version of the executable.

With vim.pack:

```lua
vim.pack.add({
  { src = "https://github.com/mbarneyjr/cfn.nvim", version = vim.version.range("*") },
})
```

With lazy.nvim:

```lua
{ "mbarneyjr/cfn.nvim", version = "*" }
```

### Install from main

The plugin cannot pick a binary version when it is not checked out at a release tag.
You must build the binary instead with `go`.
Build it to `bin/cfn-nvim` inside the plugin directory, where the plugin looks for it.
No `setup()` change is needed.

With `vim.pack`, register this autocmd before `vim.pack.add()`:

```lua
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "cfn.nvim" and ev.data.kind ~= "delete" then
      vim.system({ "go", "build", "-o", "bin/cfn-nvim", "." }, { cwd = ev.data.path })
    end
  end,
})
vim.pack.add({
  { src = "https://github.com/mbarneyjr/cfn.nvim", version = "main" },
})
```

With lazy.nvim:

```lua
{ "mbarneyjr/cfn.nvim", branch = "main", build = "go build -o bin/cfn-nvim ." }
```

### Nix

This flake outputs two packages: `vim-plugin` is the plugin, `cfn-nvim` is the helper binary.

```nix
{
  inputs.cfn-nvim.url = "github:mbarneyjr/cfn.nvim";
}
```

```nix
let
  cfn = inputs.cfn-nvim.packages.${pkgs.system};
in
{
  programs.neovim = {
    plugins = [ cfn.vim-plugin ];
    extraPackages = [ cfn.cfn-nvim ];
  };
}
```

`extraPackages` puts `cfn-nvim` on Neovim's `PATH`, so the plugin uses it and never downloads.

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

## Parameter / Tag Form Hooks

You can define a lua function that gets called as a hook to retrieve parameter or tag values at ChangeSet creation time.

```lua
---@alias CfnHook fun(ctx: cfn.HookContext): table<string, string>? values keyed by name, used to pre-populate the form

require("cfn").setup({
  hooks = {
    ---@type CfnHook
    tags = function(ctx)
      return {
        key = "value",
        region = ctx.region,
        stack_name = ctx.stack_name,
        profile = ctx.profile,
        template_path = ctx.template_path,
      }
    end,
    ---@type CfnHook
    parameters = function(ctx)
      ...
      return { key = "value" }
    end,
  },
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
