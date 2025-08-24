return {
  -- Wakatime - for keeping track of time spent coding
  { 'wakatime/vim-wakatime', lazy = false },

  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim', "scottmckendry/pick-resession.nvim" },
    config = function()
        require("telescope").setup({
            extensions = {
                resession = {
                    prompt_title = "Find Sessions",
                    dir = "session", -- directory where resession stores sessions
                },
            },
        })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = 'master',
    lazy = false,
    build = ":TSUpdate"
  },
  {
    'stevearc/resession.nvim',
    opts = {
      load_order = "modification_time",
      autosave = {
        enabled = true,
        interval = 60,
        notify = false,
      },
    },
  },
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    opts = {},
  },
  {
    "romgrk/barbar.nvim",
    requires = "kyazdani42/nvim-web-devicons",  -- for icons
    config = function()
      require("bufferline").setup {
        animation = true, -- Smooth transitions
        auto_hide = false, -- Never hide the bufferline
        tabpages = true, -- Show tabpages
        icons = { filetype = { enabled = true } }
      }
    end
  },
  {
    "kdheepak/lazygit.nvim",
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      -- LSP source
      "hrsh7th/cmp-nvim-lsp",
      -- Buffer source
      "hrsh7th/cmp-buffer",
      -- Path source
      "hrsh7th/cmp-path",
      -- Cmdline source
      "hrsh7th/cmp-cmdline",
      -- nvim-lua source
      "hrsh7th/cmp-nvim-lua",
      -- Mason sources (for LSP support)
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local cmp = require("cmp")

      -- Setup nvim-cmp for insert mode
      cmp.setup({
        sources = {
          { name = "nvim_lsp" },
          { name = "buffer" },
          { name = "path" },
          { name = "nvim_lua" },
          per_filetype = {
            codecompanion = { "codecompanion" },
          }
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })

      -- Setup cmdline completion for ":" (commands)
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "path" },
          { name = "cmdline" },
        },
      })

      -- Setup cmdline completion for "/" (search in files)
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })
    end,
  }
}
