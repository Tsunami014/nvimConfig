local M = {}

local project_file = vim.fn.stdpath("config") .. "/projects.json"
M.projects = {}

local function loadProjects()
  local f = io.open(project_file, "r")
  if f then
    local content = f:read("*a")
    if content and content ~= "" then
      local parsed = vim.fn.json_decode(content)
      if parsed and parsed.projects then
        M.projects = parsed.projects
      end
    end
    f:close()
  end
end

local function saveProjects()
  local f = io.open(project_file, "w+")
  if f then
    local table = { projects = M.projects }
    f:write(vim.fn.json_encode(table))
    f:close()
  else
    vim.notify("Failed to open project file for writing!", vim.log.levels.ERROR)
  end
end

-- Load projects when the module is loaded
loadProjects()

function M.loadUI()
  require("resession").load(vim.fn.getcwd(), { dir = "dirsession" })
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

  if not M.projects or vim.tbl_isempty(M.projects) then
    vim.notify("No projects found!", vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Projects",
    finder = finders.new_table {
      results = vim.tbl_keys(M.projects),
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          M.loadProject(selection[1])
        end
      end)
      return true
    end,
  }):find()
end

M.save_project = function()
  local cwd = vim.fn.getcwd()
  require("resession").save(cwd, { dir = "dirsession" })
  M.projects[cwd] = true
  saveProjects()
  print("Project saved!")
end

vim.api.nvim_create_autocmd({"BufWritePost"}, {
  pattern = "*",
  callback = M.save_project
})

return M