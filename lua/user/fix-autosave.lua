local resession = require("resession")

-- Save visual selection info before save, restore after
resession.add_hook("pre_save", function()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    -- record current buffer and selection marks
    vim.w._resession_prev_buf = vim.api.nvim_get_current_buf()
    vim.w._resession_prev_mode = mode
    vim.w._resession_prev_start = vim.api.nvim_buf_get_mark(0, "<")
    vim.w._resession_prev_end   = vim.api.nvim_buf_get_mark(0, ">")
  end
end)

resession.add_hook("post_save", function()
  local bufnr = vim.w._resession_prev_buf
  if not bufnr then return end
  if vim.api.nvim_buf_is_valid(bufnr) then
    local cur = vim.api.nvim_get_current_buf()
    if cur ~= bufnr then
      -- try to switch buffer in current window; this won't change tabpages
      pcall(vim.cmd, "buffer " .. vim.api.nvim_buf_get_name(bufnr))
    end

    -- reset the '< and '> marks (line, col)
    local s = vim.w._resession_prev_start
    local e = vim.w._resession_prev_end
    if s and e then
      pcall(vim.api.nvim_buf_set_mark, bufnr, "<", s[1], s[2], {})
      pcall(vim.api.nvim_buf_set_mark, bufnr, ">", e[1], e[2], {})
      -- re-enter visual using correct kind
      local mode = vim.w._resession_prev_mode
      local enter = ({ v = "v", V = "V", ["\22"] = "<C-v>" })[mode] or "v"
      local seq = vim.api.nvim_replace_termcodes(enter .. "gv", true, false, true)
      vim.api.nvim_feedkeys(seq, "n", true)
    end
  end

  vim.w._resession_prev_buf = nil
  vim.w._resession_prev_mode = nil
  vim.w._resession_prev_start = nil
  vim.w._resession_prev_end = nil
end)
