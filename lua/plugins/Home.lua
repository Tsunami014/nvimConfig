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
            {
              icon = " ",
              key = "p",
              desc = "Projects",
              action = function()
                local ok, pickers = pcall(require, "telescope.pickers")
                if not ok then
                  vim.notify("Telescope not found!", vim.log.levels.ERROR)
                  return
                end

                local finders = require("telescope.finders")
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")
                local conf = require("telescope.config").values

                -- Get a list of projects from project.nvim (adjust if your function is different)
                local projects = require("project_nvim").get_recent_projects()
                if not projects or vim.tbl_isempty(projects) then
                  vim.notify("No projects found!", vim.log.levels.WARN)
                  return
                end

                pickers.new({}, {
                  prompt_title = "Projects",
                  finder = finders.new_table {
                    results = projects,
                  },
                  sorter = conf.generic_sorter({}),
                  attach_mappings = function(prompt_bufnr, map)
                    actions.select_default:replace(function()
                      local selection = action_state.get_selected_entry()
                      actions.close(prompt_bufnr)
                      _G.loadProject(selection.value)
                    end)
                    return true
                  end,
                }):find()
              end,
            },
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

          -- Use the globally loaded projects (defaults to empty table)
          local project_list = _G.recent_projects or {}
          local items = {}
          for i, project in ipairs(project_list) do
            if i > 5 then break end
            local pth, ext = split_path(project)
            table.insert(items, {
              text = { { string.format("  %i  ", i), hl = "SnacksDashboardKey" }, { pth .. "/", hl = "Conceal" }, { ext, hl = "SnacksDashboardDesc" } },
              action = ':lua loadProject("' .. project .. '")',
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
                section = "terminal",
                cmd = "chafa ~/.config/nvim/wall.png --format symbols --symbols vhalf --size 60x17 --stretch; sleep .1",
                height = 17,
                padding = 1,
              },
              {
                icon = " ",
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

