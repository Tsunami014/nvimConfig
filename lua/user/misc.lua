-- Pretend code completion windows are markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = "codecompanion",
  callback = function()
    vim.opt.filetype = "markdown"
    vim.cmd("doautocmd FileType markdown")
  end
})

-- Add a dump highlights command to dump highlights to a temporary buffer
vim.api.nvim_create_user_command("DumpHighlights", function()
  local output = vim.api.nvim_exec2("highlight", { output = true }).output
  local lines = vim.split(output, "\n")

  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  for lnum, line in ipairs(lines) do
    local group = line:match("^([%w_]+)")
    if group then
      vim.api.nvim_buf_add_highlight(buf, -1, group, lnum - 1, 0, #group)
    end
  end
end, {})


-- Wrap in certain filetypes
local wrapIn = {"markdown", "tex"}
local function doWrap(filetype)
  for index, value in pairs(wrapIn) do
    if filetype == value then
      return true
    end
  end
  return false
end
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile", "BufEnter"}, {
  pattern = "*",
  callback = function()
    vim.opt_local.wrap = doWrap(vim.bo.filetype)
  end
})
