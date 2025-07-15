local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

function M.list_dirs(path, depth)
    depth = depth or 4  -- Default depth is 2 if not provided
    local dirs = {}

    if depth <= 0 then
        return dirs
    end

    local entries = vim.fn.readdir(path)
    for _, entry in ipairs(entries) do
	if entry:sub(1, 1) ~= "." and entry ~= "__pycache__" then
	    local full_path = path .. "/" .. entry
	    if vim.fn.isdirectory(full_path) == 1 and entry[1] ~= "." then
	        -- Add the current directory
	        table.insert(dirs, entry .. "/")

	        -- If depth allows, look for subdirectories within this directory
	        if depth > 1 then
                    local subdirs = M.list_dirs(full_path, depth - 1)
                    for _, subdir in ipairs(subdirs) do
		        table.insert(dirs, entry .. "/" .. subdir)
		    end
                end
            end
        end
    end

    return dirs
end

function M.pick_folder_in(path)
    path = vim.fn.expand(path or "~/")

    local folders = M.list_dirs(path)

    pickers.new({}, {
        prompt_title = "Pick a Folder in " .. path,
        finder = finders.new_table {
            results = folders
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(_, map)
            actions.select_default:replace(function(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                vim.cmd("cd " .. vim.fn.fnameescape(path .. "/" .. selection[1]))

		vim.cmd("bd") -- Hide dashboard
		vim.cmd("Neotree show")
            end)
            return true
        end
    }):find()
end

return M
