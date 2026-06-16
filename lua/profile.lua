local M = {}

M.OptNams = { "Minimal", "Full", "Notes" }
M.OPTS = {}
M.DEFAULT = 1

local current
function M.current_name()
  return M.OptNams[current]
end
local function update_opts()
    for i, profile in ipairs(M.OptNams) do
        M.OPTS[profile] = (i == current)
    end
end

local profile_file = vim.fn.stdpath("config") .. "/profile.txt"

local function get_env_profile()
  local profile = vim.env.NVIM_PROFILE
  if not profile or profile == "" then
    return nil
  end
  for i, profile_name in ipairs(M.OptNams) do
    if profile_name == profile then
      return i
    end
  end
end

local function load_profile()
  local cli_profile = get_env_profile()
  if cli_profile then
    return cli_profile
  end
  local f = io.open(profile_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    
    local index = tonumber(content)
    
    if index and index >= 1 and index <= #M.OptNams then
      return index
    end
    return M.DEFAULT
  end
  
  return M.DEFAULT
end

local function save_profile(index)
  local f = io.open(profile_file, "w")
  if f then
    f:write(tostring(index))
    f:close()
  else
    vim.notify("Error saving profile index!", vim.log.levels.ERROR)
  end
end

local function get_profile_name(index)
    return M.OptNams[index]
end

current = load_profile()
update_opts()

function M.set_profile(profile_name)
    local index = 0
    for i, name in ipairs(M.OptNams) do
        if name == profile_name then
            index = i
            break
        end
    end

    if index == 0 then
        -- This should not happen if called from choose_profile
        vim.notify("Error: Profile name not found!", vim.log.levels.ERROR)
        return
    end

    save_profile(index)
    vim.notify("Profile will be " .. profile_name .. " on next open of nvim!")
end

function M.choose_profile()
  vim.ui.select(M.OptNams, { prompt = "Select profile:" }, function(choice)
    if choice then
      M.set_profile(choice)
    end
  end)
end

return M
