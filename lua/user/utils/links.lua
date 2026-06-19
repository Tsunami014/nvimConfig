local M = {}

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

local function open_system(target)
  vim.ui.open(target)
  vim.notify("Opening externally: " .. target, vim.log.levels.INFO)
end

local function open_target(target, replace)
  if not target or target == "" then
    return vim.notify("Link has no target", vim.log.levels.WARN)
  end
  if target:match("^%a[%w+.-]*://") ~= nil then
    return open_system(target)
  end

  local file = target:match("^([^#]*)") or target
  if file == "" then
    return vim.notify("Link has no file target", vim.log.levels.WARN)
  end
  local path = vim.fs.normalize(vim.fn.fnamemodify(file, ":p"))
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
    open_with_system(path)
  else
    local aft = replace and " | bd #" or ""
    vim.cmd("edit " .. vim.fn.fnameescape(path) .. aft)
  end
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
      else
        -- Markdown link: [text](target)
        local search_from = i + 1
        while true do
          local close_bracket = line:find("%]", search_from)
          if not close_bracket then break end

          if line:sub(close_bracket + 1, close_bracket + 1) == "(" then
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
          end
          search_from = close_bracket + 1
        end
      end
    end
    if not advanced then i = i + 1 end
  end
  return links
end

local function link_target(link)
  if link.type == "wiki" then
    local page = link.target:match("^[^#]+") or link.target
    return "./" .. page:lower():gsub("%s+", "-"):gsub("[^%w%-]", "") .. ".md"
  end
  return link.target
end

function M.follow(replace)
  local line = vim.api.nvim_get_current_line()
  local col1 = vim.api.nvim_win_get_cursor(0)[2] + 1
  for _, link in ipairs(scan_links(line)) do
    if col1 >= link.start_col and col1 <= link.end_col then
      open_target(link_target(link), replace)
      return
    end
  end
  vim.notify("No link under cursor", vim.log.levels.INFO)
end

function M.visual_follow(replace)
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  local s_line, s_col = start_pos[2], start_pos[3]
  local e_line, e_col = end_pos[2], end_pos[3]

  if s_line > e_line or (s_line == e_line and s_col > e_col) then
    s_line, e_line, s_col, e_col = e_line, s_line, e_col, s_col
  end

  vim.cmd("normal! \27")

  if s_line ~= e_line then return nil end
  local line = vim.api.nvim_buf_get_lines(0, s_line - 1, s_line, false)[1] or ""
  for _, link in ipairs(scan_links(line)) do
    if link.start_col <= s_col and link.end_col >= e_col then
      return open_target(link_target(link), replace)
    end
  end

  local lines = vim.api.nvim_buf_get_text(0, s_line - 1, s_col - 1, e_line - 1, e_col, {})
  local text = table.concat(lines, "\n")
  vim.api.nvim_buf_set_text(0, s_line - 1, s_col - 1, e_line - 1, e_col, { "[[" .. text .. "]]" })
end

return M
