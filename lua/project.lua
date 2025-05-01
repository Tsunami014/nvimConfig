local M = {}

local project_file = vim.fn.stdpath("config") .. "/projects.json"
M.projects = {}

local function loadProjects()
  local f = io.open(project_file, "r")
  if not f then return end
  local content = f:read("*a")
  f:close()
  if content and content ~= "" then
    local parsed = vim.fn.json_decode(content)
    if parsed and parsed.projects and type(parsed.projects) == "table" then
      M.projects = parsed.projects
    end
  end
end

local function saveProjects()
  local f = io.open(project_file, "w+")
  if not f then
    vim.notify("Failed to open project file for writing!", vim.log.levels.ERROR)
    return
  end
  local tbl = { projects = M.projects }
  f:write(vim.fn.json_encode(tbl))
  f:close()
end

local function touchProject(cwd)
  for i, path in ipairs(M.projects) do
    if path == cwd then table.remove(M.projects, i) break end
  end
  table.insert(M.projects, 1, cwd)
  local max_projects = 20
  if #M.projects > max_projects then
    for i = max_projects + 1, #M.projects do
      M.projects[i] = nil
    end
  end
  saveProjects()
end

loadProjects()

function M.loadUI()
  local cwd = vim.fn.getcwd()
  require("resession").load(cwd, { dir = "dirsession" })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>e", true, false, true), "m", false)
end

function M.loadProject(ncwd)
  vim.fn.chdir(ncwd)
  M.loadUI()
  touchProject(ncwd)
end

function M.findProjects()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("Telescope not found!", vim.log.levels.ERROR)
    return
  end

  if vim.tbl_isempty(M.projects) then
    vim.notify("No projects found!", vim.log.levels.WARN)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  pickers.new({}, {
    prompt_title = "Projects",
    finder = finders.new_table { results = M.projects },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then M.loadProject(selection[1]) end
      end)

      map("i", "<C-d>", function()
        local sel = action_state.get_selected_entry()
        if sel then
          for i, path in ipairs(M.projects) do
            if path == sel[1] then table.remove(M.projects, i); break end
          end
          saveProjects()
          vim.notify("Removed project: " .. sel[1], vim.log.levels.INFO)
          actions.close(prompt_bufnr)
        end
      end)
      return true
    end,
  }):find()
end

function M.save_project(silent)
  local cwd = vim.fn.getcwd()

  local _orig_notify = vim.notify
  vim.notify = function() end
  require("resession").save(cwd, { dir = "dirsession" })
  vim.notify = _orig_notify

  touchProject(cwd)
  saveProjects()
  if (not silent) or silent == nil then
    vim.notify("Saved session for: " .. cwd, vim.log.levels.INFO)
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave" }, {
  pattern = "*",
  callback = function()
    local cwd = vim.fn.getcwd()
    if vim.tbl_contains(M.projects, cwd) then
      M.save_project(true)
    end
  end,
})

return M
