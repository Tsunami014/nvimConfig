local wk = require("which-key")

function Shortcut(key, parent, rhs, desc, icon, mode)
    return {
        __shortcut = true,
        key = key,
        parent = parent,
        rhs = rhs,
        desc = desc,
        icon = icon,
        mode = mode,
    }
end

shortcut_leader = ","  -- <leader><leader> also works
local shortcuts = {
    { shortcut_leader, group = "Shortcuts", icon = "" }
}

function Register(prefix, group, icon, mappings, leader)
    if leader == nil then
        leader = "<leader>"
    end
    local result = {
        { leader .. prefix, group = group, icon = icon }
    }

    for k, v in pairs(mappings) do
        if type(v) == "table" and v.__shortcut then
            local longKey = leader .. prefix .. v.key
            local altKey = shortcut_leader .. v.parent
            table.insert(result, {
                longKey,
                v.rhs,
                desc = v.desc,
                icon = v.icon or icon,
                mode = v.mode or "n",
            })
            table.insert(shortcuts, {
                altKey,
                v.rhs,
                desc = v.desc,
                icon = v.icon or icon,
                mode = v.mode or "n",
            })
        else
            local key = leader .. prefix .. k
            local rhs = v[1]
            local desc = v[2]
            local ico = icon
            if v.icon ~= nil then
                ico = v.icon
            end
            local mode = "n"
            if v.mode ~= nil then
                mode = v.mode
            end
            table.insert(result, { key, rhs, desc = desc, icon = ico, mode = mode })
        end
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

-- Clipboard stuff
vim.schedule(function() vim.opt.clipboard = "" end) -- Use Vim's default clipboard
Map({ 'n', 'v', 'x' }, '_', '"_', 'Black hole')
Map({ 'n', 'v', 'x' }, ';', '"+', 'System clipboard')
Map({ 'n', 'v', 'x' }, "'", '""', 'Vim clipboard')
Map('n', ';;', ':let @+ = @"<CR>', 'Transfer vim clipboard to system')
Map('n', ";'", ':let @" = @+<CR>', 'Transfer system clipboard to vim')
-- "_ black hole, "+ or "* system cbd, "" nvim default cbd

-- Move = keybinds to \
Map({ 'n', 'v', 'x' }, '\\', '=', 'Correct indentation')
Map({ 'n', 'v', 'x' }, '\\\\', '==', 'Correct indent of current line')
-- Replace = with - ; So the one button has both + and -
Map({ 'n', 'v', 'x' }, '=', '-', 'Start of previous line')
Map({ 'n', 'v', 'x' }, '+', '+', 'Start of next line')  -- To get the docs
-- Now add the delete to black hole!
Map({ 'n', 'v', 'x' }, '-', '"_dh', 'Delete to black hole')


local proj = require("project")
Register("p", "Projects", "󰉓", {
    s = { proj.save_project, "Save project" },
    l = { proj.findProjects, "Load project" }
})

Register("|", "Profiles", "", {
    c = { function()
        vim.notify('The currently active profile is: "' .. require("profile").current .. '"')
    end, "Show Current Profile" },
    s = { function() require('profile').choose_profile() end, "Switch Profile" }
})


Register("f", "Find", "󰍉", {
    Shortcut("g", "f", "<cmd>Telescope live_grep<cr>", "Find Grep in all dirs", "󰍉"),
    Shortcut("n", "n", "<cmd>Telescope notify<cr>", "Find notifications", "󰍉"),
    Shortcut("m", "m", "<cmd>messages<cr>", "Find messages", "󰍉"),
    f = { "<cmd>Telescope find_files<cr>", "Find Files in all dirs" },
    b = { "<cmd>Telescope buffers<cr>", "Find Buffers" },
    h = { "<cmd>Telescope help_tags<cr>", "Find Help" },
    H = { "<cmd>DumpHighlights<cr>", "Find highlights" },
    w = { "<cmd>Telescope grep_string<cr>", "Find Word Under Cursor" },
    F = { "<cmd>Telescope oldfiles<cr>", "Find Recent Files" },
    c = { "<cmd>Telescope commands<cr>", "Find Commands" },
    k = { "<cmd>Telescope keymaps<cr>", "Find Keymaps" },
    s = { "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Find in Current Buffer" },
    d = { "<cmd>Telescope diagnostics<cr>", "Find Diagnostics" },
    t = { "<cmd>TodoTelescope<cr>", "Find Todos", icon = "" },
    T = { "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>", "Find Todo/Fix/Fixme", icon = "" }
})

Register("r", "Find & replace", "󰗧", {
    Shortcut("r", "r", "<cmd>SearchReplaceSingleBufferOpen<cr>", "Replace in current buffer", "󰗧"),
    R = { "<cmd>SearchReplaceMultiBufferOpen<cr>", "Replace in all buffers" },
    w = { "<cmd>SearchReplaceSingleBufferCWord<cr>", "Replace current word" },
    W = { "<cmd>SearchReplaceSingleBufferCWORD<cr>", "Replace current word (greedy)" },
    e = { "<cmd>SearchReplaceSingleBufferCExpr<cr>", "Replace current expression" }
})


