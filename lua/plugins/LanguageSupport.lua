return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
  },
  -- The debugger
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- UI for DAP
      {
        "rcarriga/nvim-dap-ui",
        opts = {},
        config = function(_, opts)
          local dap = require("dap")
          local dapui = require("dapui")
          dapui.setup(opts)
          dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
          dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
          dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
        end,
        dependencies = { "nvim-neotest/nvim-nio" }
      },

      -- Virtual text (inline variable display)
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },

      -- Adapter management via Mason
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "williamboman/mason.nvim" },
        config = function()
          require("mason-nvim-dap").setup({
            dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
            opts = {
                ensure_installed = {
                  -- install language servers
                  "lua-language-server",
                  "ruff",
                  "pyright",
                  "clangd",

                  -- install formatters
                  "stylua",

                  -- install debuggers
                  "debugpy",
                  "cpptools",

                  -- install any other package
                  "tree-sitter-cli",
                },
              automatic_installation = true,
              handlers = {}, -- use default handlers
            },
          })
        end,
      },

      -- Completion integration for nvim-cmp
      {
        "rcarriga/cmp-dap",
        dependencies = { "hrsh7th/nvim-cmp" },
        config = function()
          require("cmp").setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
            sources = {
              { name = "dap" },
            },
          })
        end,
      },
    },
    config = function()
      local dap = require("dap")

      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin', 'OpenDebugAD7'),
      }
    end,
  },

  -- Vim latex integration
  {
    "lervag/vimtex",
    lazy = false,
    init = function()
      vim.g.vimtex_view_method = "sioyek"
      vim.g.vimtex_mappings_enabled = false
    end
  }
}
