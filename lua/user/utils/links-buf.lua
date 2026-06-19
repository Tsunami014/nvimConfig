local M = {}

local normalise = require("user.utils.links").normalise

local state = {
  win = nil,
  buf = nil,
  main_win = nil,
  augroup = nil,
  ns = vim.api.nvim_create_namespace("wiki_links_sidebar"),
  targets = {},
}

--- Read a file's contents as a single string, or nil if it can't be read.
local function read_text(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return nil
  end
  return table.concat(lines, "\n")
end

--- Extract the unique, sorted set of [[wiki link]] targets in `text`.
local function collect_links(text)
  local seen, out = {}, {}
  for link in text:gmatch("%[%[([^%]]+)%]%]") do
    local name = normalise(link)
    if not seen[name] then
      seen[name] = true
      table.insert(out, name)
    end
  end
  table.sort(out)
  return out
end

--- Every *.md file in `root` (other than `current_name`) that links to it.
local function scan_inbound(root, current_name)
  local inbound = {}

  for _, file in ipairs(vim.fn.globpath(root, "*.md", false, true)) do
    if vim.fs.basename(file) ~= current_name then
      local text = read_text(file)
      if text then
        for link in text:gmatch("%[%[([^%]]+)%]%]") do
          if normalise(link) == current_name then
            table.insert(inbound, file)
            break
          end
        end
      end
    end
  end

  table.sort(inbound)
  return inbound
end

local function push_section(rows, title, paths, noun)
  table.insert(rows, { text = title, group = "markdownH1" })
  table.insert(rows, { text = ("─"):rep(28), group = "markdownHeadingRule" })

  if #paths == 0 then
    table.insert(rows, { text = "  (none)", group = "markdownCode" })
    return
  end

  table.insert(rows, { text = ("  %d %s(s)"):format(#paths, noun), group = "markdownCode" })
  for _, path in ipairs(paths) do
    table.insert(rows, {
      text = "  " .. vim.fs.basename(path),
      group = "markdownUrlTitle",
      target = path,
    })
  end
end

--- The window we should open link targets in: the last-focused non-sidebar window.
local function find_main_win()
  if state.main_win and vim.api.nvim_win_is_valid(state.main_win) then
    return state.main_win
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= state.win then
      return win
    end
  end

  return nil
end

--- The window whose buffer should be scanned for links.
local function find_source_win()
  local win = find_main_win()
  if win and win ~= state.win then
    return win
  end

  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= state.win then
      return w
    end
  end

  return nil
end

local function open_target(target)
  local win = find_main_win()
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  vim.api.nvim_set_current_win(win)
  vim.cmd("edit " .. vim.fn.fnameescape(target))
  state.main_win = vim.api.nvim_get_current_win()
end

local function new_sidebar()
  local prev_win = vim.api.nvim_get_current_win()
  state.main_win = prev_win

  local buf = vim.api.nvim_create_buf(false, true)

  vim.cmd("botright vnew")
  local temp_buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_win_set_buf(0, buf)
  pcall(vim.api.nvim_buf_delete, temp_buf, { force = true })

  state.win = vim.api.nvim_get_current_win()
  state.buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].filetype = "wikilinks"

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.wrap = false
  vim.wo.foldcolumn = "0"
  vim.wo.cursorline = true
  vim.wo.winfixwidth = true
  vim.api.nvim_win_set_width(state.win, 40)

  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local target = state.targets[lnum]
    if target then
      open_target(target)
    end
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
      cleanup()
    end
  end, { buffer = buf, silent = true })

  -- Focus the sidebar once when opening it, but do not keep forcing focus back later.
  vim.api.nvim_set_current_win(state.win)
end

local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end

  local source_win = find_source_win()
  if not source_win then
    return
  end

  local src = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(source_win))
  if src == "" then
    return
  end

  src = vim.fn.fnamemodify(src, ":p")

  local root = vim.fs.dirname(src)
  local current_name = vim.fs.basename(src)

  local outbound = {}
  for _, name in ipairs(collect_links(read_text(src) or "")) do
    table.insert(outbound, vim.fs.joinpath(root, name))
  end

  local inbound = scan_inbound(root, current_name)

  local rows = {}
  push_section(rows, "Inbound", inbound, "file")
  table.insert(rows, { text = "" })
  push_section(rows, "Outbound", outbound, "link")

  local lines = {}
  state.targets = {}

  for i, row in ipairs(rows) do
    lines[i] = row.text
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)

  for i, row in ipairs(rows) do
    if row.group then
      vim.api.nvim_buf_add_highlight(
        state.buf,
        state.ns,
        row.group,
        i - 1,
        row.target and 2 or 0,
        -1
      )
    end
    if row.target then
      state.targets[i] = row.target
    end
  end

  vim.bo[state.buf].modifiable = false
end

local function cleanup()
  if state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
  state.targets = {}
  state.win = nil
  state.buf = nil
  state.main_win = nil
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    cleanup()
    return
  end

  new_sidebar()
  render()

  state.augroup = vim.api.nvim_create_augroup("WikiLinksSidebar", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = state.augroup,
    callback = function(args)
      if args.buf == state.buf then
        return
      end

      state.main_win = vim.api.nvim_get_current_win()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        render()
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    callback = function()
      if state.win and not vim.api.nvim_win_is_valid(state.win) then
        cleanup()
      end
    end,
  })
end

return M
