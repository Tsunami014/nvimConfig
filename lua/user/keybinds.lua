local wk = require("which-key")

function Register(prefix, group, icon, mappings, leader)
    if leader == nil then
        leader = "<leader>"
    end
    local result = {
        { leader .. prefix, group = group, icon = icon }
    }

    for k, v in pairs(mappings) do
        local key = leader .. prefix .. k
        local rhs = v[1]
        local desc = v[2]
        local ico = icon
        if v[3] ~= nil then
            ico = v[3]
        end
        local mode = "n"
        if v.mode ~= nil then
            mode = v.mode
        end
        table.insert(result, { key, rhs, desc = desc, icon = ico, mode = mode })
    end

    wk.add({ mode = 'n', result })
end

function Map(mode, lhs, rhs, desc, options)
    if rhs == false then
        vim.api.nvim_del_keymap(mode, lhs)
        return
    end

    if options == nil then
        options = { noremap = true, silent = true }
    end
    if desc then options.desc = desc end
    vim.keymap.set(mode, lhs, rhs, options)
end

function ToMap(key, rhs, desc, icon, leader, mode)
    leader = leader or "<leader>"
    local fullKey = leader .. key
    local map = {
        fullKey,
        rhs,
        desc = desc,
    }
    if icon then map.icon = icon end
    if mode then map.mode = mode end
    return map
end


Register("s", "Session", "", {
    s = { function() require("resession").save() end, "Save Session" },
    l = { "<cmd>Telescope resession<CR>", "Session picker" },
    L = { function() require("resession").load() end, "Load Session" },
    d = { function() require("resession").delete() end, "Delete Session" }
})


Register("|", "Profiles", "", {
    ["|"] = { function()
        vim.notify('The currently active profile is: "' .. require("profile").current_name() .. '"')
    end, "Show Current Profile" },
    S = { function() require('profile').choose_profile() end, "Switch Profile" },
    g = { string.format(":!cd %s && git pull<CR>", vim.fn.stdpath("config")), "Git sync config" }
}, "")


Register("f", "Find", "󰍉", {
    g = { "<cmd>Telescope live_grep<cr>", "Find Grep in all dirs" },
    n = { "<cmd>Telescope notify<cr>", "Find notifications" },
    m = { "<cmd>messages<cr>", "Find messages" },
    f = { "<cmd>Telescope find_files<cr>", "Find Files in all dirs" },
    b = { "<cmd>Telescope buffers<cr>", "Find Buffers" },
    h = { "<cmd>Telescope help_tags<cr>", "Find Help" },
    H = { "<cmd>DumpHighlights<cr>", "Find highlights" },
    w = { "<cmd>Telescope grep_string<cr>", "Find Word Under Cursor" },
    F = { "<cmd>Telescope oldfiles<cr>", "Find Recent Files" },
    c = { "<cmd>Telescope commands<cr>", "Find Commands" },
    k = { "<cmd>Telescope keymaps<cr>", "Find Keymaps" },
    s = { "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Find in Current Buffer" },
    d = { "<cmd>Telescope diagnostics<cr>", "Find Diagnostics", "" },
    t = { "<cmd>TodoTelescope<cr>", "Find Todos", "" },
    T = { "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>", "Find Todo/Fix/Fixme", "" }
})

Register("r", "Find & replace", "󰗧", {
    r = { "<cmd>SearchReplaceSingleBufferOpen<cr>", "Replace in current buffer" },
    R = { "<cmd>SearchReplaceMultiBufferOpen<cr>", "Replace in all buffers" },
    w = { "<cmd>SearchReplaceSingleBufferCWord<cr>", "Replace current word" },
    W = { "<cmd>SearchReplaceSingleBufferCWORD<cr>", "Replace current word (greedy)" },
    e = { "<cmd>SearchReplaceSingleBufferCExpr<cr>", "Replace current expression" }
})

