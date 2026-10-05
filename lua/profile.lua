local M = {}

M.OptNams = { "Minimal", "Full", "Full2", "Notes" }

M.PopupOrder = {
    "Full",
    "Full2",
    "Notes",
    "Minimal",
}

M.colourschemes = {
    Minimal = "default",
    Full    = "tokyonight-moon",
    Full2   = "catppuccin-frappe",
    Notes   = "everforest",
}

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

local function profile_index(profile_name)
    for i, name in ipairs(M.OptNams) do
        if name == profile_name then
            return i
        end
    end
    return nil
end

local function get_env_profile()
    local profile = vim.env.NVIM_PROFILE
    if not profile or profile == "" then
        return nil
    end
    if profile == "choose" then
        local list = { "Select profile:" }
        for i, item in ipairs(M.PopupOrder) do
            table.insert(list, string.format("%d. %s", i, item))
        end
        local choice = vim.fn.inputlist(list)
        if choice < 1 or choice > #M.PopupOrder then
            return nil
        end
        return profile_index(M.PopupOrder[choice])
    else
        return profile_index(profile)
    end
end


local function load_profile()
    local cli_profile = get_env_profile()
    local f = io.open(profile_file, "r")
    if f then
        local content = f:read("*a")
        f:close()

        local m1, m2 = content:match("^%s*(%d+):(%d+)%s*$")
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
    end
    vim.notify("Error saving profile index!", vim.log.levels.ERROR)
    return false
end

current, newdefault = load_profile()
next_prof = newdefault
update_opts()
save_profile()


function M.set_profile(profile_name, once)
    local index = profile_index(profile_name)
    if not index then
        vim.notify("Error: Profile name not found!", vim.log.levels.ERROR)
        return
    end

    next_prof = index
    if not once then
        newdefault = index
    end
    if save_profile() then
        vim.notify("Set " .. (
            once and "next" or "default"
        ) .. " profile to " .. profile_name)
        M.apply_colourscheme(profile_name)
    end
end

function M.choose_profile(once)
    vim.ui.select(M.PopupOrder, {
        prompt = "Select " .. (once and "next launch" or "default") .. " profile:"
    }, function(choice)
        if choice then
            M.set_profile(choice, once)
        end
    end)
end

function M.apply_colourscheme(profile_name)
    local scheme = M.colourschemes[profile_name]
    if not scheme then return false end
    return (pcall(vim.cmd.colorscheme, scheme))
end

function M.available_colourschemes()
    local installed = {}
    for _, c in ipairs(vim.fn.getcompletion("", "color")) do installed[c] = true end
    local seen, out = {}, {}
    for _, name in ipairs(M.OptNams) do
        local s = M.colourschemes[name]
        if s and installed[s] and not seen[s] then
            seen[s] = true
            table.insert(out, s)
        end
    end
    return out
end

return M
