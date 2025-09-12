-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4    -- Sets the width of a tab character
vim.opt.shiftwidth = 4 -- Sets the width used for auto-indentation and shifting commands
vim.opt.expandtab = true -- Converts tabs to spaces

require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" },
  },
  install = { colorscheme = { "tokyonight" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})
