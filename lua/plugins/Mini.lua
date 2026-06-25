local confDir
if vim.fn.has("win32") == 1 then
  confDir = "$APPDATA"
else
  confDir = "~/.config"
end

return {{
  "nvim-mini/mini.nvim", version = '*',
  config = function()
    require('mini.icons').setup()
    require("mini.pick").setup()
    require('mini.extra').setup()

    local starter = require('mini.starter')
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
        { name = "Files", action = ":lua Snacks.dashboard.pick('files')", section = "Open" },
        { name = "Folders", action = ":lua require('user.utils.folder-pick').pick_folder_in()", section = "Open" },
        { name = "Config", action = ":lua require('user.utils.folder-pick').pick_folder_in('" .. confDir:gsub("'", "\\'") .. "')", section = "Open" },
        { name = "Recent", action = ":lua Snacks.dashboard.pick('oldfiles')", section = "Open" },
        { name = "Text", action = ":lua Snacks.dashboard.pick('live_grep')", section = "Open" },
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

    require('mini.completion').setup({
      window = {
        info = { border = 'rounded' },
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
