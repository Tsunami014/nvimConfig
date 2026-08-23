local M = {}

local INDEX = "+index.md"

-- Extensions safe to auto-create when a link points at a non-existent file
local AUTO_CREATE = { md = true, txt = true, tex = true }

-- Extensions that should be opened inside Neovim
local INTERNAL = {
  txt = true, md = true, rst = true, tex = true,
  lua = true, py = true, js = true, ts = true, html = true, css = true,
  json = true, yaml = true, yml = true, toml = true, xml = true,
  csv = true, conf = true, ini = true, c = true, cpp = true, h = true,
  hpp = true, sh = true, bash = true,
}

local state = {
  win = nil,
  buf = nil,
}

local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
end

local function floating_opts()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.8)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. INDEX .. " ",
    title_pos = "center",
  }
end

local function open_real_file(path)
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false

  local win = vim.api.nvim_open_win(buf, true, floating_opts())
  state.win = win
  state.buf = buf
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close_window()
    return
  end

  local path = vim.fn.getcwd() .. "/" .. INDEX
  local uv = vim.uv or vim.loop

  if uv.fs_stat(path) ~= nil then
    open_real_file(path)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, floating_opts())
  state.win = win

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "",
    "  " .. INDEX .. " was not found in:",
    "    " .. vim.fn.getcwd(),
    "",
    "  Create it?",
    "",
    "    [y / <CR>] Yes      [n / <Esc>] No",
    "",
  })
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "index-toggle-prompt"
  state.buf = buf

  local function confirm()
    local fd = uv.fs_open(path, "w", 420)
    if not fd then
      vim.notify("index_toggle: failed to create " .. path, vim.log.levels.ERROR)
      return
    end
    uv.fs_close(fd)
    open_real_file(path)
  end

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "y", confirm, opts)
  vim.keymap.set("n", "<CR>", confirm, opts)
  vim.keymap.set("n", "n", close_window, opts)
  vim.keymap.set("n", "q", close_window, opts)
  vim.keymap.set("n", "<Esc>", close_window, opts)
end

local function slugify(text)
  return text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

local function split_anchor(target)
  local hash = target:find("#", 1, true)
  if not hash then
    return target, nil
  end
  return target:sub(1, hash - 1), target:sub(hash + 1)
end

-- A setext underline is a line that, once stripped of surrounding
-- whitespace, consists of one or more of only "-" or only "=" characters.
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

-- Collects heading text found at each line number
local function collect_headings(lines)
  local headings = {}
  local lnum = 1

  while lnum <= #lines do
    local line = lines[lnum]
    local atx_text = line:match("^#+%s+(.-)%s*$")

    if atx_text then
      table.insert(headings, { lnum = lnum, text = atx_text })
      lnum = lnum + 1
    else
      local stripped = line:match("^%s*(.-)%s*$")
      if stripped ~= "" and not setext_underline(line) then
        -- Look ahead for a contiguous run of non-blank lines terminated by
        -- a setext underline; that whole run is the heading text.
        local j = lnum + 1
        local text_lines = { stripped }
        while j <= #lines do
          local under = setext_underline(lines[j])
          if under then
            local text = table.concat(text_lines, " ")
            table.insert(headings, { lnum = lnum, text = text })
            break
          end
          local next_stripped = lines[j]:match("^%s*(.-)%s*$")
          if next_stripped == "" then
            break
          end
          table.insert(text_lines, next_stripped)
          j = j + 1
        end
      end
      lnum = lnum + 1
    end
  end

  return headings
end

-- Jumps the cursor in the current buffer to the heading matching `anchor`,
-- recognising both ATX (`#`) and setext (underlined) headings.
local function goto_heading(anchor, anchor_is_slug)
  local query = anchor_is_slug and slugify(anchor) or anchor:lower()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for _, heading in ipairs(collect_headings(lines)) do
    local candidate = anchor_is_slug and slugify(heading.text) or heading.text:lower()
    if candidate == query then
      vim.api.nvim_win_set_cursor(0, { heading.lnum, 0 })
      vim.cmd("normal! zz")
      return true
    end
  end

  vim.notify("Heading not found: #" .. anchor, vim.log.levels.WARN)
  return false
