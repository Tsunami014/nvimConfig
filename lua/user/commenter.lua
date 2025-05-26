local M = {}

-- Helper: Escape Lua pattern magic characters
local function escape_pattern(s)
  return s:gsub("([^%w])", "%%%1")
end

-- Toggle comment for a range of lines
function M.toggle_comment_lines(start_line, end_line)
  local cs = vim.bo.commentstring
  local prefix, suffix = cs:match("^(.-)%%s(.-)$")
  prefix = prefix or ""
  suffix = suffix or ""

  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)
  local all_commented = true

  -- Detect if all lines are already commented
  for _, line in ipairs(lines) do
    if not line:find("^%s*" .. escape_pattern(prefix)) then
      all_commented = false
      break
    end
  end

  -- Toggle comment
  for i, line in ipairs(lines) do
    if all_commented then
      -- Uncomment
      line = line:gsub("^%s*" .. escape_pattern(prefix), "", 1)
      if suffix ~= "" then
        line = line:gsub(escape_pattern(suffix) .. "%s*$", "", 1)
      end
    else
      -- Comment
      line = prefix .. line .. suffix
    end
    lines[i] = line
  end

  vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, lines)
end

return M