Register("x", "Todos & Troubles", "", {
    Shortcut("a", "a", vim.lsp.buf.code_action, "Apply LSP actions", "󰌑"),
    Shortcut("x", "x", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics", ""),
    X = { "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer Diagnostics", icon = "" },
    l = { "<cmd>Trouble loclist toggle<cr>", "Location List", icon = "" },
    q = { "<cmd>Trouble qflist toggle<cr>", "Quickfix List", icon = "" },
    t = { "<cmd>Trouble todo toggle<cr>", "Todo" },
    T = { "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>", "Todo/Fix/Fixme" },
    o = { "<C-q>", "Telescope->quickfix (<C-q>)", icon = "󰌑" },
    Shortcut("]", "]", "<cmd>cnext<cr>", "Next quick fix", ""),
    Shortcut("[", "[", "<cmd>cprev<cr>", "Previous quick fix", ""),
})

Register("s", "Session", "", {
    s = { function() require("resession").save() end, "Save Session" },
    l = { "<cmd>Telescope resession<CR>", "Session picker" },
    L = { function() require("resession").load() end, "Load Session" },
    d = { function() require("resession").delete() end, "Delete Session" }
})

local gs = require("gitsigns")
Register("g", "Git", "󰊢", {
    Shortcut("g", "g", "<cmd>LazyGit<cr>", "Open LazyGit", "󰊢"),

    s = { gs.stage_buffer, "Stage Buffer" },
    R = { gs.reset_buffer, "Reset Buffer" },
    b = { function() gs.blame() end, "Blame Buffer" },
    d = { gs.diffthis, "Diff This" },
    D = { function() gs.diffthis("~") end, "Diff This ~" },
})
Register("h", "Hunks", "", {
    s = { ":Gitsigns stage_hunk<CR>", "Stage Hunk" },
    r = { ":Gitsigns reset_hunk<CR>", "Reset Hunk" },
    p = { gs.preview_hunk_inline, "Preview Hunk Inline" },
    b = { function() gs.blame_line({ full = true }) end, "Blame Line" }
}, "<leader>g")

local dap = require("dap")
local dapui = require("dapui")
Map("n", "<F5>", dap.continue, "DAP Continue")
Map("n", "<F6>", dap.run_last, "DAP Run last config")
Map("n", "<F10>", dap.step_over, "DAP Step Over")
Map("n", "<F11>", dap.step_into, "DAP Step Into")
Map("n", "<F12>", dap.step_out, "DAP Step Out")
Register("d", "Debug", "", {
    v = { "<cmd>VenvSelect<cr>", "Select venv python" },
    c = { function() require("user.cpp").set_new_build_args() end, "Set build args c/c++" },

    Shortcut("b", "b", dap.toggle_breakpoint, "Toggle Breakpoint", ""),
    B = { function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, "Conditional Breakpoint" },
    r = { dap.repl.open, "Open REPL" },
    l = { dap.run_last, "Run Last DAP" },
    Shortcut("u", "d", dapui.toggle, "DAP UI Toggle", ""),
    e = { dapui.eval, "DAP Eval" }
})

Register("t", "Terminal", "", {
    Shortcut("t", "t", "<cmd>ToggleTerm<cr>", "Toggle Terminal", ""),
    h = { "<cmd>ToggleTerm direction=horizontal<cr>", "Toggle Horizontal Terminal" },
    v = { "<cmd>ToggleTerm direction=vertical<cr>", "Toggle Vertical Terminal" },
    f = { "<cmd>ToggleTerm direction=float<cr>", "Toggle Floating Terminal" }
})

Register("k", "Preview (knap)", "", {
    Shortcut("k", "k", function() require("knap").process_once() end, "Process preview once", ""),
    c = { function() require("knap").close_viewer() end, "Close preview" },
    a = { function() require("knap").toggle_autopreviewing() end, "Toggle auto preview" },
})

Map("n", "<Tab>", "<cmd>BufferNext<cr>", "Next Buffer")
Map("n", "<S-Tab>", "<cmd>BufferPrevious<cr>", "Previous Buffer")
Map("n", "<A-l>", "<cmd>BufferMoveNext<cr>", "Move Buffer Right")
Map("n", "<A-h>", "<cmd>BufferMovePrevious<cr>", "Move Buffer Left")
Register("b", "Buffer", "󰓩", {
    n = { "<cmd>tabnew<cr>", "New Buffer" },
    Shortcut("p", "p", "<cmd>BufferPick<cr>", "Pick Buffer", "󰓩"),
    c = { "<cmd>BufferClose<cr>", "Close Buffer" },
    o = { "<cmd>BufferCloseAllButCurrent<cr>", "Close Other Buffers" },
    r = { "<cmd>BufferRestore<cr>", "Restore Buffer" },
    a = { "<cmd>ASToggle<CR>", "Toggle autosave", icon = "" },

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

local quotes = {
    "YOU GOT THIS!",
    "I BELIEVE IN YOU!",
    "DON'T GIVE UP!",
    "KEEP GOING!",
    "IT'S ALL THE CODE'S FAULT NOT YOURS!",
    "BUGS ARE INEVITABLE DURING PRODUCTION."
}
Register("u", "UI", "", {
    m = { ":MarkdownPreview<CR>", "Markdown preview", icon = "󰈈" },
    M = {
        function()
            local quote = quotes[math.random(#quotes)]
            vim.notify(quote, vim.log.levels.INFO, { title = "Motivation Boost" })
        end,
        "Motivation",
        icon = ""
    },

    ["."] = { proj.loadUI, "Initialise the UI", },
    Shortcut("w", "w", function()
        vim.cmd("set wrap!")
        local wrap_status = vim.wo.wrap and "enabled" or "disabled"
        vim.notify("Wrap " .. wrap_status, vim.log.levels.INFO, { title = "Wrap Toggle" })
    end,
    "Toggle wrap", "󰖶"),
})

Register("P", "Packages", "", {
    m = { "<cmd>Mason<cr>", "Open Mason" }
})

Register("c", "Symbols", "󱔁", {
    Shortcut("c", "c", "<cmd>Trouble symbols toggle<cr>", "Symbols", "󱔁"),
    Shortcut("C", "C", "<cmd>Trouble lsp toggle<cr>", "LSP references/definitions/...", "󱔁"),
})

Register("]", "Next", "󰒭", {
    t = { function() require("todo-comments").jump_next() end, "Next Todo Comment", icon = "" },
    h = { function() gs.nav_hunk("next") end, "Next Hunk", icon = "󰊢" },
    H = { function() gs.nav_hunk("last") end, "Last Hunk", icon = "󰊢" }
})
Register("[", "Previous", "󰒮", {
    t = { function() require("todo-comments").jump_prev() end, "Previous Todo Comment", icon = "" },
    h = { function() gs.nav_hunk("prev") end, "Prev Hunk", icon = "󰊢" },
    H = { function() gs.nav_hunk("first") end, "First Hunk", icon = "󰊢" }
})

-- Misc stuff
Map('n', '/', '<cmd>SearchBoxIncSearch<CR>', 'Search')
Map({ 'v', 'x' }, '/', '<cmd>SearchBoxIncSearch visual_mode=true<CR>', 'Search')

Map({ 'n', 'v' }, '?', '<cmd>WhichKey<CR>', 'Activate which-key')

Map({ "n", "v" }, "Q", "<cmd>q<CR>", "Quit")
Map({ 'n', 'v', 'x' }, '<c-a>', '<esc>ggVG', 'Select all')

Map("v", ">", ">gv", "Indent selection")
Map("v", "<", "<gv", "Deindent selection")

Map("i", "<C-.>", "<C-t>", "Indent line")
Map("i", "<C-,>", "<C-d>", "De-indent line")

comms = require("user.commenter")
-- Commands following <leader>
wk.add({
    -- Commands
    ToMap("e", "<cmd>Neotree toggle<cr>", "Toggle NeoTree", ""),
    ToMap("o", "<cmd>Neotree reveal<cr>", "Reveal File in NeoTree", "󰈈"),

    ToMap("i", "<cmd>Inspect<cr>", "Inspect", "󰍉"),

    ToMap("n", "<cmd>tabnew<cr>", "New buffer", "󰓩"),

    ToMap("L", function()
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
    end, "Load cwd/.nvimrc", ""),

    ToMap("C", function()
        vim.cmd('cd ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h'))
    end, "Chdir to parent dir", "󰌑"),

    ToMap(".", function()
        require("notify").dismiss()
    end, "Dismiss notification", "󱠡"),

    ToMap('"', "<Plug>(doge-generate)", "Generate Docstring", "󰏫"), -- <cmd>DogeGenerate<cr>

    ToMap("/", function()
        local line = vim.api.nvim_win_get_cursor(0)[1] - 1
        comms.toggle_comment_lines(line, line)
    end, "Toggle comment", "/"),
    ToMap("/", function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
        vim.schedule(function()
            local start_line = vim.fn.line("'<")
            local end_line = vim.fn.line("'>")

            if start_line > end_line then
                start_line, end_line = end_line, start_line
            end

            comms.toggle_comment_lines(start_line - 1, end_line - 1)
        end)
    end, "Toggle comments", "/", nil, "v"),
})

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

wk.add({ mode = 'n', shortcuts })

