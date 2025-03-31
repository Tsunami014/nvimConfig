require "user.lualine-theme"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.documentFormattingProvider then
      client.server_capabilities.documentFormattingProvider = false
    end
  end,
})

function Map(mode, lhs, rhs, desc)
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
Map("n", "<leader>i", ":lua initUI()<CR>", "Initialise the UI")

_G.loadProject = function(ncwd)
  vim.fn.chdir(ncwd)
  _G.initUI()
end

vim.keymap.set("v", "<leader>D", '"_d', { desc = "Delete selection", remap = false, noremap = true, silent = true })