local gs = require("gitsigns")
Register("g", "Git", "󰊢", {
    g = { "<cmd>LazyGit<cr>", "Open LazyGit" },

    s = { gs.stage_buffer, "Stage Buffer" },
    R = { gs.reset_buffer, "Reset Buffer" },
    b = { function() gs.blame() end, "Blame Buffer" },
    d = { gs.diffthis, "Diff This" },
    D = { function() gs.diffthis("~") end, "Diff This ~" },
})
Register("h", "Hunks", "", {
    s = { ":Gitsigns stage_hunk<CR>", "Stage Hunk" },
    r = { ":Gitsigns reset_hunk<CR>", "Reset Hunk" },
    p = { gs.preview_hunk_inline, "Preview Hunk Inline" },
    b = { function() gs.blame_line({ full = true }) end, "Blame Line" }
}, "<leader>g")

Register("t", "Terminal", "", {
    t = { "<cmd>ToggleTerm<cr>", "Toggle Terminal" },
    h = { "<cmd>ToggleTerm direction=horizontal<cr>", "Toggle Horizontal Terminal" },
    v = { "<cmd>ToggleTerm direction=vertical<cr>", "Toggle Vertical Terminal" },
    f = { "<cmd>ToggleTerm direction=float<cr>", "Toggle Floating Terminal" }
})

Register("u", "UI", "", {
    ["."] = { "<cmd>LoadUI<cr>", "Initialise the UI" },
    w = { function() vim.cmd("set wrap!") end, "Toggle wrap", "󰖶" },
    i = { "<cmd>Inspect<cr>", "Inspect", "󰍉" }
})

-- Buffer things
Map("n", "<Tab>", "<cmd>BufferNext<cr>", "Next Buffer")
Map("n", "<S-Tab>", "<cmd>BufferPrevious<cr>", "Previous Buffer")
Map("n", "<A-l>", "<cmd>BufferMoveNext<cr>", "Move Buffer Right")
Map("n", "<A-h>", "<cmd>BufferMovePrevious<cr>", "Move Buffer Left")
Register("b", "Buffer", "󰓩", {
    n = { "<cmd>tabnew<cr>", "New Buffer" },
    p = { "<cmd>BufferPick<cr>", "Pick Buffer" },
    c = { "<cmd>BufferClose<cr>", "Close Buffer" },
    o = { "<cmd>BufferCloseAllButCurrent<cr>", "Close Other Buffers" },
    r = { "<cmd>BufferRestore<cr>", "Restore Buffer" },
    R = { "<cmd>e<cr>", "Refresh buffer", "" },
    a = { "<cmd>ASToggle<CR>", "Toggle autosave", "" },

    ["1"] = { "<cmd>BufferGoto 1<cr>", "First buffer" },
    ["0"] = { "<cmd>BufferLast<cr>", "Last Buffer" },

    l = { "<cmd>BufferMoveNext<cr>", "Move Buffer Right" },
    h = { "<cmd>BufferMovePrevious<cr>", "Move Buffer Left" },

    x = { "<cmd>BufferPin<cr>", "Pin/Unpin Buffer" },
    X = { "<cmd>BufferCloseAllButPinned<cr>", "Close Unpinned Buffers" },

    s = { "<cmd>BufferOrderByDirectory<cr>", "Sort by Directory" },
    S = { "<cmd>BufferOrderByLanguage<cr>", "Sort by Language" },
    L = { "<cmd>BufferOrderByWindowNumber<cr>", "Sort by Window" },

    W = { "<cmd>BufferWipeout<cr>", "Wipeout Buffer" },
})

