local p = require("profile")

return {
  { "nvim-web-devicons" }, -- Icons
  -- Theme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
    cond = not p.OPTS.Notes
  },
  {
    "catppuccin/nvim", name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("catppuccin-frappe")
    end,
    cond = p.OPTS.Notes
  },

  -- Highlight colours (e.g. #2F34E2)
  {
    "brenoprata10/nvim-highlight-colors",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      render = "background", -- "foreground" | "first_column" | "background"
      enable_tailwind = true,
      custom_colors = {},    -- hex override table
    },
  },

  -- Notifications in nice bubbles
  {
    "rcarriga/nvim-notify",
    opts = {
      minimum_width = 30,
    }
  },

  -- Very Nice UI (experimental)
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      --"rcarriga/nvim-notify",
    },
    opts = {
      popupmenu = { enabled = false },
      messages = { enabled = false },
      cmdline = { enabled = false },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
      },
    },
  },

  {
    "gelguy/wilder.nvim",
    event = "CmdlineEnter",
    config = function()
      local wilder = require("wilder")

      wilder.setup({ modes = { ":", "/", "?" } })
      wilder.set_option("use_python_remote_plugin", 0) -- this kills the _wilder_python_* errors

      wilder.set_option("pipeline", {
        wilder.branch(
          wilder.cmdline_pipeline({ fuzzy = 0 }),
          wilder.vim_search_pipeline()
        ),
      })

      wilder.set_option("renderer", wilder.popupmenu_renderer(
        wilder.popupmenu_palette_theme({
          border = "rounded",
          highlights = { border = "Normal" },
          prompt_position = "top",  -- input line at the top of the box, list below it
          max_height = "30%",
          min_height = 0,
          reverse = 0,
        })
      ))
    end,
  },

  -- Rainbow brackets
  {
    "HiPhish/rainbow-delimiters.nvim",
    config = function()
      require("rainbow-delimiters.setup").setup {
        strategy = {
          [""] = "rainbow-delimiters.strategy.global",
          vim = "rainbow-delimiters.strategy.local",
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },
}
