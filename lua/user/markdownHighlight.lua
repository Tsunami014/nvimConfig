local M = {}

local cursor_override_match_id = nil

local function override_cursor_heading()
  if cursor_override_match_id then
    vim.fn.matchdelete(cursor_override_match_id)
    cursor_override_match_id = nil
  end

  local cur_line = vim.api.nvim_get_current_line()
  local heading_pattern = "^#+%s*.+"
  if cur_line:match(heading_pattern) then
    local lnum = vim.fn.line(".")
    cursor_override_match_id = vim.fn.matchaddpos("NoMDHeading", { { lnum, 1, -1 } }, 1000)
  end
end

function M.setup()
  for i = 1, 6 do
    local hl_group = "@markup.heading." .. i .. ".markdown"
    local existing = vim.api.nvim_get_hl(0, { name = hl_group })

    if existing.fg ~= 0 then
      vim.api.nvim_set_hl(0, hl_group, { bold = true, fg = "#000000", bg = existing.fg })
    end
  end

  vim.cmd("highlight link NoMDHeading Normal")

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    callback = override_cursor_heading,
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    M.setup()
  end,
})

return M
