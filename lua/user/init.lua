require "user.lualine-theme"
require "user.keybinds"

local pend = false
local loading = false
vim.api.nvim_create_user_command(
  'LoadUI',
  function(opts)
    local ncwd = opts.args
    loading = true
    if ncwd ~= "" then
      vim.cmd("cd " .. vim.fn.fnameescape(ncwd))
      local saved_eventignore = vim.o.eventignore
      vim.o.eventignore = "all"
      local loaded = pcall(function() require("resession").load(vim.fn.getcwd(), { dir = "dirsession", silence_errors = true, reset = true }) end)
      vim.o.eventignore = saved_eventignore
      vim.defer_fn(function()
        vim.cmd("Neotree")
        vim.cmd("wincmd w")
      end, 10)
    else
      vim.cmd("Neotree")
      vim.cmd("wincmd w")
    end
    loading = false
  end, { nargs = '?' }
)

vim.api.nvim_create_autocmd({
  "BufAdd",
  "BufNewFile",
  "BufDelete",
  "BufWipeout",
}, {
  callback = function()
    if pend or loading then
      return
    end
    pend = true
    vim.defer_fn(function()
      if vim.api.nvim_get_mode().mode == "n" then
        require("resession").save(vim.fn.getcwd(), { dir = "dirsession", notify = false })
      end
      pend = false
    end, 500)
  end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc(-1) > 0 then
      local dir = vim.fn.argv(0)
      if vim.fn.isdirectory(dir) == 1 then
        vim.defer_fn(function()
          vim.cmd("LoadUI " .. vim.fn.fnameescape(dir))
        end, 10)
      end
    end
  end,
  nested = true,
})

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
    local output = vim.api.nvim_exec2("highlight", { output = true }).output
    local lines = vim.split(output, "\n")

    vim.cmd("tabnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false

    for lnum, line in ipairs(lines) do
        local group = line:match("^([%w_]+)")
        if group then
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

local wrapIn = {"markdown", "tex"}
local function doWrap(filetype)
    for index, value in pairs(wrapIn) do
        if filetype == value then
            return true
        end
    end
    return false
end
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile", "BufEnter"}, {
  pattern = "*",
  callback = function()
    vim.opt_local.wrap = doWrap(vim.bo.filetype)
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
