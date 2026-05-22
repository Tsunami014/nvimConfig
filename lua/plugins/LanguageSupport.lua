
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
  {
    "jay-babu/mason-nvim-dap.nvim",
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
          "codelldb",

          -- install any other package
          "tree-sitter-cli",
        },
      automatic_installation = true,
      handlers = {}, -- use default handlers
    },
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
            ensure_installed = { "codelldb", "python", "js" },
            automatic_installation = true,
            handlers = {},
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

      -- Sample configuration for LLDB (Rust/C/C++)
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.exepath("codelldb"),
          args = { "--port", "${port}" },
        },
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
