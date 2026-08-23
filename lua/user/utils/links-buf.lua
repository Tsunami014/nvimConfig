local M = {}

local normalise = require("user.utils.links-shared").normalise

local cleanup
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

local function link_file_part(link)
  local hash = link:find("#", 1, true)
  if hash then
    return link:sub(1, hash - 1)
  end
  return link
end

--- Extract the unique, sorted set of [[wiki link]] targets in `text`.
local function collect_links(text)
  local seen, out = {}, {}
  for link in text:gmatch("%[%[([^%]]+)%]%]") do
    local file_part = link_file_part(link)
    if file_part ~= "" then
      local name = normalise(file_part)
      if not seen[name] then
        seen[name] = true
        table.insert(out, name)
      end
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
          local file_part = link_file_part(link)
          if file_part ~= "" and normalise(file_part) == current_name then
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

--- A setext underline is a line that, once stripped of surrounding
--- whitespace, consists of one or more of only "-" or only "=" characters.
local function setext_underline(line)
  local stripped = line:match("^%s*(.-)%s*$")
  if stripped == "" then
    return nil
  end
  if stripped:match("^%-+$") then
    return "-"
  end
  if stripped:match("^=+$") then
    return "="
  end
  return nil
end

--- Extracts every heading in `text`
local function collect_headings(text)
  local lines = vim.split(text, "\n", { plain = true })
  local headings = {}
  local lnum = 1

  while lnum <= #lines do
    local line = lines[lnum]
    local hashes, atx_text = line:match("^(#+)%s+(.-)%s*$")

    if atx_text then
      table.insert(headings, { level = #hashes, text = atx_text })
      lnum = lnum + 1
    else
      local stripped = line:match("^%s*(.-)%s*$")
      if stripped ~= "" and not setext_underline(line) then
        local j = lnum + 1
        local text_lines = { stripped }
        local matched = false
        while j <= #lines do
          local under = setext_underline(lines[j])
          if under then
            local level = (under == "=") and 1 or 2
            table.insert(headings, { level = level, text = table.concat(text_lines, " ") })
            matched = true
            break
          end
          local next_stripped = lines[j]:match("^%s*(.-)%s*$")
          if next_stripped == "" then
            break
          end
          table.insert(text_lines, next_stripped)
          j = j + 1
        end
        if not matched then
          lnum = lnum + 1
        else
          lnum = j + 1
        end
      else
        lnum = lnum + 1
      end
    end
  end

  return headings
end

local function push_toc(rows, text)
  local headings = collect_headings(text)

  table.insert(rows, { text = "Contents", group = "markdownH1" })
  table.insert(rows, { text = ("─"):rep(28), group = "markdownHeadingRule" })

  if #headings == 0 then
    table.insert(rows, { text = "  (none)", group = "markdownCode" })
    return
  end

  -- Indent relative to the shallowest heading level present, so a document
  -- that starts at "##" isn't needlessly indented.
  local min_level = math.huge
  for _, h in ipairs(headings) do
    min_level = math.min(min_level, h.level)
  end

  for _, h in ipairs(headings) do
    local indent = ("  "):rep(h.level - min_level)
    table.insert(rows, {
      text = "  " .. indent .. h.text,
      group = "markdownUrlTitle",
      heading = h,
    })
  end
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

--- Jumps the cursor in `win`'s buffer to the given heading, matching how
--- index_toggle's goto_heading locates ATX/setext headings by exact text.
local function goto_heading_in_win(win, heading)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local target_text = heading.text:lower()
  local lnum = 1

  while lnum <= #lines do
    local line = lines[lnum]
    local atx_text = line:match("^#+%s+(.-)%s*$")

    if atx_text then
      if atx_text:lower() == target_text then
        vim.api.nvim_set_current_win(win)
        vim.api.nvim_win_set_cursor(win, { lnum, 0 })
        vim.cmd("normal! zz")
        return
      end
      lnum = lnum + 1
    else
      local stripped = line:match("^%s*(.-)%s*$")
      if stripped ~= "" and not setext_underline(line) then
        local j = lnum + 1
        local text_lines = { stripped }
        local matched_line = nil
        while j <= #lines do
          if setext_underline(lines[j]) then
            matched_line = lnum
            break
          end
          local next_stripped = lines[j]:match("^%s*(.-)%s*$")
          if next_stripped == "" then
            break
          end
          table.insert(text_lines, next_stripped)
          j = j + 1
        end
        if matched_line and table.concat(text_lines, " "):lower() == target_text then
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_win_set_cursor(win, { matched_line, 0 })
          vim.cmd("normal! zz")
          return
        end
        lnum = matched_line and (j + 1) or (lnum + 1)
      else
        lnum = lnum + 1
      end
    end
  end
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
    if not target then
      return
    end
    if target.kind == "file" then
      open_target(target.path)
    elseif target.kind == "heading" then
      goto_heading_in_win(find_main_win(), target.heading)
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
  local src_text = read_text(src) or ""

  local outbound = {}
  for _, name in ipairs(collect_links(src_text)) do
    table.insert(outbound, vim.fs.joinpath(root, name))
  end

  local inbound = scan_inbound(root, current_name)

  local rows = {}
  push_toc(rows, src_text)
  table.insert(rows, { text = "" })
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
        (row.target or row.heading) and 2 or 0,
        -1
      )
    end
    if row.target then
      state.targets[i] = { kind = "file", path = row.target }
    elseif row.heading then
      state.targets[i] = { kind = "heading", heading = row.heading }
    end
  end

  vim.bo[state.buf].modifiable = false
end

cleanup = function()
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
