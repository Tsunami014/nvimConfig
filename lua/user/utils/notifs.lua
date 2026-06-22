local M = {}
M.history = {}

function M.pick()
  local hist_rev = {}
  for i = #M.history, 1, -1 do
    table.insert(hist_rev, M.history[i])
  end

  require("mini.pick").start({
    source = {
      name = "vim.notify History",
      items = hist_rev,
      choose = function(item)
        local buf = vim.api.nvim_create_buf(false, true)
        local lines = vim.split(item, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local max_line_len = 0
        for _, line in ipairs(lines) do
          if #line > max_line_len then
            max_line_len = #line
          end
        end

        local win_width = math.min(max_line_len + 2, math.floor(vim.o.columns * 0.7))
        local win_height = math.min(#lines, math.floor(vim.o.lines * 0.5))

        local win = vim.api.nvim_open_win(buf, false, {
          relative = "editor",
          width = win_width,
          height = win_height,
          row = math.floor((vim.o.lines - win_height) / 2),
          col = math.floor((vim.o.columns - win_width) / 2),
          style = "minimal",
          border = "rounded",
        })
        vim.wo[win].wrap = true

        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
          end
        end)

        vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
        vim.keymap.set("n", "<Esc>", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
      end,
    },
  })
end


function M.setup()
  local notif = require('mini.notify')
  notif.setup({
    content = {
      format = function(notif)
        local icons = {
          INFO  = " ",
          WARN  = " ",
          ERROR = " ",
          DEBUG = " ",
        }
        local icon = icons[notif.level] or ""
        return icon .. (notif.msg or "")
      end,
    }
  })

  local mknotif = notif.make_notify({
    ERROR = { duration = 8000 },
    WARN = { duration = 6000 },
    INFO = { duration = 4000 },
  })
  vim.notify = function(msg, level, opts)
    local time = os.date("%H:%M:%S")
    local level_names = { [1] = "DEBUG", [2] = "INFO", [3] = "WARN", [4] = "ERROR" }
    local level_str = level_names[level] or "INFO"
    local formatted_msg = string.format("[%s] %s: %s", time, level_str, msg)
    table.insert(M.history, formatted_msg)
    mknotif(msg, level, opts)
  end
end

return M
