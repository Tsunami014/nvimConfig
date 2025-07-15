local profile = require("profile").current

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
      input = { enabled = true },
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
              action = ":lua require('user.folder-pick').pick_folder_in()",
            },
            {
              icon = " ",
              key = "p",
              desc = "Projects",
              action = require("project").findProjects,
            },
            { icon = "󰗧 ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            {
              icon = " ",
              key = "c",
              desc = "Config",
              action = ":lua require('user.folder-pick').pick_folder_in('" .. confDir:gsub("'", "\\'") .. "')",
            },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = "󰩈 ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        -- Build the panels list dynamically.
        sections = function()
          local width = vim.o.columns
          local is_narrow = width < 78 * 2.5

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

          local project_list = require("project").projects
          local items = {}

          for i, project in ipairs(project_list) do
            if i > 5 then break end
            local pth, ext = split_path(project)
            table.insert(items, {
              text = {
                { string.format("  %i  ", i), hl = "SnacksDashboardKey" },
                { pth .. "/", hl = "Conceal" },
                { ext, hl = "SnacksDashboardDesc" },
              },
              action = ':lua require("project").loadProject("' .. project .. '")',
              key = tostring(i),
            })
          end

          local function mergeThree(t1, t2, t3)
            local result = {}
            for _, v in ipairs(t1) do table.insert(result, v) end
            for _, v in ipairs(t2) do table.insert(result, v) end
            for _, v in ipairs(t3) do table.insert(result, v) end
            return result
          end

          local tCmd = [[cbonsai -li -t 0.001 -w 2 -c "&,O,#,uwu"]]
          if profile == "Windows" then
            tCmd = ""
          end

          local widePanels = {
            {
              {
                section = "terminal",
                cmd = tCmd,
                height = 30,
                padding = 1,
              },
            },
            {
              { section = "header" },
              { section = "keys", gap = 1, padding = 1 },
              { section = "startup", padding = 1 },
            },
            mergeThree({
              {
                icon = "󰉓 ",
                title = "Projects",
                padding = 0,
              },
            }, items, {
              {
                text = { { "" } },
                indent = 0,
                padding = 0,
              },
              {
                icon = " ",
                title = "Recent Files",
                section = "recent_files",
                indent = 2,
              },
            })
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

