local M = {}

M.active = false
M.buf = nil
M.win = nil

M.commands = {
  a = { function() vim.lsp.buf.code_action() end, "Apply code action" },
  x = { function() vim.cmd("Trouble diagnostics toggle") end, "Toggle diagnostics" },
  r = { function() vim.cmd("SearchReplaceSingleBufferOpen") end, "Replace in current buffer", exit = true },
  f = { function() vim.cmd("Telescope live_grep") end, "Find grep in all dirs", exit = true },
  n = { function() vim.cmd("Telescope notify") end, "Show notifications", exit = true },
  ["]"] = { function() vim.cmd("cnext") end, "Next quickfix" },
  ["["] = { function() vim.cmd("cprev") end, "Previous quickfix" },
  g = { function() vim.cmd("LazyGit") end, "Open LazyGit", exit = true },
  b = { function() require("dap").toggle_breakpoint() end, "Toggle breakpoint" },
  t = { function() vim.cmd("ToggleTerm") end, "Toggle terminal" },
  k = { function() require("knap").process_once() end, "Process preview once" },
  p = { function() vim.cmd("BufferPick") end, "Pick buffer", exit = true },
  c = { function() vim.cmd("Trouble symbols toggle") end, "Toggle symbols" },
  C = { function() vim.cmd("Trouble lsp toggle") end, "Toggle LSP references/definitions" },
  ["."] = { function() require("notify").dismiss() end, "Dismiss notifications" },
  e = { function() vim.cmd("Neotree toggle") end, "Toggle file explorer" },
  d = { function() require("dapui").toggle() end, "Toggle debugger UI" },
  w = { function() vim.cmd("set wrap!") end, "Toggle line wrap" },
}

function create_hint()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_buf_clear_namespace(M.buf, -1, 0, -1)
  else
    M.buf = vim.api.nvim_create_buf(false, true)
  end

  local lines = {}
  for k, v in pairs(M.commands) do
    table.insert(lines, string.format("%s → %s%s", k, v.exit and "(exit) " or "", v[2]))
  end
  table.sort(lines, function(a, b)
    local a1 = string.sub(a, 1, 1)
    local b1 = string.sub(b, 1, 1)
    local function score(k)
      -- lower = first
      if k:match("%l") then return 3 end  -- Lowercase
      if k:match("%u") then return 2 end  -- Uppercase
      return 1  -- Symbols
    end

    local sa, sb = score(a1), score(b1)
    if sa == sb then
      return a1 < b1
    else
      return sa < sb
    end
  end)
  table.insert(lines, "<Esc> → Exit")

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)

  if not M.win or not vim.api.nvim_win_is_valid(M.win) then
    local opts = {
      relative = "editor",
      width = 40,
      height = #lines,
      row = 2,
      col = 2,
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = 50,
    }
    M.win = vim.api.nvim_open_win(M.buf, false, opts)
  end
end

function M.close_hydra()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
  M.active = false
end

-- Start the hydra
function M.start_hydra()
  if M.active then
    M.close_hydra()
    create_hint()
    print("Hydra restarted! Press keys, <Esc> to exit.")
  else
    M.active = true
    create_hint()
    print("Hydra active! Press keys, <Esc> to exit.")
  end

  vim.schedule(function()
    while M.active do
      local ok, char = pcall(vim.fn.getchar)
      if not ok then break end

      local key
      if type(char) == "number" then
        key = vim.fn.nr2char(char)
      elseif type(char) == "string" then
        key = char
      end

      if key == "\27" then
        M.active = false
        break
      end

      local cmd = M.commands[key]
      if cmd then
        -- safely call the function
        local ok_cmd, err = pcall(cmd[1])
        if not ok_cmd then
          print("Error: " .. tostring(err))
        end

        vim.cmd("redraw")

        if cmd.exit then
          M.active = false
          break
        end
      else
        print("No command for key: " .. tostring(key))
      end
    end

    M.close_hydra()
    print("Hydra exited!")
  end)
end

return M
