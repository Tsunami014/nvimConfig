_G.loadProject = function(ncwd)
  vim.fn.chdir(ncwd)
  _G.initUI()
end

_G.findProjects = function()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("Telescope not found!", vim.log.levels.ERROR)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  -- Get a list of projects from project.nvim (adjust if your function is different)
  local projects = require("project_nvim").get_recent_projects()
  if not projects or vim.tbl_isempty(projects) then
    vim.notify("No projects found!", vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Projects",
    finder = finders.new_table {
      results = projects,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        _G.loadProject(selection.value)
      end)
      return true
    end,
  }):find()
end

local function save_project()
    vim.cmd("SS")
    print("Project saved!")
end

local function load_project()
    _G.findProjects()
end

-- Key mappings for project management
vim.keymap.set("n", "<leader>P", "", { desc = "󰉓 Projects" })
vim.keymap.set("n", "<leader>Ps", save_project, { desc = "󰉖 Save project" })
vim.keymap.set("n", "<leader>Pl", load_project, { desc = " Load project" })

