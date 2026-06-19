vim.g.mapleader = " "
vim.g.maplocalleader = " \\" -- Hope nothing uses this

vim.opt.number = true -- Number lines
vim.opt.relativenumber = true -- Number lines relative to the current
vim.opt.swapfile = false -- Generate a swap file when half-editing something
vim.opt.expandtab = true -- Converts tabs to spaces
vim.opt.exrc = true   -- Allow loading .nvim.lua files in the project root
vim.opt.secure = true -- Disable unsafe commands in those local files
vim.opt.inccommand = "split" -- Show a replace preview in a split window
vim.opt.ignorecase = true -- search case insensitive
vim.opt.smartcase = true -- search matters if capital letter

-- These get overridden by later indent guessing anyway
vim.opt.tabstop = 4    -- Sets the width of a tab character
vim.opt.shiftwidth = 4 -- Sets the width used for auto-indentation and shifting commands
