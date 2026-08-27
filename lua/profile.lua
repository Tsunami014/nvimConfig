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
    local f = io.open(profile_file, "r")
    if f then
        local content = f:read("*a")
        f:close()

        local m1, m2 = content:match("^(%d+):(%d+)$")
        local now, def = tonumber(m1), tonumber(m2)
        if cli_profile then
            now = cli_profile
        elseif not now or now < 1 or now > #M.OptNams then
            now = M.DEFAULT
        end
        if not def or def < 1 or def > #M.OptNams then
            def = M.DEFAULT
        end
        return now, def
    end
    if cli_profile then
        return cli_profile, M.DEFAULT
    end
    return M.DEFAULT, M.DEFAULT
end

local newdefault
local next_prof
local function save_profile()
    local f = io.open(profile_file, "w")
    if f then
        f:write(tostring(next_prof) .. ":" .. tostring(newdefault))
        f:close()
        return true
    else
        vim.notify("Error saving profile index!", vim.log.levels.ERROR)
        return false
    end
end

current, newdefault = load_profile()
next_prof = newdefault
update_opts()
save_profile()

function M.set_profile(profile_name, once)
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

    next_prof = index
    if not once then
        newdefault = index
    end
    if save_profile() then
        vim.notify("Profile will be " .. profile_name .. (once and " for the next launch only" or " by default from the next launch"))
    end
end

function M.choose_profile(once)
    vim.ui.select(M.OptNams, { prompt = "Select " .. (once and "next launch" or "default") .. " profile:" }, function(choice)
        if choice then
            M.set_profile(choice, once)
        end
    end)
end

return M
