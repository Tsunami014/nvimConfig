local p = require("profile")
if p.OPTS.Notes then
  return {}
end

local dir  = vim.fn.expand("~/.local/state/theme/current")
local file = dir .. "/palette.json"

local fallback = {
  variant = 1,
  bg = "#1a1b26", bg2 = "#222436", bg3 = "#2f334d",
  fg = "#c0caf5", muted1 = "#9aa5ce", muted2 = "#545c7e",
  red = "#f7768e", orange = "#ff9e64", yellow = "#e0af68", green = "#9ece6a",
  cyan = "#7dcfff", blue = "#7aa2f7", purple = "#bb9af7",
  primary = "#a0ade9", secondary = "#99a0be", tertiary = "#d19ec5",
}

local function load_palette()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
  end)
  if ok and type(data) == "table" then
    return vim.tbl_extend("force", fallback, data)
  end
  return fallback
end

-- Personal highlight tweaks
local function overrides(d)
  local set = vim.api.nvim_set_hl
  -- primary / secondary show the wallpaper's identity in the UI chrome
  -- set(0, "CursorLineNr", { fg = d.primary, bold = true })
  -- set(0, "WinSeparator", { fg = d.secondary })
  -- set(0, "FloatBorder",  { fg = d.secondary })
  -- e.g. set(0, "Comment", { fg = d.muted2, italic = true })
end

local function apply()
  local d = load_palette()
  require("mini.base16").setup({ palette = {
    base00 = d.bg,     base01 = d.bg2,    base02 = d.bg3,    base03 = d.muted2,
    base04 = d.muted1, base05 = d.fg,     base06 = d.fg,     base07 = d.fg,
    base08 = d.red,    base09 = d.orange, base0A = d.yellow, base0B = d.green,
    base0C = d.cyan,   base0D = d.blue,   base0E = d.purple, base0F = d.purple,
  }})
  vim.g.colors_name = "wallpaper"
  overrides(d)

  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "wallpaper", modeline = false })
  vim.cmd("redrawstatus!")
end

apply()

if p.OPTS.Full then
  -- Live reload
  vim.fn.mkdir(dir, "p")
  local timer   = vim.uv.new_timer()
  local watcher = vim.uv.new_fs_event()
  watcher:start(dir, {}, function(_, name)
    if name ~= "palette.json" then return end
    timer:stop()
    timer:start(50, 0, vim.schedule_wrap(function()
      if vim.g.colors_name == "wallpaper" then apply() end
    end))
  end)
end

p.apply_if_active("wallpaper")
