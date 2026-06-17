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


local dap = require("dap")

-- Stop closing after finish execution
dap.listeners.before.event_terminated["dapui_config"] = nil
dap.listeners.before.event_exited["dapui_config"] = nil

local vs = require("venv-selector")
local pyconfig = {
  {
    type = "python",
    request = "launch",
    name = "Python: Launch file with current venv",

    program = "${file}",
    console = "integratedTerminal",
    pythonPath = function()
      return vs.python()
    end,
  }
}
dap.configurations.python = pyconfig
-- Use python debug config for 'debugpy' configurations
function pyadapter(callback, config)
  local venv = vs.python()
  if not venv then
    vim.notify("[DAP] No venv selected — falling back to system Python", vim.log.levels.WARN)
    venv = vim.fn.exepath("python3")
  end

  callback({
    type = "executable",
    command = venv,
    args = { '-m', 'debugpy.adapter' },
    options = {
      source_filetype = 'python',
    }
  })
end

dap.adapters.python  = pyadapter
dap.adapters.debugpy = pyadapter

-- Some language server options
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config('pyright', {
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
})

vim.lsp.config('ruff', {
  settings = {
    ruff_lsp = {
      ignore = { "F405", "F841" },
    }
  }
})

vim.lsp.config('clangd', {
  capabilities = capabilities,
  cmd = {
    "clangd",
    "-j=8",
    "--background-index",
    "--clang-tidy=false",
    "--pch-storage=memory",
    "--compile-commands-dir=.",
  },
  flags = {
    debounce_text_changes = 200, -- prevents spamming, milliseconds
  },
  root_markers = { '.clangd', 'compile_commands.json' },
  root_dir = "compile_commands.json",
})

vim.lsp.enable({ "pyright", "ruff", "clangd" })

-- Disable auto formatting
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.server_capabilities.documentFormattingProvider then
            client.server_capabilities.documentFormattingProvider = false
        end
    end,
})


-- Add ctrl+enter keybind for the dap repl for convenience
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dap-repl",
  callback = function(args)
    vim.keymap.set("i", "<C-CR>", function()
      local repl = require("dap.repl")
      local line = vim.api.nvim_get_current_line()
      local cmd = line:gsub("^dap> ", "", 1)

      if cmd ~= "" then
        repl.execute("-exec " .. cmd)
        vim.api.nvim_set_current_line("dap> ")
        vim.api.nvim_win_set_cursor(0, {
          vim.fn.line("."),
          #"dap> ",
        })
      end
    end, {
      buffer = args.buf,
      desc = "Execute REPL command via -exec",
    })
  end,
})
