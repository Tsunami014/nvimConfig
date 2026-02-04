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

-- Add a dump highlights command to dump highlights to a temporary buffer
vim.api.nvim_create_user_command("DumpHighlights", function()
    -- Get highlight output as string
    local output = vim.api.nvim_exec2("highlight", { output = true }).output
    local lines = vim.split(output, "\n")

    -- Open a scratch buffer
    vim.cmd("tabnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false

    -- Actually highlight group names on each line
    for lnum, line in ipairs(lines) do
        -- get the first word of each line — usually the group name
        local group = line:match("^([%w_]+)")
        if group then
            -- Apply the highlight to the group name itself (col 0 to its length)
            vim.api.nvim_buf_add_highlight(buf, -1, group, lnum - 1, 0, #group)
        end
    end
end, {})


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
    ensure_installed = { "lua", "markdown", "markdown_inline", "python", "vim", "regex", 
        "bash", "yaml", "css", "html", "javascript", "latex", "tsx", "typst", "c", "cpp" },
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

vim.api.nvim_create_autocmd({"BufRead", "BufNewFile", "BufEnter"}, {
  pattern = "*",
  callback = function()
    if vim.bo.filetype ~= "markdown" then
      vim.opt_local.wrap = false
    else
      vim.opt_local.wrap = true
    end
  end
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

cppconfig            = require("user.cpp").config

require("dap.ext.vscode").load_launchjs(nil, {
    python  = pyconfig,
    debugpy = pyconfig,
    cpp     = cppconfig,
    c       = cppconfig
})

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
  },
  flags = {
    debounce_text_changes = 200, -- prevents spamming; milliseconds, tune 150-500
  },
  root_markers = { '.clangd', 'compile_commands.json' },
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
