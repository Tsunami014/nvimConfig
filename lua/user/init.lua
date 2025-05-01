require "user.lualine-theme"

-- vim.api.nvim_create_autocmd({"BufRead", "BufNewFile", "BufEnter"}, {
--   pattern = "*",
--   callback = function()
--     if vim.bo.filetype ~= "markdown" then
--       vim.opt_local.wrap = false
--     else
--       vim.opt_local.wrap = true
--     end
--   end
-- })

-- Some language server options
require('lspconfig').pyright.setup{
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "off",
        diagnosticSeverityOverrides = {
          reportArgumentType = "none",
          reportTypeCommentUsage = "information",
          reportWildcardImportFromLibrary = "none",
        }
      }
    }
  }
}
require('lspconfig').ruff.setup{
  settings = {
    ruff_lsp = {
      ignore = {"F405", "F841"},
    }
  }
}

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

-- Project stuff
local proj = require("project")
Map("n", "<Leader>P", "", "󰉓 Projects")
Map("n", "<Leader>Ps", proj.save_project, "Save project")
Map("n", "<Leader>Pl", proj.findProjects, "Load project")

Map("n", "<Leader>u.", proj.loadUI, "Initialise the UI")

-- Profile stuff
Map("n", "<leader>|", "", " Profiles")
Map("n", "<leader>|c", function()
  vim.notify('The currently active profile is: "' .. require("profile").current .. '"')
end, "Show Current Profile")
Map("n", "<leader>|s", "<cmd>lua require('profile').choose_profile()<CR>", "Switch Profile")

-- Clipboard stuff
vim.schedule(function() vim.opt.clipboard = "" end) -- Use Vim's default clipboard
Map({'n', 'v', 'x'}, '_', '"_', 'Black hole')
Map({'n', 'v', 'x'}, ';', '"+', 'System clipboard')
Map({'n', 'v', 'x'}, "'", '""', 'Vim clipboard')
-- "_ black hole, "+ or "* system cbd, "" nvim default cbd

-- Misc stuff
Map('n', '<Leader>c', '', ' Symbols')
Map('n', '<Leader>s', '', ' Todos & Noice')
Map('n', '<Leader>f', '', '󰍉 Find')
Map('n', '<Leader>gh', '', ' Hunks')

Map({'n', 'v', 'x'}, '<c-a>', '<esc>ggVG', 'Select all')

