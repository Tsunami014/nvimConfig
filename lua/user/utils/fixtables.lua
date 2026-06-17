local M = {}

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function get_width(str)
  -- prefer display width (handles multibyte/wide chars sanely)
  if vim.fn.strdisplaywidth then
    return vim.fn.strdisplaywidth(str)
  end
  return #str
end

local function get_leading_ws(line)
  return line:match("^(%s*)") or ""
end

local function is_table_line(line)
  if not line then return false end
  local t = trim(line)
  if t == "" then return false end
  return t:find("|", 1, true) ~= nil
end

-- Split a table row line into trimmed cell strings.
-- Tolerates rows with/without leading or trailing pipes.
local function split_cells(line)
  local t = trim(line)
  if t:sub(1, 1) == "|" then
    t = t:sub(2)
  end
  if t:sub(-1) == "|" then
    t = t:sub(1, -2)
  end

  local cells = {}
  -- append a sentinel "|" so the trailing cell is captured by gmatch too
  for cell in (t .. "|"):gmatch("(.-)|") do
    table.insert(cells, trim(cell))
  end
  return cells
end

local function is_separator_cell(cell)
  if cell == "" then return false end
  if not cell:match("^[%-:]+$") then return false end
  return true
end

local function is_separator_row(cells)
  if #cells == 0 then return false end
  local hasconts = false
  for _, c in ipairs(cells) do
    if c:match("%S") then
      if not is_separator_cell(c) then
        return false
      end
      hasconts = true
    end
  end
  return hasconts
end

-- Determine alignment from a separator cell.
local function cell_alignment(cell)
  local len = #cell
  local first_is_colon = cell:sub(1, 1) == ":"
  local last_is_colon = cell:sub(-1) == ":"

  if first_is_colon and last_is_colon then
    return "center"
  elseif first_is_colon then
    return "left"
  elseif last_is_colon then
    return "right"
  end

  -- no colon at the true edges: maybe it's sloppy (e.g. "--::--"). Scan halves.
  if not cell:find(":", 1, true) then
    return "none"
  end

  local half = math.ceil(len / 2)
  local left_part = cell:sub(1, half)
  local right_part = cell:sub(len - half + 1, len)
  local left_colon = left_part:find(":", 1, true) ~= nil
  local right_colon = right_part:find(":", 1, true) ~= nil
  if left_colon and right_colon then
    return "center"
  elseif right_colon then
    return "right"
  elseif left_colon then
    return "left"
  else
    return "none"
  end
end

-- Renders the separator cell's marker string for the given final column width
local function build_separator_cell(width, align)
  if align == "center" then
    if width > 5 then
      return " :" .. string.rep("-", width - 4) .. ": "
    end
    width = math.max(width, 3)
    return ":" .. string.rep("-", width - 2) .. ":"
  elseif align == "right" then
    if width > 4 then
      return " " .. string.rep("-", width - 3) .. ": "
    end
    width = math.max(width, 2)
    return string.rep("-", width - 1) .. ":"
  elseif align == "left" then
    if width > 4 then
      return " :" .. string.rep("-", width - 3) .. " "
    end
    width = math.max(width, 2)
    return ":" .. string.rep("-", width - 1)
  else
    if width > 3 then
      return " " .. string.rep("-", width - 2) .. " "
    end
    width = math.max(width, 1)
    return string.rep("-", width)
  end
end

-- Pads a data cell to `width` according to the column's header alignment.
local function pad_cell(text, width, align)
  local w = get_width(text)
  local diff = width - w
  if diff <= 0 then return text end

  if align == "right" then
    return string.rep(" ", diff) .. text
  elseif align == "center" then
    local left = math.floor(diff / 2)
    local right = diff - left
    return string.rep(" ", left) .. text .. string.rep(" ", right)
  else -- left / none
    return text .. string.rep(" ", diff)
  end
end


function M.fix_table()
  local bufnr = 0
  local cur_lnum = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed

  local cur_line = vim.api.nvim_buf_get_lines(bufnr, cur_lnum - 1, cur_lnum, false)[1]
  if not is_table_line(cur_line) then
    vim.notify("No markdown table found at cursor", vim.log.levels.WARN)
    return
  end

  -- scan upward for contiguous table lines
  local start_lnum = cur_lnum
  while start_lnum > 1 do
    local l = vim.api.nvim_buf_get_lines(bufnr, start_lnum - 2, start_lnum - 1, false)[1]
    if is_table_line(l) then
      start_lnum = start_lnum - 1
    else
      break
    end
  end

  -- scan downward for contiguous table lines
  local last_line = vim.api.nvim_buf_line_count(bufnr)
  local end_lnum = cur_lnum
  while end_lnum < last_line do
    local l = vim.api.nvim_buf_get_lines(bufnr, end_lnum, end_lnum + 1, false)[1]
    if is_table_line(l) then
      end_lnum = end_lnum + 1
    else
      break
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)

  -- parse each row
  local rows = {}
  for i, line in ipairs(lines) do
    local cells = split_cells(line)
    rows[i] = { cells = cells, is_sep = is_separator_row(cells) }
  end

  -- canonical indentation: take it from the first row of the block
  local indent = get_leading_ws(lines[1])

  -- max content width per column (from non-separator rows only)
  local col_widths = {}
  for _, row in ipairs(rows) do
    if not row.is_sep then
      for j, cell in ipairs(row.cells) do
        local w = get_width(cell)
        if not col_widths[j] or w > col_widths[j] then
          col_widths[j] = w
        end
      end
    end
  end

  -- alignment per column, taken from whichever separator row defines it
  local col_align = {}
  for _, row in ipairs(rows) do
    if row.is_sep then
      for j, cell in ipairs(row.cells) do
        col_align[j] = cell_alignment(cell)
      end
    end
  end

  local min_for_align = { none = 1, left = 2, right = 2, center = 3 }
  local interior_width = {}
  for j, content_w in pairs(col_widths) do
    local padded_interior = content_w + 2 -- " content "
    local marker_w = min_for_align[col_align[j]] or 1
    interior_width[j] = math.max(padded_interior, marker_w)
  end
  -- columns that only ever appear in a separator row (no data row reached
  -- that far) still need an interior width
  for _, row in ipairs(rows) do
    if row.is_sep then
      for j, _ in ipairs(row.cells) do
        if not interior_width[j] then
          interior_width[j] = math.max(min_for_align[col_align[j]] or 1, 3)
        end
      end
    end
  end

  -- rebuild every row
  local out = {}
  for i, row in ipairs(rows) do
    local parts = {}
    for j, cell in ipairs(row.cells) do
      local iw = interior_width[j] or (get_width(cell) + 2)
      if row.is_sep then
        parts[j] = build_separator_cell(iw, col_align[j] or "none")
      else
        parts[j] = " " .. pad_cell(cell, iw - 2, col_align[j]) .. " "
      end
    end
    out[i] = indent .. "|" .. table.concat(parts, "|") .. "|"
  end

  vim.api.nvim_buf_set_lines(bufnr, start_lnum - 1, end_lnum, false, out)

  -- keep cursor on the same line, clamp column safely
  pcall(vim.api.nvim_win_set_cursor, 0, { cur_lnum, 0 })
end

function M.setup(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command("FixMdTable", function()
    M.fix_table()
  end, { desc = "Normalise the markdown table under the cursor" })

  local keymap = opts.keymap or "<leader>tf"
  vim.keymap.set("n", keymap, M.fix_table, { desc = "Fix markdown table at cursor", silent = true })
end

return M
