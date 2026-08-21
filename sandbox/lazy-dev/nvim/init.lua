local sandbox = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local root = vim.fn.fnamemodify(sandbox, ":h")

dofile(sandbox .. "/lazy.lua")({
  "mbarneyjr/cfn.nvim",
  url = "file://" .. root,
  build = "go build -o bin/cfn-nvim .",
})

dofile(sandbox .. "/common.lua")
