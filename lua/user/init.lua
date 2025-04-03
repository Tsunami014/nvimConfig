require "user.lualine-theme"

vim.o.shell = '/bin/bash -l'
vim.env.PATH = "/home/tsunami014/.nvm/versions/node/v20.18.0/bin/:" .. vim.env.PATH

-- Some language server options
require('lspconfig').pyright.setup{
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "off",
        diagnosticSeverityOverrides = {
          reportArgumentType = "warning",
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
      configuration = {
        ignore = {"F405", "F841"},
      }
    }
  }
}

-- Enable wrapping for Markdown files
local wrap_states = {}

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local filetype = vim.bo[buf].filetype

    if filetype == "markdown" then
      -- Save wrap state only if not already saved
      if wrap_states[buf] == nil then
        wrap_states[buf] = vim.opt.wrap:get()
      end
      vim.opt.wrap = true
    elseif wrap_states[buf] ~= nil then
      -- Restore wrap state when entering a non-markdown buffer
      vim.opt.wrap = wrap_states[buf]
      wrap_states[buf] = nil -- Cleanup
    end
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    local buf = args.buf
    wrap_states[buf] = nil
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

-- Misc stuff
Map('n', '<Leader>c', '', ' Symbols')
Map('n', '<Leader>s', '', ' Todos & Noice')
Map('n', '<Leader>f', '', '󰍉 Find')
Map('n', '<Leader>gh', '', ' Hunks')
Map('n', '<Leader>sn', '', ' Noice')

Map("n", "<leader>|", "", " Profiles")
Map("n", "<leader>|c", function()
  vim.notify('The currently active profile is: "' .. require("profile").current .. '"')
end, "Show Current Profile")
Map("n", "<leader>|s", "<cmd>lua require('profile').choose_profile()<CR>", "Switch Profile")

Map('v', '<Leader>d', '"_d', 'Delete selection')

