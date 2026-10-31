local M = {}

local function t(k) return vim.api.nvim_replace_termcodes(k, true, false, true) end

local entries = {
  { group = "Move between windows", keys = { "h", "<Left>" },  cmd = "wincmd h", desc = "Window left" },
  { group = "Move between windows", keys = { "j", "<Down>" },  cmd = "wincmd j", desc = "Window below" },
  { group = "Move between windows", keys = { "k", "<Up>" },    cmd = "wincmd k", desc = "Window above" },
  { group = "Move between windows", keys = { "l", "<Right>" }, cmd = "wincmd l", desc = "Window right" },

  { group = "Resize", keys = { "H", "<S-Left>" },  cmd = "vertical resize -3", desc = "Narrower" },
  { group = "Resize", keys = { "L", "<S-Right>" }, cmd = "vertical resize +3", desc = "Wider" },
  { group = "Resize", keys = { "K", "<S-Up>" },    cmd = "resize +2",          desc = "Taller" },
  { group = "Resize", keys = { "J", "<S-Down>" },  cmd = "resize -2",          desc = "Shorter" },
  { group = "Resize", keys = { "=" },              cmd = "wincmd =",           desc = "Equalize all windows" },

  { group = "Manage windows", keys = { "s" }, cmd = "split",  desc = "Horizontal split" },
  { group = "Manage windows", keys = { "v" }, cmd = "vsplit", desc = "Vertical split" },
  { group = "Manage windows", keys = { "x" }, cmd = "close",  desc = "Close window" },
  { group = "Manage windows", keys = { "o" }, cmd = "only",   desc = "Close all other windows" },
}

local help_keys = { "?" }
local exit_keys = { ",", "<Esc>", "q", "<CR>" }

local actions, exits, helps = {}, {}, {}
for _, e in ipairs(entries) do
  for _, k in ipairs(e.keys) do actions[t(k)] = e.cmd end
end
for _, k in ipairs(exit_keys) do exits[t(k)] = true end
for _, k in ipairs(help_keys) do helps[t(k)] = true end

local STATUS = "-- WINDOW --   ?  Help   , / Esc / q  Exit"

local function is_leader(key)
  local l = vim.g.mapleader
  return l and key == t(l)
end

local function build_help_lines()
  local lines = {}
  local last_group
  for _, e in ipairs(entries) do
    if e.group ~= last_group then
      if last_group then table.insert(lines, "") end
      table.insert(lines, " " .. e.group)
      last_group = e.group
    end
    table.insert(lines, string.format("   %-22s %s", table.concat(e.keys, " / "), e.desc))
  end
  vim.list_extend(lines, {
    "",
    " Other",
    string.format("   %-22s %s", ":", "Run a command and exit"),
    string.format("   %-22s %s", "<leader>", "Run a <leader> mapping"),
    string.format("   %-22s %s", table.concat(help_keys, " / "), "Show this help"),
    string.format("   %-22s %s", table.concat(exit_keys, " / "), "Exit window mode"),
    "",
    " All other keys are ignored in this mode.",
    " Press any key to close ",
  })
  return lines
end

local function show_help()
  local lines = build_help_lines()
  local width = 0
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l)) end
  width = width + 2

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = #lines,
    row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Window mode help ",
    title_pos = "center",
    focusable = false,
    zindex = 250,
  })

  vim.cmd.redraw()
  pcall(vim.fn.getcharstr)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local running = false

local function resume_when_idle()
  local id
  id = vim.api.nvim_create_autocmd("SafeState", {
    callback = function()
      -- "m" = halfway through a mapping (e.g. leader waiting for the next key),
      -- "o" = operator pending. Not idle yet, so keep waiting.
      if vim.fn.state("mo") ~= "" then return end
      pcall(vim.api.nvim_del_autocmd, id)
      vim.schedule(M.activate)
    end,
  })
end

function M.activate()
  if running then return end
  running = true

  while true do
    vim.api.nvim_echo({ { STATUS, "ModeMsg" } }, false, {})
    vim.cmd.redraw()

    local ok, key = pcall(vim.fn.getcharstr)
    if not ok or exits[key] then break end

    if helps[key] then
      show_help()
    elseif actions[key] then
      pcall(vim.cmd, actions[key])
    elseif key == t(':') then
      vim.api.nvim_feedkeys(key, "mt", false)
      running = false
      return
    elseif is_leader(key) then
      vim.api.nvim_feedkeys(key, "mt", false)
      running = false
      resume_when_idle()
      return
    end
  end

  running = false
  vim.api.nvim_echo({ { "" } }, false, {})
  vim.cmd.redraw()
end

return M
