local sandbox = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

vim.pack.add({
  { src = "https://github.com/mbarneyjr/cfn.nvim", version = vim.version.range("*") },
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/folke/snacks.nvim" },
}, { confirm = false })

dofile(sandbox .. "/common.lua")
