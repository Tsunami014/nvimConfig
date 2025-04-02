local M = {}

M.OPTS = { "default", "Linux", "Windows" }
M.DEFAULT = 0

local profile_file = vim.fn.stdpath("config") .. "/profile.json"

local function load_profile()
  local f = io.open(profile_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and data.profile then
      return data.profile
    end
  end
  return M.OPTS[M.DEFAULT]
end

local function save_profile(profile)
  local f = io.open(profile_file, "w")
  if f then
    local data = { profile = profile }
    f:write(vim.fn.json_encode(data))
    f:close()
  else
    vim.notify("Error saving profile!", vim.log.levels.ERROR)
  end
end

M.current = load_profile()

function M.set_profile(profile)
  M.current = profile
  save_profile(profile)
  vim.notify("Profile set to " .. profile)

  require("project").save_project()

  local cwd = vim.fn.getcwd()
  local cmd = vim.v.progpath .. [[ -c 'lua require("project").loadProject("]] .. cwd .. '")\''
  vim.fn.jobstart("kitty " .. cmd, { detach = true })

  vim.cmd("qa!")
end

function M.choose_profile()
  vim.ui.select(M.OPTS, { prompt = "Select profile:" }, function(choice)
    if choice then
      M.set_profile(choice)
    end
  end)
end

return M

