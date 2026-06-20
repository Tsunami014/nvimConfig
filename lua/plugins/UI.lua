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

  -- Search in a nice bubble
  {
    'VonHeikemen/searchbox.nvim',
    requires = {
      {'MunifTanjim/nui.nvim'}
    }
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
      -- Get rid of messages (interferes with ! commands)
      messages = { enabled = false },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
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
      presets = {
        bottom_search = true,
        command_palette = true,
      },
    },
  },

  -- statusline
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   event = "VeryLazy",
  --   dependencies = { "nvim-tree/nvim-web-devicons" },
  --   init = function()
  --     vim.g.lualine_laststatus = vim.o.laststatus
  --     if vim.fn.argc(-1) > 0 then
  --       -- set an empty statusline till lualine loads
  --       vim.o.statusline = " "
  --     else
  --       -- hide the statusline on the starter page
  --       vim.o.laststatus = 0
  --     end
  --   end,
  -- },

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
