require "user.lualine-theme"
require "user.project"

-- Enable wrapping for Markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt.wrap = true
  end,
})

-- Disable auto formatting
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.documentFormattingProvider then
      client.server_capabilities.documentFormattingProvider = false
    end
  end,
})

-- Some keybinds
function Map(mode, lhs, rhs, desc)
  if rhs == false then
    vim.api.nvim_del_keymap(mode, lhs)
    return
  end
  desc = desc or ""
  local opts = { desc = desc }
  local options = { noremap = true, silent = true }
  if opts then
      options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

_G.initUI = function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>S.", true, false, true), "m", false)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>th", true, false, true), "m", false)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "m", false)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>e", true, false, true), "m", false)
end
Map("n", "<leader>u.", ":lua initUI()<CR>", "Initialise the UI")

-- Buffer stuff
Map('n', '<Leader>bn', '<cmd>tabnew<cr>', 'New tab')
Map('n', '<Leader>bD', function()
  require("astroui.status").heirline.buffer_picker(function(bufnr)
    require("astrocore.buffer").close(bufnr)
  end)
end, 'Pick to close')
Map('n', '<Leader>b]', function()
  require("astrocore.buffer").nav(vim.v.count1)
end, 'Next buffer')
Map('n', '<Leader>b[', function()
  require("astrocore.buffer").nav(-vim.v.count1)
end, 'Previous buffer')
Map('n', '<Leader>bp', false)

-- Misc stuff
Map('n', '<Leader>c', '', ' Symbols')
Map('n', '<Leader>s', '', ' Todos & Noice')
Map('n', '<Leader>f', '', '󰍉 Find')
Map('n', '<Leader>gh', '', ' Hunks')
Map('n', '<Leader>sn', '', ' Noice')

Map('v', '<Leader>d', '"_d', 'Delete selection')

