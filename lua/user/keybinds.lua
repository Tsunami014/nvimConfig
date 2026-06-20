local wk = require("which-key")
local dap = require("dap")
local dapui = require("dapui")
local dbug = require("user.debug")
local sesh = require("resession")
local links = require("user.utils.links")

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

function RunKeys(keys)
    return function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false) end
end


Register("f", "Find", "󰍉", {
    g = { "<cmd>Telescope live_grep<cr>", "Find Grep in all dirs" },
    n = { "<cmd>Telescope notify<cr>", "Find notifications" },
    m = { "<cmd>messages<cr>", "Find messages" },
    f = { "<cmd>Telescope find_files<cr>", "Find Files in all dirs" },
    b = { "<cmd>Telescope buffers<cr>", "Find Buffers" },
    h = { "<cmd>Telescope help_tags<cr>", "Find Help" },
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

-- Buffer things
Map({ 'n', 'v' }, "<A-BS>", "<cmd>BufferClose<cr>", "Close buffer")
Map("n", "<Tab>", "<cmd>BufferNext<cr>", "Next Buffer")
Map("n", "<S-Tab>", "<cmd>BufferPrevious<cr>", "Previous Buffer")
Map("n", "<A-h>", "<cmd>BufferMovePrevious<cr>", "Move Buffer Left")
Map("n", "<A-l>", "<cmd>BufferMoveNext<cr>", "Move Buffer Right")

Map({ 'n', 'v' }, "<C-A-BS>", "<cmd>tabclose<cr>", "Close Layout")
Map("n", "<C-Tab>", "<cmd>tabnext<cr>", "Next Layout")
Map("n", "<C-S-Tab>", "<cmd>tabprev<cr>", "Previous Layout")
Map("n", "<C-A-h>", "<cmd>tabmove -1<cr>", "Move Layout -1")
Map("n", "<C-A-l>", "<cmd>tabmove +1<cr>", "Move Layout +1")
Register("b", "Buffer", "󰓩", {
    n = { "<cmd>enew<cr>", "New Buffer" },
    h = { "<cmd>new<cr>", "New Buffer Horizontal" },
    h = { "<cmd>vnew<cr>", "New Buffer Vertical" },
    p = { "<cmd>BufferPick<cr>", "Pick Buffer" },
    c = { "<cmd>BufferClose<cr>", "Close Buffer" },
    C = { "<cmd>BufferClose!<cr>", "Force close Buffer" },
    o = { "<cmd>BufferCloseAllButCurrent<cr>", "Close Other Buffers" },
    r = { "<cmd>BufferRestore<cr>", "Restore Buffer" },
    R = { "<cmd>e<cr>", "Refresh buffer", "" },

    ["1"] = { "<cmd>BufferGoto 1<cr>", "First buffer" },
    ["0"] = { "<cmd>BufferLast<cr>", "Last Buffer" },

    h = { "<cmd>BufferMovePrevious<cr>", "Move Buffer Left" },
    l = { "<cmd>BufferMoveNext<cr>", "Move Buffer Right" },

    x = { "<cmd>BufferPin<cr>", "Pin/Unpin Buffer" },
    X = { "<cmd>BufferCloseAllButPinned<cr>", "Close Unpinned Buffers" },

    s = { "<cmd>BufferOrderByDirectory<cr>", "Sort by Directory" },
    S = { "<cmd>BufferOrderByLanguage<cr>", "Sort by Language" },
    L = { "<cmd>BufferOrderByWindowNumber<cr>", "Sort by Window" },

    w = { "<cmd>BufferWipeout<cr>", "Wipeout Buffer" }, -- Completely purges it from memory
})
Register("l", "Layouts", "", {
    n = { "<cmd>tabnew<cr>", "New Layout" },
    c = { "<cmd>tabclose<cr>", "Close Layout" },
    o = { "<cmd>tabonly<cr>", "Close other tab pages" },

    h = { "<cmd>tabmove -1<cr>", "Move Layout -1" },
    l = { "<cmd>tabmove +1<cr>", "Move Layout +1" },
})

-- Debugger stuff
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
    d = { dbug.toggle_terminal, "Toggle Debug Terminal", "" },
    v = { "<cmd>VenvSelect<cr>", "Select venv python" },
    b = { dap.toggle_breakpoint, "Toggle Breakpoint" },
    B = { function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, "Conditional Breakpoint" },
    l = { "<cmd>DapShowLog<cr>", "Show logs" },
    L = { "<cmd>LspLog<cr>", "Lsp logs", "" },
    i = { "<cmd>LspInfo<cr>", "Lsp info", "" },
    u = { dapui.toggle, "DAP UI Toggle" },
    r = { dap.repl.open, "Open REPL" },
    e = { dapui.eval, "DAP Eval" },
    s = { "<cmd>LspStart<cr>", "Start lsp", "" },
    S = { "<cmd>LspStop<cr>", "Stop lsp", "" },
    R = { "<cmd>LspRestart<cr>", "Restart lsp", "" },
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

local function lsp(scope)
  return function() require('mini.extra').pickers.lsp({ scope = scope }) end
end
Register("c", "Symbols", "󱔁", {
    c = { "<cmd>Trouble symbols toggle<cr>", "Symbols" },
    C = { "<cmd>Trouble lsp toggle<cr>", "LSP references/definitions/..." },
    R = { vim.lsp.buf.rename, "Rename symbol", "󰘎" },

    D = { lsp('declaration'), "Goto this declaration" },
    d = { lsp('definition'), "Goto this definition" },
    i = { lsp('implementation'), "Goto this implementations" },
    t = { lsp('type_definition'), "Goto this type def" },
    r = { lsp('references'), "Goto this references" },
    s = { lsp('document_symbol'), "Goto symbol" },
    S = { lsp('workspace_symbol'), "Goto workspace symbol" },
})

Register("e", "Environment", "", {
    c = { function()
        vim.cmd('cd ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h'))
        pcall(function() require("resession").load(vim.fn.getcwd(), { dir = "dirsession", reset = true }) end)
    end, "Chdir to parent dir", "󰌑" },
    m = { "<cmd>Mason<cr>", "Open Mason", "󰏗" },
    a = { "<cmd>DirenvAllow<cr>", "Allow direnv" },
    A = { "<cmd>ASToggle<CR>", "Toggle autosave", "" },
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
    f = { function()
        vim.notify("Reentering dir...")
        vim.api.nvim_exec_autocmds("DirChanged", { pattern = "global", })
    end, "Reenter directory", "" }, -- Fixes problems with some things
    g = { string.format(":!cd %s && git pull<CR>", vim.fn.stdpath("config")), "Git sync config" }
})
Register("|", "Profiles", "", {
    ["|"] = { function()
        vim.notify('The currently active profile is: "' .. require("profile").current_name() .. '"')
    end, "Show Current Profile" },
    S = { function() require('profile').choose_profile() end, "Switch Profile" },
}, "<leader>e")
Register("s", "Session", "", {
    s = { sesh.save, "Save Session" },
    l = { "<cmd>Telescope resession<CR>", "Session picker" },
    d = { sesh.delete, "Delete Session" }
}, "<leader>e")

Register("t", "Terminal", "", {
    t = { "<cmd>ToggleTerm<cr>", "Toggle Terminal" },
    h = { "<cmd>ToggleTerm direction=horizontal<cr>", "Toggle Horizontal Terminal" },
    v = { "<cmd>ToggleTerm direction=vertical<cr>", "Toggle Vertical Terminal" },
    f = { "<cmd>ToggleTerm direction=float<cr>", "Toggle Floating Terminal" }
})

Register("x", "Todos & Troubles", "", {
    a = { vim.lsp.buf.code_action, "apply lsp actions", "󰌑" },
    X = { "<cmd>trouble diagnostics toggle<cr>", "diagnostics", "" },
    x = { "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer Diagnostics", "" },
    l = { "<cmd>Trouble loclist toggle<cr>", "Location List", "" },
    q = { "<cmd>Trouble qflist toggle<cr>", "Quickfix List", "" },
    t = { "<cmd>Trouble todo toggle<cr>", "Todo" },
    T = { "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>", "Todo/Fix/Fixme" },
    o = { "<C-q>", "Telescope->quickfix (<C-q>)", "󰌑" },
})

Register("u", "UI/Formatting", "󰉼", {
    f = { "<cmd>GuessIndent<cr>", "Guess indentation" },
    n = { require("user.utils.fixtables").fix_table, "Normalise md table", "󰓫" },
    ["'"] = { "<Plug>(doge-generate)", "Generate Docstring", "󰏫" }, -- <cmd>DogeGenerate<cr>
    s = { function()
        vim.opt.spell = not vim.opt.spell
        vim.notify((vim.opt.spell and "Checking" or "Not checking") .. " spelling")
    end, "Toggle spell check", "" },
    S = { function()
        vim.ui.input({ prompt = "Set indent spacing & re-indent file: " }, function(input)
            local spaces = tonumber(input)
            if spaces then
                vim.opt_local.shiftwidth = spaces
                vim.opt_local.tabstop = spaces
                vim.opt_local.softtabstop = spaces

                local current_win = vim.api.nvim_get_current_win()
                local cursor_pos = vim.api.nvim_win_get_cursor(current_win)
                vim.cmd("silent! retab!")
                vim.cmd("normal! gg=G")
                pcall(vim.api.nvim_win_set_cursor, current_win, cursor_pos)
                vim.notify("File indented to " .. spaces .. " spaces.")
            elseif input ~= nil then
                vim.notify("Invalid input", vim.log.levels.WARN)
            end
        end)
    end, "Set indentation" },
    W = { function()
        MiniTrailspace.trim()
        MiniTrailspace.trim_last_lines()
    end, "Delete trailing whitespace" },

    w = { function() vim.cmd("set wrap!") end, "Toggle wrap", "󰖶" },
    i = { "<cmd>Inspect<cr>", "Inspect", "󰍉" },
    h = { "<cmd>DumpHighlights<cr>", "Dump highlights" },
    t = { "<plug>(vimtex-toc-toggle)", "Toggle Latex table of contents", "" },
    [","] = { require("notify").dismiss, "Dismiss notifications", "󱠡" },
})

-- Commands following <leader>
Register("<leader>", "", "󱁐", {
    E = { "<cmd>Neotree toggle<cr>", "Toggle NeoTree", "" },
    O = { "<cmd>Neotree reveal<cr>", "Reveal File in NeoTree", "󰈈" },
    U = { "<cmd>UndotreeToggle<cr>", "Undo tree", "" },
    I = { links.toggle, "Toggle index file", "" },
    L = { require("user.utils.links-buf").toggle, "Toggle links panel", "" },

    F = { RunKeys("<leader>fg"), "Find grep in all dirs", "󰍉" },
    T = { RunKeys("<leader>tt"), "Toggle terminal", "" },
    D = { RunKeys("<leader>dd"), "Toggle DAP UI", "" },

    ["<Enter>"] = { vim.diagnostic.open_float, "Show diagnostics popup", "" },
    [","] = { function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local config = vim.api.nvim_win_get_config(win)
            if config.relative ~= "" then
                vim.api.nvim_win_close(win, false)
            end
        end
    end, "Dismiss popups", "󱠡" },

    ["/"] = { function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        MiniComment.toggle_lines(line, line)
    end, "Toggle comment", "/" },
}, "")
Map('v', "<leader>/", function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
    vim.schedule(function()
        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
        MiniComment.toggle_lines(start_line, end_line)
    end)
end, "Toggle comments")


-- A more convenient @@
Map({ 'n', 'v' }, '\\', '@@', '@@')

-- Window shenanigans
Map('n', ',', "<C-w><C-w>", 'Go to/toggle window')
Map('t', '<A-esc>', "<C-\\><C-n>", 'Exit terminal mode')
Map({ 'n', 'i', 'v', 't' }, '<A-space>', function()
    dbug.toggle_terminal()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), 'n', true)
