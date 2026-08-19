-- Installs the newest released tag from GitHub, with no build hook, so the
-- plugin falls through to downloading the prebuilt cfn-nvim binary.

local sandbox = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

vim.pack.add({
  { src = "https://github.com/mbarneyjr/cfn.nvim", version = vim.version.range("*") },
}, { confirm = false })

dofile(sandbox .. "/common.lua")
