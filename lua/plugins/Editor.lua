return {
  -- File system viewer
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          never_show = { ".git", "package-lock.json" },
        },
      },
    },
  },

  -- You can probably *guess* what this does
  {
    'nmac427/guess-indent.nvim',
    lazy = false,
    config = function() require('guess-indent').setup {} end,
  },

  -- Auto complete brackets and things
  {
    "cohama/lexima.vim",
  },

  -- Keybindings popup
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts_extend = { "spec" },
    opts = {
      preset = "helix",
    },
  },

  -- git signs highlights text that has changed since the list
  -- git commit, and also lets you interactively stage & unstage
  -- hunks in a commit.
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      signs_staged = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
      },
    },
  },

  -- find and replace
  {
    "roobert/search-replace.nvim",
    config = function()
      require("search-replace").setup({})
    end,
  },

  -- better diagnostics list and others
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {
      modes = {
        lsp = {
          win = { position = "right" },
        },
      },
    },
  },

  -- Finds and lists all of the TODO, HACK, BUG, etc comment
  -- in your project and loads them into a browsable list.
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = "VeryLazy",
    opts = {},
  },

  -- Venv selector
  {
    "linux-cultist/venv-selector.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-dap",
      "mfussenegger/nvim-dap-python",
      { "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
    },
    lazy = false,
    opts = {
    },
  },

  -- Autosave
  {
    'pocco81/auto-save.nvim',
    lazy = false,
    opts = {
      execution_message = {
		    message = "",
		    dim = 0.08,
		    cleaning_interval = 10,
	    },
    },
  },

  -- DOcstring GEnerator
  {
    {
      "kkoomen/vim-doge",
      lazy = false,
      build = ":call doge#install()",
      init = function()
        vim.g.doge_doc_standard_python = "google"
      end,
    },
  },
}
