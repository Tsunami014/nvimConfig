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
    ["Override debug options"] = {[[
function DebugActions(actions)
    local ft = vim.bo.filetype
    -- while #actions > 0 do table.remove(actions) end
    -- table.insert(actions, {
    --     label = "Name",
    --     terminal = "cmd", -- Or use a function
    --     after = function(code) if code == 0 then launch_cpp_dap("file") end end,
    --     keepopen = true, -- keep terminal open even on success; default false
    -- })
    -- table.insert(actions, {
    --     label = "Name2",
    --     after = function()
    --         dap.run({
    --             name = "Launch Python",
    --             type = "python",
    --             request = "launch",
    --             program = "file.py",
    --             console = "integratedTerminal",
    --         })
    --     end,
    -- })
end
-- vim.g.askcppexec = "file" -- Instead of asking which executable to use, use this
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
            vim.notify("Environment file already exists!")
            return
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
