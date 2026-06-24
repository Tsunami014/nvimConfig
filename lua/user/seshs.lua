local M = {}

local session_dir = vim.fn.stdpath("data") .. "/dirsessions"

local home = vim.fs.normalize(vim.fn.expand("~"))
local ignored_exact = {
  home,
  home .. "/Downloads",
  home .. "/Documents",
  "/",
}
local ignored_trees = {
  "/tmp",
  "/var/tmp",
}

local function is_real_file_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return false
  end
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  if vim.fn.isdirectory(name) == 1 then
    return false
  end
  return true
end

local function encode_dir(dir)
  return (dir:gsub("_", "_u"):gsub("/", "_s"))
end
local function decode_name(name)
  return (name:gsub("_s", "/"):gsub("_u", "_"))
end

local function session_path(dir)
  return session_dir .. "/" .. encode_dir(vim.fs.normalize(dir)) .. ".json"
end

local function should_save_session(cwd)
  for _, v in ipairs(ignored_exact) do
    if v == cwd then
      return false
    end
  end
  for _, dir in ipairs(ignored_trees) do
    if cwd == dir or vim.startswith(cwd, dir .. "/") then
      return false
    end
  end
  return true
end

-- Walks every tabpage and records, per tab, which real file buffers were
-- open, which one had focus, and cursor positions. Tabs with no real file
-- buffers (e.g. a tab only showing a sidebar) are skipped entirely.
local function collect_state()
  local tabs = {}
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local active_index = nil

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local files = {}
    local cursors = {}
    local current = nil
    local active_win = vim.api.nvim_tabpage_get_win(tab)

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if is_real_file_buf(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        table.insert(files, name)
        cursors[name] = vim.api.nvim_win_get_cursor(win)[1]
        if win == active_win then
          current = name
        end
      end
    end

    if #files > 0 then
      table.insert(tabs, { files = files, current = current, cursors = cursors })
      if tab == current_tabpage then
        active_index = #tabs
      end
    end
  end

  return { tabs = tabs, active_tab = active_index }
end

function M.save()
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  if not should_save_session(cwd) then
    return
  end
  local state = collect_state()
  if #state.tabs == 0 then
    return
  end
  vim.fn.mkdir(session_dir, "p")
  local ok, encoded = pcall(vim.json.encode, state)
  if ok then
    pcall(vim.fn.writefile, { encoded }, session_path(cwd))
  end
end

-- Deletes every "real file" buffer (their windows survive, showing an
-- empty buffer in their place).
local function clean_bufs()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_real_file_buf(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- Closes windows showing anything that ISN'T a real file buffer: neo-tree,
-- undotree, netrw directory listings, terminals, quickfix, help, etc.
-- Crucially this closes the *window* (not just the buffer), and does so
-- without eventignore active, so the owning plugin's own autocmds (e.g.
-- WinClosed) fire and it can clean up its internal state correctly.
-- Without that, plugins like neo-tree/undotree can end up thinking a
-- stale window is still valid, which is what caused them to take over the
-- whole screen instead of splitting properly the next time they were
-- opened.
local function close_non_file_windows()
  if #vim.api.nvim_list_wins() == 1 then
    local only_buf = vim.api.nvim_win_get_buf(vim.api.nvim_list_wins()[1])
    if not is_real_file_buf(only_buf) then
      -- Make sure there's a normal landing window before we close the
      -- only window in the tab.
      vim.cmd("new")
    end
  end

  local progressed = true
  while progressed do
    progressed = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and #vim.api.nvim_list_wins() > 1 then
        local buf = vim.api.nvim_win_get_buf(win)
        if not is_real_file_buf(buf) then
          pcall(vim.api.nvim_win_close, win, true)
          progressed = true
          break
        end
      end
    end
  end
end

-- After their windows are gone, wipe out the now-hidden non-file buffers
-- themselves (old neo-tree/undotree/terminal/directory buffers) so they
-- don't pile up across directory switches.
local function wipe_non_file_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and not is_real_file_buf(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" or vim.bo[buf].buftype ~= "" then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

-- Removes leftover unnamed/empty scratch buffers that aren't shown in any
-- window (e.g. the placeholder buffer a window had before we :edit'd a
-- real file into it).
local function wipe_stray_scratch_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.api.nvim_buf_get_name(buf) == ""
      and vim.bo[buf].buftype == ""
      and not vim.bo[buf].modified
      and vim.fn.bufwinid(buf) == -1
    then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- Loads one saved tab's files into the current tab/window.
local function open_tab_contents(t)
  for _, f in ipairs(t.files or {}) do
    if vim.fn.filereadable(f) == 1 then
      pcall(vim.cmd, "badd " .. vim.fn.fnameescape(f))
    end
  end

  local target = t.current
  if not target or vim.fn.filereadable(target) ~= 1 then
    target = nil
    for _, f in ipairs(t.files or {}) do
      if vim.fn.filereadable(f) == 1 then
        target = f
        break
      end
    end
  end

  if target then
    pcall(vim.cmd, "edit " .. vim.fn.fnameescape(target))
    local line = t.cursors and t.cursors[target]
    if line and line > 0 then
      pcall(vim.api.nvim_win_set_cursor, 0, { math.min(line, vim.api.nvim_buf_line_count(0)), 0 })
    end
  end
end

function M.load(dir)
  local path = session_path(dir)
  if vim.fn.filereadable(path) == 0 then
    return false
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then
    return false
  end
  local ok2, state = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok2 or type(state) ~= "table" then
    return false
  end

  -- Backward compatibility with sessions saved before tab support.
  if not state.tabs and state.files then
    state = { tabs = { { files = state.files, current = state.current, cursors = state.cursors } } }
  end

  if not state.tabs or #state.tabs == 0 then
    return false
  end

  local any_readable = false
  for _, t in ipairs(state.tabs) do
    for _, f in ipairs(t.files or {}) do
      if vim.fn.filereadable(f) == 1 then
        any_readable = true
        break
      end
    end
    if any_readable then
      break
    end
  end
  if not any_readable then
    return false
  end

  for i, t in ipairs(state.tabs) do
    if i > 1 then
      vim.cmd("tabnew")
    end
    open_tab_contents(t)
  end

  if state.active_tab and state.active_tab >= 1 and state.active_tab <= #state.tabs then
    pcall(vim.cmd, "tabnext " .. state.active_tab)
  end

  wipe_stray_scratch_buffers()
  return true
end

local pend = false
local loading = false

vim.api.nvim_create_user_command(
  'LoadUI',
  function(opts)
    local ncwd = opts.args
    loading = true
    if ncwd ~= "" then
      vim.cmd("cd " .. vim.fn.fnameescape(ncwd))
      pcall(vim.cmd, "tabonly!")
      close_non_file_windows()
      clean_bufs()
      wipe_non_file_buffers()
      local loaded = M.load(vim.fn.getcwd())
      if loaded then
        loading = false
      else
        vim.defer_fn(function()
          vim.cmd("Neotree show")
          vim.cmd("wincmd w")
          wipe_stray_scratch_buffers()
          loading = false
        end, 30)
      end
    else
      vim.cmd("Neotree show")
      vim.cmd("wincmd w")
      loading = false
    end
  end, { nargs = '?' }
)

vim.api.nvim_create_autocmd({
  "BufAdd",
  "BufNewFile",
  "BufDelete",
  "BufWipeout",
}, {
  callback = function()
    if pend or loading then
      return
    end
    pend = true
    vim.defer_fn(function()
      if vim.api.nvim_get_mode().mode == "n" then
        M.save()
      end
      pend = false
    end, 500)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc(-1) > 0 then
      local dir = vim.fn.argv(0)
      if vim.fn.isdirectory(dir) == 1 then
        vim.cmd("enew")
        vim.defer_fn(function()
          vim.cmd("LoadUI " .. vim.fn.fnameescape(dir))
        end, 10)
      end
    end
  end,
  nested = true,
})

local function all_sessions()
  local items = {}
  for _, fname in ipairs(vim.fn.glob(session_dir .. "/*.json", false, true)) do
    local base = vim.fn.fnamemodify(fname, ":t:r")
    table.insert(items, decode_name(base))
  end
  table.sort(items, function(a, b)
    return vim.fn.getftime(session_path(a)) > vim.fn.getftime(session_path(b))
  end)
  return items
end

function M.pick()
  local pick = require("mini.pick")
  pick.start({
    source = {
      name = "Sessions",
      items = all_sessions(),
      choose = function(item)
        vim.schedule(function()
          vim.cmd("LoadUI " .. vim.fn.fnameescape(item))
        end)
      end,
      preview = function(buf_id, item)
        local mtime = vim.fn.getftime(session_path(item))
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, {
          item,
          "",
          mtime > 0 and ("Last saved: " .. vim.fn.strftime("%Y-%m-%d %H:%M:%S", mtime)) or "No save time available",
        })
      end,
    },
    mappings = {
      delete_session = {
        char = "<C-d>",
        func = function()
          local cur = pick.get_picker_matches().current
          if not cur then
            return
          end
          pcall(vim.fn.delete, session_path(cur))
          vim.notify("Deleted session: " .. cur)
          pick.set_picker_items(all_sessions())
        end,
      },
    },
  })
end

return M