end

local function open_system(target)
  vim.ui.open(target)
  vim.notify("Opening externally: " .. target, vim.log.levels.INFO)
end

-- Jumps to the definition line for a reference link or footnote
local function goto_definition(label)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local pattern = "^%s*%[" .. vim.pesc(label) .. "%]:%s*(%S+)"

  for lnum, line in ipairs(lines) do
    local target = line:match(pattern)
    if target then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      vim.cmd("normal! zz")
      if target:match("^%a[%w+.-]*://") then
        open_system(target)
      end
      return true
    end
  end

  vim.notify("Definition not found: [" .. label .. "]", vim.log.levels.WARN)
  return false
end

local function fenced_block_at(lnum)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local fence_pattern = "^%s*```"

  local i = 1
  while i <= #lines do
    local line = lines[i]
    if line:match(fence_pattern) then
      local start = i
      local block_lang = line:match("^%s*```%s*([%w_+-]*)")
      local j = i + 1
      local close_line = nil
      while j <= #lines do
        if lines[j]:match(fence_pattern) then
          close_line = j
          break
        end
        j = j + 1
      end
      if close_line then
        if lnum >= start and lnum <= close_line then
          return {
            lang = block_lang,
            fence_start = start,
            fence_end = close_line,
            content_start = start + 1,
            content_end = close_line - 1,
          }
        end
        i = close_line + 1
      else
        if lnum >= start then
          return {
            lang = block_lang,
            fence_start = start,
            fence_end = nil,
            content_start = start + 1,
            content_end = #lines,
          }
        end
        i = j
      end
    else
      i = i + 1
    end
  end

  return nil
end