-- Debugger stuff
local dap = require("dap")
local dapui = require("dapui")
local dbug = require("user.debug")
Map("n", "<F4>", dbug.stop, "Stop debugging")
Map("n", "<F17>", dbug.stop, "Stop debugging") -- Shift+F5
Map("n", "<F5>", function()
    if dap.session() then
        dap.continue()
    else
        dbug.pick()
    end
end, "Continue or start debugging")
Map("n", "<F6>", dbug.run_last, "Run last debug")
Map("n", "<F9>", dap.step_into, "DAP Step Into")
Map("n", "<F10>", dap.step_over, "DAP Step Over")
Map("n", "<F11>", dap.step_out, "DAP Step Out")
Map("n", "<C-CR>", require("dapui").eval, "DAP Hover")
Register("d", "Debug", "", {
    v = { "<cmd>VenvSelect<cr>", "Select venv python" },
    b = { dap.toggle_breakpoint, "Toggle Breakpoint" },
    B = { function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, "Conditional Breakpoint" },
    l = { "<cmd>DapShowLog<cr>", "Show logs" },
    u = { dapui.toggle, "DAP UI Toggle" },
    r = { dap.repl.open, "Open REPL" },
    e = { dapui.eval, "DAP Eval" }
})

-- Commands following <leader>
wk.add({
    ToMap("E", "<cmd>Neotree toggle<cr>", "Toggle NeoTree", ""),
    ToMap("O", "<cmd>Neotree reveal<cr>", "Reveal File in NeoTree", "󰈈"),

    ToMap("R", "<cmd>SearchReplaceSingleBufferOpen<cr>", "Replace in current buffer", "󰗧"),
    ToMap("F", "<cmd>Telescope live_grep<cr>", "Find grep in all dirs", "󰍉"),
    ToMap("G", "<cmd>LazyGit<cr>", "Open LazyGit", "󰊢"),
    ToMap("T", "<cmd>ToggleTerm<cr>", "Toggle terminal", ""),
    ToMap("W", function() vim.cmd("set wrap!") end, "Toggle wrap", "󰖶"),

    ToMap(",", function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local config = vim.api.nvim_win_get_config(win)
            if config.relative ~= "" then
                vim.api.nvim_win_close(win, false)
            end
        end
    end, "Dismiss popups", "󱠡"),
    ToMap(".", function()
        require("notify").dismiss()
    end, "Dismiss notifications", "󱠡"),

    ToMap("'", "<Plug>(doge-generate)", "Generate Docstring", "󰏫"), -- <cmd>DogeGenerate<cr>

    ToMap("/", function()
        local line = vim.api.nvim_win_get_cursor(0)[1] - 1
        require("user.commenter").toggle_comment_lines(line, line)
    end, "Toggle comment", "/"),
    ToMap("/", function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
        vim.schedule(function()
            local start_line = vim.fn.line("'<")
            local end_line = vim.fn.line("'>")

            if start_line > end_line then
                start_line, end_line = end_line, start_line
            end

            require("user.commenter").toggle_comment_lines(start_line - 1, end_line - 1)
        end)
    end, "Toggle comments", "/", nil, "v"),
})


-- Some lsp stuff!
Register("e", "Environment", "", {
    c = { function()
        vim.cmd('cd ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h'))
        pcall(function() require("resession").load(vim.fn.getcwd(), { dir = "dirsession", reset = true }) end)
    end, "Chdir to parent dir", "󰌑" },
    m = { "<cmd>Mason<cr>", "Open Mason", "󰏗" },
    a = { "<cmd>DirenvAllow<cr>", "Allow direnv" },
    L = { function()
        local cwd = vim.fn.getcwd()
        local lua_rc = cwd .. "/.nvim.lua"
        local vim_rc = cwd .. "/.nvimrc"

        if vim.fn.filereadable(lua_rc) == 1 then
            dofile(lua_rc)
            print("Loaded .nvim.lua from " .. lua_rc)
        elseif vim.fn.filereadable(vim_rc) == 1 then
            vim.cmd("source " .. vim_rc)
            print("Sourced .nvimrc from " .. vim_rc)
        else
            print("No .nvim.lua or .nvimrc found in current directory.")
        end
    end, "Load .nvimrc", "" },
}, ".")

