local sandbox = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local root = vim.fn.fnamemodify(sandbox, ":h")

vim.opt.rtp:prepend(root)
vim.cmd.helptags(vim.fs.joinpath(root, "doc"))

local bin = vim.fs.joinpath(sandbox, "live", "bin")
vim.fn.mkdir(bin, "p")
local out = vim
  .system({ "go", "build", "-o", vim.fs.joinpath(bin, "cfn-nvim"), "." }, { cwd = root, text = true })
  :wait()
assert(out.code == 0, "go build failed: " .. out.stderr)
vim.env.PATH = bin .. ":" .. vim.env.PATH

vim.pack.add({
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/folke/snacks.nvim" },
}, { confirm = false })

dofile(sandbox .. "/common.lua")
