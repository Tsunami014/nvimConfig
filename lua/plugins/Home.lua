---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    opts = {
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
            { icon = " ", key = "p", desc = "Projects", action = ":Telescope projects" },
            { icon = "󰗧 ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            {
              icon = " ",
              key = "c",
              desc = "Config",
              action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
            },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = "󰩈 ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        -- Build the panels list dynamically.
        sections = function()
          local width = vim.api.nvim_get_option "columns"
          local is_narrow = width < 80 * 2.5

          -- Use the globally loaded projects (defaults to empty table)
          local project_list = _G.recent_projects or {}
          local items = {}
          for i, project in ipairs(project_list) do
            if i > 5 then break end
            table.insert(items, {
              icon = i,
              text = { { string.format("%d. %s", i, project), hl = "SnacksDashboardDesc" } },
              action = ':echo "' .. project .. '"',
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

          local widePanels = {
            {
              {
                section = "terminal",
                cmd = [[cbonsai -li -t 0.001 -w 2 -c "&,O,#,uwu"]],
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
                icon = " ",
                title = "Projects",
                indent = 2,
                padding = 0,
              },
            }, items, {
              {
                icon = "\n ",
                title = "\nRecent Files",
                section = "recent_files",
                indent = 2,
                padding = { top = 1, bottom = 1 },
              },
            }),
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

