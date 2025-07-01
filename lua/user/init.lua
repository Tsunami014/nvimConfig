require "user.lualine-theme"
require "user.keybinds"

-- Pretend code completion windows are markdown
vim.api.nvim_create_autocmd("FileType", {
    pattern = "codecompanion",
    callback = function()
        vim.opt.filetype = "markdown"
        vim.cmd("doautocmd FileType markdown")
    end
})


local resession = require("resession")
local session_cache = {}
local function get_session_name()
  local cwd = vim.fn.getcwd()
  -- Try to find existing session
  local sessions = resession.list()
  if sessions[cwd] then
    return cwd
  end
  return "Last Session"
end

local function save_session()
  local name = get_session_name()
  resession.save(name, { notify = false })
end
local function debounced_save()
  if session_cache.saving then return end
  session_cache.saving = true
  vim.defer_fn(function()
    save_session()
    session_cache.saving = false
  end, 200)
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufDelete" }, {
  callback = debounced_save,
})


require('nvim-treesitter.configs').setup {
  ensure_installed = { "lua", "markdown", "markdown_inline", "python", "vim", "regex", "bash", "yaml",
                       "css", "html", "javascript", "latex", "norg", "scss", "svelte", "tsx", "typst", "vue" },
}

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      local hover = client.handlers["textDocument/hover"]
      client.handlers["textDocument/hover"] = function(...)
        local result = select(2, ...)
        if not (result and result.contents) then return end
        vim.lsp.util.open_floating_preview(result.contents, "markdown", {
          border = "rounded",
        })
      end

      local signature = client.handlers["textDocument/signatureHelp"]
      client.handlers["textDocument/signatureHelp"] = function(...)
        local result = select(2, ...)
        if not (result and result.signatures) then return end
        vim.lsp.util.open_floating_preview({ result.signatures[1].label }, "markdown", {
          border = "rounded",
        })
      end
    end
  end,
})


vim.opt.exrc = true
vim.opt.secure = true
vim.opt.swapfile = false

-- Show the effects of a search / replace in a live preview window
vim.o.inccommand = "split"

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

local dap = require("dap")
table.insert(dap.configurations.python, 1, {
  type = "python",
  request = "launch",
  name = "Python: Launch file with current venv",

  program = "${file}",
  pythonPath = function()
    return require("venv-selector").python()
  end,
})
-- Use python debug config for 'debugpy' configurations
dap.adapters.debugpy = dap.adapters.python
require("dap.ext.vscode").load_launchjs(nil, {
  debugpy = dap.configurations.python,
})

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

