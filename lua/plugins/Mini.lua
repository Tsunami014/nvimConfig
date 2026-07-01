local confDir
if vim.fn.has("win32") == 1 then
  confDir = "$APPDATA"
else
  confDir = "~/.config"
end


-- Prevent mini.completions in some filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree-popup",
  callback = function()
    vim.b.minicompletion_disable = true
  end,
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniSnippetsSessionStop',
  callback = function()
    -- When a snippets session ends, delete all placeholders
    local buf = vim.api.nvim_get_current_buf()
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })

    local ranges = {}
    for _, m in ipairs(marks) do
      local row, col, details = m[2], m[3], m[4]
      local hl = details.hl_group
      if hl == 'MiniSnippetsCurrentReplace' or hl == 'MiniSnippetsUnvisited' then
        if details.end_row and (details.end_row > row or details.end_col > col) then
          table.insert(ranges, { row, col, details.end_row, details.end_col })
        end
      end
    end
    if #ranges == 0 then return end

    table.sort(ranges, function(a, b)
      if a[1] ~= b[1] then return a[1] > b[1] end
      return a[2] > b[2]
    end)

    vim.schedule(function()
      for _, r in ipairs(ranges) do
        pcall(vim.api.nvim_buf_set_text, buf, r[1], r[2], r[3], r[4], {})
      end
    end)
  end,
})

return {{
  "nvim-mini/mini.nvim", version = '*',
  config = function()
    require('mini.icons').setup()
    require("mini.pick").setup()
    require('mini.extra').setup()

    local starter = require('mini.starter')
    local foldp = require('user.utils.folder-pick')
    starter.setup({
      header = [[
 ███▄    █ ▓█████  ▒█████   ██▒   █▓ ██▓ ███▄ ▄███▓
 ██ ▀█   █ ▓█   ▀ ▒██▒  ██▒▓██░   █▒▓██▒▓██▒▀█▀ ██▒
▓██  ▀█▄██▒▒███   ▒██░  ██▒ ▓██  █▒░▒██▒▓██    ▓██░
▓██▒   ███▒▒▓█  ▄ ▒██   ██░  ▒██ █░░░██░▒██    ▒██ 
▒██░   ▓██░░▒████▒░ ████▓▒░   ▒▀█░  ░██░▒██▒   ░██▒
░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒░▒░▒░    ░ █░  ░▓  ░ ▒░   ░  ░
░ ░░   ░ ▒░ ░ ░  ░  ░ ▒ ▒░    ░ ░░   ▒ ░░  ░      ░
   ░   ░ ░    ░   ░ ░ ░ ▒       ░░   ▒ ░░      ░   
         ░    ░  ░    ░ ░        ░   ░         ░   
      ]],

      evaluate_single = true,
      items = {
        { name = "New", action = function() starter.close() vim.cmd('startinsert') end, section = "Open" },
        { name = "Files", action = ":Telescope find_files", section = "Open" },
        { name = "Folders", action = foldp.pick_folder_in, section = "Open" },
        { name = "Config", action = function() foldp.pick_folder_in(confDir) end, section = "Open" },
        { name = "Recent", action = MiniExtra.pickers.oldfiles, section = "Open" },
        { name = "Text", action = ":Telescope live_grep", section = "Open" },
        { name = "Lazy", action = ":Lazy", section = "Actions" },
        starter.sections.recent_files(10, false),
      },
      content_hooks = {
        starter.gen_hook.adding_bullet(),
        starter.gen_hook.indexing('all', { 'Open', 'Actions' }),
        starter.gen_hook.aligning('center', 'center'),
        starter.gen_hook.padding(0, 2),
      },
    })

    require('mini.snippets').setup({
      snippets = {
        require('mini.snippets').gen_loader.from_lang(),
      },
    })
    require('mini.completion').setup({
      window = {
        info = { border = 'rounded' },
      },
      lsp_completion = {
        process_items = function(items, base)
          -- Cut off ending characters that are the same as the characters after the cursor
          items = MiniCompletion.default_process_items(items, base)

          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]
          local char_after = line:sub(col + 1, col + 1)
          if char_after == '' then return items end

          for _, item in ipairs(items) do
            local text = item.textEdit and item.textEdit.newText or item.insertText
            if text and text:sub(-1) == char_after then
              if item.textEdit then
                item.textEdit.newText = text:sub(1, -2)
              else
                item.insertText = text:sub(1, -2)
              end
            end
          end
          return items
        end,
      },
    })

    require('user.utils.notifs').setup() -- Sets up mini.notify

    require('mini.diff').setup()
    require('user.statusline') -- Sets up mini.statusline

    require('mini.ai').setup()
    require('mini.jump').setup()
    require('mini.comment').setup()
    require('mini.surround').setup()
    require('mini.cursorword').setup()
    require('mini.trailspace').setup()
    require('mini.indentscope').setup({ symbol = '│' })
  end
}}
