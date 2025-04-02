local M = {}

function M.loadUI()
  require("resession").load(vim.fn.getcwd(), { dir = "dirsession" })
  --vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>th", true, false, true), "m", false)
  --vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "m", false)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>e", true, false, true), "m", false)
end

function M.loadProject(ncwd)
  vim.fn.chdir(ncwd)
  M.loadUI()
end

function M.findProjects()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("Telescope not found!", vim.log.levels.ERROR)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  -- Get a list of projects from project.nvim
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
        M.loadProject(selection.value)
      end)
      return true
    end,
  }):find()
end

M.save_project = function()
    require("resession").save(vim.fn.getcwd(), { dir = "dirsession" })
    print("Project saved!")
end

return M

