local M = {}

function M.interest(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    vim.cmd("normal! " .. (direction == "next" and "]]" or "[["))
    return
  end

  local ok, query = pcall(vim.treesitter.query.get, lang, "folds")
  if not ok or not query then
    vim.cmd("normal! " .. (direction == "next" and "]]" or "[["))
    return
  end

  local parser = vim.treesitter.get_parser(bufnr, lang)
  local root = parser:parse()[1]:root()
  local cur_row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local rows = {}
  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local srow = node:range()
    rows[srow] = true -- dedupe by row
  end

  local sorted = {}
  for row in pairs(rows) do table.insert(sorted, row) end
  table.sort(sorted)

  if direction == "next" then
    for _, row in ipairs(sorted) do
      if row > cur_row then
        vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
        return
      end
    end
  else
    for i = #sorted, 1, -1 do
      if sorted[i] < cur_row then
        vim.api.nvim_win_set_cursor(0, { sorted[i] + 1, 0 })
        return
      end
    end
  end
end

return M
