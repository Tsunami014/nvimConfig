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

-- Recursively walks a vim.fn.winlayout() dropping non-file buffers
local function serialise_layout(node)
  local kind = node[1]

  if kind == "leaf" then
    local win = node[2]
    local buf = vim.api.nvim_win_get_buf(win)
    if not is_real_file_buf(buf) then
      return nil
    end
    return {
      type = "leaf",
      file = vim.api.nvim_buf_get_name(buf),
      cursor = vim.api.nvim_win_get_cursor(win)[1],
      current = (win == vim.api.nvim_get_current_win()),
      width = vim.api.nvim_win_get_width(win),
      height = vim.api.nvim_win_get_height(win),
    }
  end

  local children = {}
  for _, child in ipairs(node[2]) do
    local s = serialise_layout(child)
    if s then
      table.insert(children, s)
    end
  end

  if #children == 0 then
    return nil
  elseif #children == 1 then
    return children[1]
  end

  return { type = kind, children = children }
end

local function collect_state()
  local files = {}
  local cursors = {}

  local win_for_buf = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if not win_for_buf[buf] then
        win_for_buf[buf] = win
      end
    end
  end

  local function add_buf(buf)
    if is_real_file_buf(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      table.insert(files, name)
      local win = win_for_buf[buf]
      if win then
        cursors[name] = vim.api.nvim_win_get_cursor(win)[1]
      end
    end
  end

  local found = false
  for _, mod in ipairs({ "barbar.state", "bufferline.state" }) do
    local ok, state = pcall(require, mod)
    if ok and type(state.buffers) == "table" then
      found = true
      for _, buf in ipairs(state.buffers) do
        add_buf(buf)
      end
    end
  end
  if not found then
    -- Fallback if barbar's internals aren't reachable
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.fn.buflisted(buf) == 1 and vim.api.nvim_buf_is_loaded(buf) then
        add_buf(buf)
      end
    end
  end

  -- Per-tab window layout (splits included), with non-file windows pruned.
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local tab_layouts = {}
  local active_tab = nil
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    local layout = serialise_layout(vim.fn.winlayout(tabnr))
    if layout then
      table.insert(tab_layouts, layout)
      if tab == current_tabpage then
        active_tab = #tab_layouts
      end
    end
  end

  return { files = files, cursors = cursors, tab_layouts = tab_layouts, active_tab = active_tab }
end

function M.save()
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  if not should_save_session(cwd) then
    return
  end
  local state = collect_state()
  if #state.files == 0 then
    return
  end
  vim.fn.mkdir(session_dir, "p")
  local ok, encoded = pcall(vim.json.encode, state)
  if ok then
    pcall(vim.fn.writefile, { encoded }, session_path(cwd))
  end
end

local function clean_bufs()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_real_file_buf(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- Closes the window (not just the buffer) so plugins like neo-tree/undotree
-- get their normal close autocmds and don't end up in a stale state.
local function close_non_file_windows()
  local wins = vim.api.nvim_list_wins()
  if #wins == 1 then
    local win = wins[1]
    if not is_real_file_buf(vim.api.nvim_win_get_buf(win)) then
      vim.cmd("new")
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if #vim.api.nvim_list_wins() <= 1 then
      break
    end

    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if not is_real_file_buf(buf) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
end

-- Wipes the now-hidden non-file buffers themselves (old neo-tree/undotree/
-- terminal/directory buffers) so they don't pile up across switches.
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

-- Removes leftover unnamed scratch buffers
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

-- Rebuilds one tab's split layout
local function build_tab_layout(layout)
  local focus_win = nil
  local leaves = {}
  local splitright = vim.o.splitright
  local splitbelow = vim.o.splitbelow
  vim.o.splitright = true
  vim.o.splitbelow = true

  local function build(win, node)
    if node.type == "leaf" then
      vim.api.nvim_set_current_win(win)
      if vim.fn.filereadable(node.file) == 1 then
        pcall(vim.cmd, "edit " .. vim.fn.fnameescape(node.file))
        if node.cursor and node.cursor > 0 then
          pcall(vim.api.nvim_win_set_cursor, win, { math.min(node.cursor, vim.api.nvim_buf_line_count(0)), 0 })
        end
      end
      if node.current then
        focus_win = win
      end
      table.insert(leaves, { win = win, width = node.width, height = node.height })
      return
    end

    -- "row" = windows side by side (vertical split), "col" = stacked (horizontal split)
    local cmd = (node.type == "row") and "vsplit" or "split"

    local wins = { win }
    for i = 2, #node.children do
      vim.api.nvim_set_current_win(wins[#wins])
      vim.cmd(cmd)
      table.insert(wins, vim.api.nvim_get_current_win())
    end

    for i, child in ipairs(node.children) do
      build(wins[i], child)
    end
  end

  pcall(build, vim.api.nvim_get_current_win(), layout)

  -- Apply saved sizes once the full split tree for this tab exists
  for _, leaf in ipairs(leaves) do
    if vim.api.nvim_win_is_valid(leaf.win) then
      if leaf.height then
        pcall(vim.api.nvim_win_set_height, leaf.win, leaf.height)
      end
      if leaf.width then
        pcall(vim.api.nvim_win_set_width, leaf.win, leaf.width)
      end
    end
  end
  for _, leaf in ipairs(leaves) do
    if vim.api.nvim_win_is_valid(leaf.win) then
      if leaf.height then
        pcall(vim.api.nvim_win_set_height, leaf.win, leaf.height)
      end
      if leaf.width then
        pcall(vim.api.nvim_win_set_width, leaf.win, leaf.width)
      end
    end
  end

  vim.o.splitright = splitright
  vim.o.splitbelow = splitbelow

  if focus_win and vim.api.nvim_win_is_valid(focus_win) then
    pcall(vim.api.nvim_set_current_win, focus_win)
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
  if not ok2 or type(state) ~= "table" or type(state.files) ~= "table" then
    return false
  end

  local any_readable = false
  for _, f in ipairs(state.files) do
    if vim.fn.filereadable(f) == 1 then
      any_readable = true
      break
    end
  end
  if not any_readable then
    return false
  end

  for _, f in ipairs(state.files) do
    if vim.fn.filereadable(f) == 1 then
      pcall(vim.cmd, "badd " .. vim.fn.fnameescape(f))
    end
  end

  if type(state.tab_layouts) == "table" and #state.tab_layouts > 0 then
    for i, layout in ipairs(state.tab_layouts) do
      if i > 1 then
        vim.cmd("tabnew")
      end
      build_tab_layout(layout)
    end

    if state.active_tab and state.active_tab >= 1 and state.active_tab <= #state.tab_layouts then
      pcall(vim.cmd, "tabnext " .. state.active_tab)
    end
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
      if #vim.api.nvim_list_tabpages() > 1 then
        pcall(vim.cmd, "tabonly!")
      end
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
  "BufEnter",
  "WinNew",
  "WinClosed",
}, {
  callback = function(args)
    if pend or loading then
      return
    end
    if args.event == "BufEnter" and not is_real_file_buf(args.buf) then
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
        vim.cmd("new | only")
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
