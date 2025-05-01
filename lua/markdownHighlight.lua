local M = {}
local ns = vim.api.nvim_create_namespace("markdownHighlight")
local filetype = "markdown"

local heading_hl = {
  "@markup.heading.1.markdown",
  "@markup.heading.2.markdown",
  "@markup.heading.3.markdown",
  "@markup.heading.4.markdown",
  "@markup.heading.5.markdown",
  "@markup.heading.6.markdown",
}

-- Bar piece characters
local left_full = ""
local left_empty = ""
local mid_full = ""
local mid_empty = ""
local right_full = ""
local right_empty = ""

-- Build progress bar based on percent and heading level
local function make_bar(percent, level)
  local parts = {}
  for i = 1, level+1 do
    local threshold = (i / (level+3)) * 100
    local is_full = percent >= threshold
    if i == 1 then
      parts[#parts+1] = is_full and left_full or left_empty
    elseif i == level+1 then
      parts[#parts+1] = is_full and right_full or right_empty
    else
      parts[#parts+1] = is_full and mid_full or mid_empty
    end
  end
  return table.concat(parts)
end

-- Prepare the display text for a heading line
local function make_bar_line(idx, total, line)
  local hashes, text = string.match(line, "^(#+)%s*(.*)$")
  if not hashes then return end
  local level = #hashes
  local percent = math.floor((idx / total) * 100)
  local bar = make_bar(percent, level)
  return level, bar .. " " .. text
end

-- Redraw all overlays, skipping the cursor line
function M.redraw(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_option(bufnr, "filetype") ~= filetype then return end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total = #lines
  local cursor = vim.api.nvim_win_get_cursor(0)[1]

  for i, line in ipairs(lines) do
    local level, disp = make_bar_line(i, total, line)
    if disp and i ~= cursor then
      local hl = heading_hl[level] or heading_hl[#heading_hl]
      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
        virt_text = {{disp, hl}},
        virt_text_pos = 'overlay',
      })
    end
  end
end

-- Setup autocommands
function M.setup()
  vim.cmd([[augroup MarkdownNumberDisplay
    autocmd!
    autocmd CursorMoved,CursorMovedI,BufEnter,BufWritePost,TextChanged,TextChangedI *.md lua require('markdownHighlight').redraw()
  augroup END]])
end

M.setup()
return M
