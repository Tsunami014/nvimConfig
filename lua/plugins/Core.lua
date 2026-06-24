local p = require("profile")

return {
  -- Wakatime - for keeping track of time spent coding
  {
    'wakatime/vim-wakatime',
    lazy = false,
    cond = p.OPTS.Full
  },

  {
    'nvim-telescope/telescope.nvim',
    branch = 'master',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = 'master',
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { "lua", "markdown", "markdown_inline", "python", "vim", "regex", 
            "bash", "yaml", "css", "html", "javascript", "latex", "tsx", "typst", "c", "cpp" },
      })
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    opts = {},
  },
  {
    "mbbill/undotree",
    lazy = true,
    cmd = "UndotreeToggle"
  },
  {
    "romgrk/barbar.nvim",
    requires = "kyazdani42/nvim-web-devicons",  -- for icons
    opts = {
      animation = true,
      auto_hide = false,
      tabpages = true,
      clickable = true,
      icons = {
        diagnostics = {
          [vim.diagnostic.severity.ERROR] = {enabled = true, icon = ''},
        },
        filetype = { enabled = true },
        inactive = { button = false },
        separator = { left = '▍', right = '' },
        modified = { button = '!' },
        pinned = { button = '', filename = false },
        button = '×',
      }
    }
  },
  {
    "kdheepak/lazygit.nvim",
  },
  {
    "actionshrimp/direnv.nvim",
    opts = {
      type = "dir",
      async = true,
      on_direnv_finished = function()
        vim.cmd("LspRestart")
      end
    }
  },
}