local function copy_code_block_at_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local block = fenced_block_at(lnum)
  if not block then
    return false
  end

  if block.content_end < block.content_start then
    vim.fn.setreg('"', "")
    vim.fn.setreg("+", "")
    vim.notify("Copied empty code block", vim.log.levels.INFO)
    return true
  end

  local body = vim.api.nvim_buf_get_lines(
    0, block.content_start - 1, block.content_end, false
  )
  local text = table.concat(body, "\n") .. "\n"

  vim.fn.setreg('"', text, "l")
  vim.fn.setreg("+", text, "l")

  local label = (block.lang and block.lang ~= "") and (block.lang .. " ") or ""
  vim.notify("Copied " .. label .. "code block (" .. #body .. " lines)", vim.log.levels.INFO)
  return true
end

local function open_target(info, replace)
  if not info or (not info.file and not info.anchor) then
    return vim.notify("Link has no target", vim.log.levels.WARN)
  end

  if info.file and info.file:match("^%a[%w+.-]*://") ~= nil then
    local url = info.file
    if info.anchor and info.anchor ~= "" then
      url = url .. "#" .. info.anchor
    end
    return open_system(url)
  end

  if not info.file or info.file == "" then
    if not info.anchor or info.anchor == "" then
      return vim.notify("Link has no file target", vim.log.levels.WARN)
    end
    goto_heading(info.anchor, info.anchor_is_slug)
    return
  end

  local path = vim.fs.normalize(vim.fn.fnamemodify(info.file, ":p"))
  if vim.fn.isdirectory(path) == 1 then
    return vim.notify("Link is a directory", vim.log.levels.WARN)
  end

  local ext = path:match("%.([%w]+)$")
  ext = ext and ext:lower() or nil
  if vim.fn.filereadable(path) ~= 1 then
    if ext and AUTO_CREATE[ext] then
      local dir = vim.fn.fnamemodify(path, ":h")
      if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end
    else
      return vim.notify("File does not exist: " .. path, vim.log.levels.WARN)
    end
  end

  if ext and not INTERNAL[ext] then
    open_system(path)
    return
  end

  if state.win ~= nil
    and vim.api.nvim_win_is_valid(state.win)
    and vim.api.nvim_get_current_win() == state.win then
    close_window()
  end
  local aft = replace and " | bd #" or ""
  vim.cmd("edit " .. vim.fn.fnameescape(path) .. aft)

  if info.anchor and info.anchor ~= "" then
    goto_heading(info.anchor, info.anchor_is_slug)
  end
end

-- Scans `<target>` autolinks
local function scan_angle_links(line, existing)
  local out = {}
  local pos = 1
  while true do
    local s, e = line:find("<[^%s<>]+>", pos)
    if not s then break end

    local overlaps = false
    for _, link in ipairs(existing) do
      if s <= link.end_col and e >= link.start_col then
        overlaps = true
        break
      end
    end

    if not overlaps then
      table.insert(out, {
        type = "angle",
        target = line:sub(s + 1, e - 1),
        start_col = s,
        end_col = e,
      })
    end

    pos = e + 1
  end
  return out
end

local function scan_links(line)
  local links = {}
  local i, n = 1, #line

  while i <= n do
    local c = line:sub(i, i)
    local advanced = false

    if c == "[" then
      if line:sub(i + 1, i + 1) == "[" then
        -- Wiki link: [[text]]
        local close = line:find("]]", i + 2, true)
        if close then
          table.insert(links, {
            type = "wiki",
            target = line:sub(i + 2, close - 1),
            start_col = i,
            end_col = close + 1,
          })
          i = close + 2
          advanced = true
        end
      elseif line:sub(i + 1, i + 1) == "^" then
        -- Footnote reference: [^label]
        local close = line:find("%]", i + 2)
        if close then
          local label = line:sub(i + 1, close - 1) -- includes leading "^"
          table.insert(links, {
            type = "footnote",
            target = label,
            start_col = i,
            end_col = close,
          })
          i = close + 1
          advanced = true
        end
      else
        -- [text](target) or [text][label]
        local search_from = i + 1
        while true do
          local close_bracket = line:find("%]", search_from)
          if not close_bracket then break end

          local next_char = line:sub(close_bracket + 1, close_bracket + 1)

          if next_char == "(" then
            -- Inline link: [text](target)
            local close_paren = line:find(")", close_bracket + 2, true)
            if close_paren then
              table.insert(links, {
                type = "md",
                target = line:sub(close_bracket + 2, close_paren - 1),
                start_col = i,
                end_col = close_paren,
              })
              i = close_paren + 1
              advanced = true
            end
            break
          elseif next_char == "[" then
            -- Reference link: [text][label] (label may be empty -> use text)
            local close2 = line:find("%]", close_bracket + 2)
            if close2 then
              local label = line:sub(close_bracket + 2, close2 - 1)
              if label == "" then
                label = line:sub(i + 1, close_bracket - 1)
              end
              table.insert(links, {
                type = "reference",
                target = label,
                start_col = i,
                end_col = close2,
              })
              i = close2 + 1
              advanced = true
            end
            break
          else
            -- Plain [text] with no ( ) or [ ] following
            break
          end
        end
      end
    end
    if not advanced then i = i + 1 end
  end

  for _, angle in ipairs(scan_angle_links(line, links)) do
    table.insert(links, angle)
  end
  return links
end

--- True if `text` already looks like a file reference rather than a bare
--- page title: it has a path separator, or ends in a dotted extension.
local function looks_like_path(text)
  if text:find("/", 1, true) then
    return true
  end
  return text:match("%.[%w]+$") ~= nil
end

function M.normalise(link)
  local page = link:match("^[^#]+") or link
  page = page:match("^%s*(.-)%s*$")

  if looks_like_path(page) then
    return page
  end

  return slugify(page) .. ".md"
end

-- Converts a scanned link into the descriptor consumed by `open_target`.
local function link_target(link)
  if link.type == "angle" then
    local file, anchor = split_anchor(link.target)
    return { file = file ~= "" and file or nil, anchor = anchor, anchor_is_slug = true }
  end

  local file, anchor = split_anchor(link.target)

  if link.type == "wiki" then
    local normalised = file ~= "" and M.normalise(file) or nil
    local prefixed = normalised
    if normalised and not (normalised:match("^%.?%.?/") or normalised:match("^/")) then
      prefixed = "./" .. normalised
    end
    return {
      file = prefixed,
      anchor = anchor,
      anchor_is_slug = false,
    }
  end

  return {
    file = file ~= "" and file or nil,
    anchor = anchor,
    anchor_is_slug = true,
  }
end

function M.follow(replace)
  if copy_code_block_at_cursor() then return end

  local line = vim.api.nvim_get_current_line()
  local col1 = vim.api.nvim_win_get_cursor(0)[2] + 1
  for _, link in ipairs(scan_links(line)) do
    if col1 >= link.start_col and col1 <= link.end_col then
      if link.type == "reference" or link.type == "footnote" then
        goto_definition(link.target)
      else
        open_target(link_target(link), replace)
      end
      return
    end
  end
  vim.notify("Nothing interesting under cursor", vim.log.levels.INFO)
end

local function wrap_range_as_code_block(s_line, s_col, e_line, e_col)
  if s_col > 1 then
    local line = vim.api.nvim_buf_get_lines(0, s_line - 1, s_line, false)[1] or ""
    local before = line:sub(1, s_col - 1)
    local after = line:sub(s_col)
    vim.api.nvim_buf_set_lines(0, s_line - 1, s_line, false, { before, after })
    e_line = e_line + 1
    s_line = s_line + 1
    s_col = 1
  end

  do
    local line = vim.api.nvim_buf_get_lines(0, e_line - 1, e_line, false)[1] or ""
    if e_col < #line then
      local before = line:sub(1, e_col)
      local after = line:sub(e_col + 1)
      vim.api.nvim_buf_set_lines(0, e_line - 1, e_line, false, { before, after })
    end
  end

  vim.api.nvim_buf_set_lines(0, e_line, e_line, false, { "```" })
  vim.api.nvim_buf_set_lines(0, s_line - 1, s_line - 1, false, { "```" })
end

function M.visual_follow(replace)
  local vmode = vim.fn.mode()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  local s_line, s_col = start_pos[2], start_pos[3]
  local e_line, e_col = end_pos[2], end_pos[3]

  if s_line > e_line or (s_line == e_line and s_col > e_col) then
    s_line, e_line, s_col, e_col = e_line, s_line, e_col, s_col
  end

  if vmode == "V" then
    s_col = 1
    local end_line_text = vim.api.nvim_buf_get_lines(0, e_line - 1, e_line, false)[1] or ""
    e_col = math.max(#end_line_text, 1)
  end

  vim.cmd("normal! \27")

  if s_line ~= e_line then
    wrap_range_as_code_block(s_line, s_col, e_line, e_col)
    return
  end

  local line = vim.api.nvim_buf_get_lines(0, s_line - 1, s_line, false)[1] or ""
  for _, link in ipairs(scan_links(line)) do
    if link.start_col <= s_col and link.end_col >= e_col then
      if link.type == "reference" or link.type == "footnote" then
        return goto_definition(link.target)
      end
      return open_target(link_target(link), replace)
    end
  end

  local lines = vim.api.nvim_buf_get_text(0, s_line - 1, s_col - 1, e_line - 1, e_col, {})
  local text = table.concat(lines, "\n")
  vim.api.nvim_buf_set_text(0, s_line - 1, s_col - 1, e_line - 1, e_col, { "[[" .. text .. "]]" })
end

return M
