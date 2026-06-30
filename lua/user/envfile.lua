local M = {}

-- Reset some common directory environment things
local function resetEnv()
    _G.DebugActions = nil
end

function M.dirch(ignorefail)
    local cwd = vim.fn.getcwd()
    local lua_rc = cwd .. "/.nvim.lua"
    local vim_rc = cwd .. "/.nvimrc"

    if vim.fn.filereadable(lua_rc) == 1 then
        dofile(lua_rc)
        vim.notify("Loaded .nvim.lua from " .. lua_rc)
    elseif vim.fn.filereadable(vim_rc) == 1 then
        vim.cmd("source " .. vim_rc)
        vim.notify("Sourced .nvimrc from " .. vim_rc)
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
    --     terminal = function() return "cmd" end,
    --     after = function() launch_cpp_dap("file") end,
    -- })
end
-- vim.g.askcppexec = "file" -- Instead of asking which executable to use, use this
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
