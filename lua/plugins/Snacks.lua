local confDir
if vim.fn.has("win32") == 1 then
  confDir = "$APPDATA"
else
  confDir = "~/.config"
end

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = { enabled = true },
      dashboard = {
        preset = {
          header = [[


 ███▄    █ ▓█████  ▒█████   ██▒   █▓ ██▓ ███▄ ▄███▓
 ██ ▀█   █ ▓█   ▀ ▒██▒  ██▒▓██░   █▒▓██▒▓██▒▀█▀ ██▒
▓██  ▀█ ██▒▒███   ▒██░  ██▒ ▓██  █▒░▒██▒▓██    ▓██░
▓██▒  ▐▌██▒▒▓█  ▄ ▒██   ██░  ▒██ █░░░██░▒██    ▒██ 
▒██░   ▓██░░▒████▒░ ████▓▒░   ▒▀█░  ░██░▒██▒   ░██▒
░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒░▒░▒░    ░ ▐░  ░▓  ░ ▒░   ░  ░
░ ░░   ░ ▒░ ░ ░  ░  ░ ▒ ▒░    ░ ░░   ▒ ░░  ░      ░
   ░   ░ ░    ░   ░ ░ ░ ▒       ░░   ▒ ░░      ░   
         ░    ░  ░    ░ ░        ░   ░         ░   
                                ░                  
          ]],
          keys = {
            { icon = "󰍉 ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            {
              icon = " ",
              key = "F",
              desc = "Find Folder",
              action = ":lua require('user.utils.folder-pick').pick_folder_in()",
            },
            { icon = "󰗧 ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            {
              icon = " ",
              key = "c",
              desc = "Config",
              action = ":lua require('user.utils.folder-pick').pick_folder_in('" .. confDir:gsub("'", "\\'") .. "')",
            },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = "󰩈 ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        -- Build the panels list dynamically.
        sections = function()
          local width = vim.o.columns
          local is_narrow = width < 60 * 2

          local function split_path(str)
            local parts = {}
            for part in string.gmatch(str, "[^/]+") do
                table.insert(parts, part)
            end

            if #parts == 0 then
                return nil, nil
            end
            local a = table.concat(parts, "/", 1, #parts - 1) -- All but the last part
            local b = parts[#parts] -- Last part
            return a, b
          end

          local widePanels = {
            {
              {
                section = "terminal",
                cmd = "sh " .. vim.fn.stdpath('config') .. "/pipes.sh",
                height = 15,
                padding = 1,
              },
            },
            {
              { section = "header" },
              { section = "keys", gap = 1, padding = 1 },
              { section = "startup", padding = 1 },
            },
            {
              icon = " ",
              title = "Recent Files",
              section = "recent_files",
              indent = 2,
            },
          }

          local panels = {}
          if is_narrow then
            panels = { table.move(widePanels, 2, #widePanels, 1, {}) }
          else
            panels = widePanels
          end

          for idx, panel in ipairs(panels) do
            panel.pane = idx
          end
          return panels
        end,
      },
    },
  },
}