end, 'Toggle Debug Terminal')

-- Clipboard stuff - "_ black hole, "+ or "* system cbd, "" nvim default cbd
vim.schedule(function() vim.opt.clipboard = "" end) -- Use Vim's default clipboard
Map({ 'n', 'v', 'x' }, '_', '"_', 'Black hole')
Map({ 'n', 'v', 'x' }, ';', '"+', 'System clipboard')
Map({ 'n', 'v', 'x' }, "'", '""', 'Vim clipboard')
Map('n', ';;', ':let @+ = @"<CR>', 'Transfer vim clipboard to system')
Map('n', ";'", ':let @" = @+<CR>', 'Transfer system clipboard to vim')
Map({ 'n', 'v', 'x' }, '-', '"_d', 'Delete to black hole')

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

local ji = require("user.utils.jump").interest
vim.keymap.set("n", "]]", function() ji("next") end, { desc = "Next interesting thing" })
vim.keymap.set("n", "[[", function() ji("prev") end, { desc = "Previous interesting thing" })

-- Indent stuff
Map("v", ">", ">gv", "Indent selection")
Map("v", "<", "<gv", "Deindent selection")

Map("n", "<C-.>", ">>", "Indent line")
Map("n", "<C-,>", "<<", "De-indent line")
Map("i", "<C-.>", "<C-t>", "Indent line")
Map("i", "<C-,>", "<C-d>", "De-indent line")

-- Links
Map('n', '<Enter>', links.follow, 'Follow link')
Map('n', '<S-Enter>', function() links.follow(true) end, 'Follow link in current buf')
Map({ 'v', 'x' }, '<Enter>', links.visual_follow, 'Follow link')
Map({ 'v', 'x' }, '<S-Enter>', function() links.visual_follow(true) end, 'Follow link in current buf')

-- Misc stuff
Map('n', '/', '<cmd>SearchBoxIncSearch<CR>', 'Search')
Map({ 'v', 'x' }, '/', '<cmd>SearchBoxIncSearch visual_mode=true<CR>', 'Search')

Map({ 'n', 'v' }, '<C-Space>', '<cmd>WhichKey<CR>', 'Activate which-key')

Map({ 'n', 'v' }, "Q", "<cmd>q<CR>", "Quit")
Map({ 'n', 'v', 'x' }, '<c-a>', '<esc>ggVG', 'Select all')


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