local picker = require("snacks").picker
Register("g", "Goto", "󱞩", {
    D = { function() picker.lsp_declarations({ jump = { reuse_win = false } }) end, "Goto this declaration" },
    d = { function() picker.lsp_definitions({ jump = { reuse_win = false } }) end, "Goto this definition" },
    i = { function() picker.lsp_implementations({ jump = { reuse_win = false } }) end, "Goto this implementations" },
    t = { function() picker.lsp_type_definitions({ jump = { reuse_win = false } }) end, "Goto this type def" },
    r = { function() picker.lsp_references({ jump = { reuse_win = false } }) end, "Goto this references" },
    I = { picker.lsp_symbols, "Goto symbol" },
    s = { picker.lsp_symbols, "Goto symbol" },
    S = { picker.lsp_workspace_symbols, "Goto workspace symbol" },
}, ".")

Register("l", "LSP", "", {
    L = { "<cmd>LspLog<cr>", "Lsp logs" },
    l = { "<cmd>LspInfo<cr>", "Lsp info" },
    s = { "<cmd>LspStart<cr>", "Start lsp" },
    S = { "<cmd>LspStop<cr>", "Stop lsp" },
    r = { "<cmd>LspRestart<cr>", "Restart lsp" }
}, ".")

Register("c", "Symbols", "󱔁", {
    c = { "<cmd>Trouble symbols toggle<cr>", "Symbols" },
    C = { "<cmd>Trouble lsp toggle<cr>", "LSP references/definitions/..." },
    t = { "<plug>(vimtex-toc-toggle)", "Toggle Latex table of contents", "" },
}, ".")

Register("x", "Todos & Troubles", "", {
    a = { vim.lsp.buf.code_action, "apply lsp actions", "󰌑" },
    X = { "<cmd>trouble diagnostics toggle<cr>", "diagnostics", "" },
    x = { "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer Diagnostics", "" },
    l = { "<cmd>Trouble loclist toggle<cr>", "Location List", "" },
    q = { "<cmd>Trouble qflist toggle<cr>", "Quickfix List", "" },
    t = { "<cmd>Trouble todo toggle<cr>", "Todo" },
    T = { "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>", "Todo/Fix/Fixme" },
    o = { "<C-q>", "Telescope->quickfix (<C-q>)", "󰌑" },
    ["]"] = { "<cmd>cnext<cr>", "Next quick fix", "" },
    ["["] = { "<cmd>cprev<cr>", "Previous quick fix", "" }
}, ".")

Register(".", "Debug", "", {
    ["."] = { dbug.toggle_terminal, "Toggle Debug Terminal", "" },
    ["<Enter>"] = { vim.diagnostic.open_float, "Show diagnostics popup", "" },
    [" "] = { vim.lsp.buf.hover, "Show hover info", "󰋗" },

    V = { "<cmd>VenvSelect<cr>", "Select venv python" },
    B = { dap.toggle_breakpoint, "Toggle Breakpoint", "" },
    C = { function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, "Conditional Breakpoint", "" },
    A = { vim.lsp.buf.code_action, "Apply code action", "󰌑" },

    L = { "<cmd>DapShowLog<cr>", "Show logs" },
    S = { "<cmd>Trouble symbols toggle<cr>", "Toggle symbols", "󱔁" },
    X = { "<cmd>Trouble diagnostics toggle<cr>", "Toggle diagnostics", "" },
    D = { dapui.toggle, "DAP UI Toggle", "" },
    R = { vim.lsp.buf.rename, "Rename", "󰘎" },
    U = { dap.repl.open, "Open REPL", "" },
    E = { dapui.eval, "DAP Eval", "" },
}, "")


-- A more convenient use
Map({ 'n', 'v' }, '\\', '@q', '@q')

-- Clipboard stuff
vim.schedule(function() vim.opt.clipboard = "" end) -- Use Vim's default clipboard
Map({ 'n', 'v', 'x' }, '_', '"_', 'Black hole')
Map({ 'n', 'v', 'x' }, ';', '"+', 'System clipboard')
Map({ 'n', 'v', 'x' }, "'", '""', 'Vim clipboard')
Map('n', ';;', ':let @+ = @"<CR>', 'Transfer vim clipboard to system')
Map('n', ";'", ':let @" = @+<CR>', 'Transfer system clipboard to vim')
-- "_ black hole, "+ or "* system cbd, "" nvim default cbd

