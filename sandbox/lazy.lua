local lazypath = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "lazy.nvim")

return function(spec)
  if not vim.uv.fs_stat(lazypath) then
    local out = vim
      .system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
      }, { text = true })
      :wait()
    assert(out.code == 0, "lazy.nvim clone failed: " .. out.stderr)
  end
  vim.opt.rtp:prepend(lazypath)

  require("lazy").setup({
    spec = {
      spec,
      { "folke/tokyonight.nvim" },
      { "folke/snacks.nvim" },
    },
    install = { colorscheme = { "tokyonight" } },
    change_detection = { enabled = false },
  })
end
