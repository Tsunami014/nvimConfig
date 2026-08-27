local M = {}

-- Reset some common directory environment things
local function resetEnv()
    if type(_G.EnvReset) == "function" then
        EnvReset()
        _G.EnvReset = nil
    end
    _G.DebugActions = nil
end

function M.dirch(ignorefail)
    resetEnv()
    local cwd = vim.fn.getcwd()
    local lua_rc = cwd .. "/.nvim.lua"
    local vim_rc = cwd .. "/.nvimrc"

    if vim.fn.filereadable(lua_rc) == 1 then
        local content = vim.secure.read(lua_rc)
        if content then
            local chunk, err = load(content, "@" .. lua_rc)
            if chunk then
                local ok, run_err = pcall(chunk)
                if not ok then
                    vim.notify("Error running .nvim.lua: " .. run_err, vim.log.levels.ERROR)
                end
            else
                vim.notify("Error parsing .nvim.lua: " .. err, vim.log.levels.ERROR)
            end
        end
    elseif vim.fn.filereadable(vim_rc) == 1 then
        local content = vim.secure.read(vim_rc)
        if content then
            vim.cmd(content)
        end
    elseif not ignorefail then
        vim.notify("No .nvim.lua or .nvimrc found in current directory.")
    end
end

function M.trust()
    local cwd = vim.fn.getcwd()
    local lua_rc = cwd .. "/.nvim.lua"
    local vim_rc = cwd .. "/.nvimrc"

    if vim.fn.filereadable(lua_rc) == 1 then
        vim.secure.trust({ action = 'remove', path = ".nvim.lua" })
    elseif vim.fn.filereadable(vim_rc) == 1 then
        vim.secure.trust({ action = 'remove', path = ".nvimrc" })
    elseif not ignorefail then
        vim.notify("No .nvim.lua or .nvimrc found in current directory.")
    end
end

local options = {
    ["Blank .nvimrc"] = {"", 1},
    ["Blank .nvim.lua"] = {"", 2},
    ["Generic debug template"] = {[[
function DebugActions(actions)
    local ft = vim.bo.filetype
    while #actions > 0 do table.remove(actions) end
    -- table.insert(actions, 1, { -- Insert at top of list
    table.insert(actions, { -- Insert at bottom of list
        label = "Name",
        terminal = "cmd",
        -- terminal = function() return "cmd" end,
        after = function() end,
        -- after = function(code) end, -- status code of terminal output
        -- keepopen = true, -- keep terminal open even on success; default false
    })
end
]], 2},
    ["C++ template"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, 1, {
        label = "Name",
        terminal = "make debug",
        after = function(code) if code == 0 then launch_cpp_dap("file") end end,
    })
end
-- vim.g.askcppexec = "file" -- Instead of asking which executable to use, use this
]], 2},
    ["Python template"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, 1, {
        label = "Run file",
        after = function()
            require("dap").run({
                name = "Launch Python",
                type = "python",
                request = "launch",
                program = "file.py",
                -- args = {"arg", "here"},
                console = "integratedTerminal",
            })
        end,
    })
end
]], 2},
    ["Latex template"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, 1, {
        label = "Compile & view LaTeX",
        terminal = function() return latex_compile("file.tex") end,
        after = function(code)
            if code == 0 then latex_view("file.tex") end
        end
    })
end
]], 2},
    ["Run on save"] = {[[
local grp = vim.api.nvim_create_augroup("RunOnSave", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
  group = grp,
  pattern = "*/file.txt",
  callback = function(args)
    -- local dir = vim.fn.fnamemodify(args.file, ":h")
    vim.system({ "bash", "-c", "echo saved: " .. args.file }, {}, function(obj)
      vim.schedule(function()
        print(obj.stdout)
      end)
    end)
  end,
})

function EnvReset()
  vim.api.nvim_create_augroup("RunOnSave", { clear = true })
end
]], 2},
    ["Inline terminal"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, {
        label = "Open a non-floating terminal",
        after = function()
            new_terminal("echo 'hello'", {
                -- dir = "vertical", size = 50, keep_open = true,
            })
        end
    })
end
]], 2},
}
local keys = {}
for k, _ in pairs(options) do
  table.insert(keys, k)
end
table.sort(keys)

vim.api.nvim_create_autocmd("DirChanged", {
    pattern = "*",
    callback = function() M.dirch(true) end
})

function M.genfile()
    local cwd = vim.fn.getcwd()
    local fles = { cwd .. "/.nvimrc", cwd .. "/.nvim.lua" }
    for _, f in ipairs(fles) do
        if vim.fn.filereadable(f) == 1 then
            if vim.fn.confirm("Environment file already exists, do you want to replace it?", "&Yes\n&No") == 1 then
                if vim.fn.delete(f) ~= 0 then
                    vim.notify("Error: Failed to delete environment file.")
                    return
                end
            else
                vim.notify("Not deleting.")
                return
            end
        end
    end
    vim.ui.select(keys, {
    prompt = "Select an option:",
    }, function(choice)
        if choice then
            local o = options[choice]
            local fname = fles[o[2]]
            local file = io.open(fname, "w")
            if file then
                file:write(o[1])
                file:close()
                vim.cmd.edit(fname)
            else
                vim.notify("Error: Could not open file for writing.")
            end
        end
    end)
end

return M
