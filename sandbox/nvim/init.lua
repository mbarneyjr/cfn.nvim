-- Installs the plugin from this repository and builds the binary from source.

local sandbox = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local root = vim.fn.fnamemodify(sandbox, ":h")

vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name ~= "cfn.nvim" or ev.data.kind == "delete" then
      return
    end
    local out = vim.system({ "go", "build", "-o", "bin/cfn-nvim", "." }, { cwd = ev.data.path, text = true }):wait()
    assert(out.code == 0, "go build failed: " .. out.stderr)
  end,
})

vim.pack.add({
  { src = "file://" .. root, name = "cfn.nvim" },
}, { confirm = false })

dofile(sandbox .. "/common.lua")