-- Move = keybinds to \
Map({ 'n', 'v', 'x' }, '?', '=', 'Correct indentation')
Map({ 'n', 'v', 'x' }, '??', '==', 'Correct indent of current line')
-- Replace = with - ; So the one button has both + and -
Map({ 'n', 'v', 'x' }, '=', '-', 'Start of previous line')
Map({ 'n', 'v', 'x' }, '+', '+', 'Start of next line')  -- To get the docs
-- Now add the delete to black hole!
Map({ 'n', 'v', 'x' }, '-', '"_dh', 'Delete to black hole')


-- Next & prev things
Map('n', ']t', require("todo-comments").jump_next, 'Next Todo Comment')
Map('n', ']h', function() gs.nav_hunk("next") end, 'Next Hunk')
Map('n', ']H', function() gs.nav_hunk("last") end, 'Last Hunk')
Map('n', ']x', function() vim.diagnostic.jump({ count = 1, float = true, severity = nil }) end, 'Next diagnostic')
Map('n', ']w', function() vim.diagnostic.jump({ count = 1, float = true, severity = vim.diagnostic.severity.WARN }) end, 'Next warning')
Map('n', ']e', function() vim.diagnostic.jump({ count = 1, float = true, severity = vim.diagnostic.severity.ERROR }) end, 'Next error')

Map('n', '[t', require("todo-comments").jump_prev, 'Previous Todo Comment')
Map('n', '[h', function() gs.nav_hunk("prev") end, 'Prev Hunk')
Map('n', '[H', function() gs.nav_hunk("first") end, 'First Hunk')
Map('n', '[x', function() vim.diagnostic.jump({ count = -1, float = true, severity = nil }) end, 'Prev diagnostic')
Map('n', '[w', function() vim.diagnostic.jump({ count = -1, float = true, severity = vim.diagnostic.severity.WARN }) end, 'Prev warning')
Map('n', '[e', function() vim.diagnostic.jump({ count = -1, float = true, severity = vim.diagnostic.severity.ERROR }) end, 'Prev error')

-- Misc stuff
Map('n', '/', '<cmd>SearchBoxIncSearch<CR>', 'Search')
Map({ 'v', 'x' }, '/', '<cmd>SearchBoxIncSearch visual_mode=true<CR>', 'Search')

Map({ 'n', 'v' }, '<C-Space>', '<cmd>WhichKey<CR>', 'Activate which-key')

Map({ 'n', 'v' }, "Q", "<cmd>q<CR>", "Quit")
Map({ 'n', 'v' }, "<A-BS>", "<cmd>BufferClose<cr>", "Close buffer")
Map({ 'n', 'v', 'x' }, '<c-a>', '<esc>ggVG', 'Select all')

Map("v", ">", ">gv", "Indent selection")
Map("v", "<", "<gv", "Deindent selection")

Map("n", "<C-.>", ">>", "Indent line")
Map("n", "<C-,>", "<<", "De-indent line")
Map("i", "<C-.>", "<C-t>", "Indent line")
Map("i", "<C-,>", "<C-d>", "De-indent line")


-- Completion stuff
local cmp = require("cmp")
Map({ 'i', 's' }, '<Tab>', function()
    if cmp.visible() then
        cmp.select_next_item()
    else
        local col = vim.fn.col(".")
        local spaces = vim.o.tabstop - ((col - 1) % vim.o.tabstop)
        vim.api.nvim_feedkeys(string.rep(" ", spaces), "n", false)
    end
end, 'Next completion')
Map({ 'i', 's' }, '<S-Tab>', function()
    if cmp.visible() then
        cmp.select_prev_item()
    end
end, 'Previous completion')

Map({ 'i', 's' }, '<C-Space>', function() cmp.complete() end, 'Open completions')


-- Window shenanigans
Map('n', ',', "<C-w><C-w>", 'Go to/toggle window')
Map('t', '<A-esc>', "<C-\\><C-n>", 'Exit terminal mode')
