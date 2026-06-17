local M = {}

local function escape_pattern(s)
  return s:gsub("([^%w])", "%%%1")
end
local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

local function get_comment_tokens(commentstring)
  local raw_prefix, raw_suffix = commentstring:match("^(.-)%%s(.-)$")
  raw_prefix, raw_suffix = raw_prefix or "", raw_suffix or ""

  local prefix = raw_prefix:match("^%s*(.-)%s*$")
  local suffix = raw_suffix:match("^%s*(.-)%s*$")

  return prefix, suffix
end

--- Smallest leading-whitespace width among the non-blank lines.
local function min_indent(lines)
  local min
  for _, line in ipairs(lines) do
    if not is_blank(line) then
      local indent = #line:match("^%s*")
      if not min or indent < min then
        min = indent
      end
    end
  end
  return min or 0
end
local function all_commented(lines, prefix_pat)
  local saw_content = false
  for _, line in ipairs(lines) do
    if not is_blank(line) then
      saw_content = true
      if not line:find("^%s*" .. prefix_pat) then
        return false
      end
    end
  end
  return saw_content
end

local function comment_line(line, indent, prefix, suffix)
  local leading, rest = line:sub(1, indent), line:sub(indent + 1)
  local result = leading .. prefix .. " " .. rest
  if suffix ~= "" then
    result = result .. " " .. suffix
  end
  return result
end

local function uncomment_line(line, prefix_pat, suffix_pat)
  line = line:gsub("^(%s*)" .. prefix_pat .. " ?", "%1", 1)
  if suffix_pat then
    line = line:gsub(" ?" .. suffix_pat .. "%s*$", "", 1)
  end
  return line
end

function M.toggle_comment_lines(start_line, end_line)
  local prefix, suffix = get_comment_tokens(vim.bo.commentstring)
  if prefix == "" then
    vim.notify("No commentstring set for this filetype", vim.log.levels.WARN)
    return
  end

  local prefix_pat = escape_pattern(prefix)
  local suffix_pat = suffix ~= "" and escape_pattern(suffix) or nil

  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)

  if all_commented(lines, prefix_pat) then
    for i, line in ipairs(lines) do
      if not is_blank(line) then
        lines[i] = uncomment_line(line, prefix_pat, suffix_pat)
      end
    end
  else
    local indent = min_indent(lines)
    for i, line in ipairs(lines) do
      if not is_blank(line) then
        lines[i] = comment_line(line, indent, prefix, suffix)
      end
    end
  end

  vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, lines)
end

return M
