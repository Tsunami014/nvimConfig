function DebugActions(actions)
    local ft = vim.bo.filetype
    table.insert(actions, {
        label = "Launch Nvim",
        terminal = "$TermSpawn nvim",
    })
end
