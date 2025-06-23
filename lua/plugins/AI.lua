local ok, secrets = pcall(require, "lua.user.secrets")
if not ok then
  vim.notify(
    "[codecompanion] secrets.lua not found. Skipping API key setup.",
    vim.log.levels.WARN
  )
  secrets = {}  -- fallback to empty table
end

return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("codecompanion").setup({
      display = {
        chat = {
          show_settings         = true,
          show_header_separator = true,
        },
      },


      adapters = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = { api_key = secrets.OPENAI_API_KEY },
            schema = { model = { default = "gpt-4" } },
          })
        end,

        ollama = function()
          return require("codecompanion.adapters").extend("ollama", {})
        end,

        copilot = function()
          return require("codecompanion.adapters").extend("copilot", {})
        end,

        gemini = function()
          return require("codecompanion.adapters").extend("gemini", {
            env = { api_key = secrets.GEMINI_API_KEY },
            schema = { model = { default = "gemini-1.5-flash" } },
          })
        end,

        deepseek = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            env = {
              url     = "https://api.deepseek.com/v1",
              api_key = secrets.DEEPSEEK_API_KEY,
            },
            schema = { model = { default = "deepseek-chat" } },
          })
        end,
      },

      strategies = {
        -- you can still default to openai if you have the key,
        -- or pick whatever you like as your “first” provider
        chat   = { adapter = secrets.OPENAI_API_KEY and "openai"   or "ollama" },
        inline = { adapter = secrets.OPENAI_API_KEY and "openai"   or "ollama" },
        agent  = { adapter = secrets.OPENAI_API_KEY and "openai"   or "ollama" },
      },
    })
    local cc_cfg = require("codecompanion.config")

    -- 3) Define your custom “choose provider → choose model” picker:
    vim.keymap.set("n", "<leader>cp", function()
      -- your hard-coded whitelist (just keys from cc_cfg.adapters)
      local whitelist = { "openai", "anthropic" }

      -- build the list of actually available providers
      local providers = {}
      for _, name in ipairs(whitelist) do
        if cc_cfg.adapters[name] then
          table.insert(providers, name)
        end
      end

      -- pick a provider
      vim.ui.select(providers, { prompt = "Choose AI provider" }, function(provider)
        if not provider then return end

        -- pick a model from that provider
        local adapter = cc_cfg.adapters[provider]()
        local schema = adapter.schema or {}
        local model_field = schema.model or {}

        -- get list of model choices
        local models = model_field.choices or {}
        if #models == 0 and model_field.default then
          models = { model_field.default }
        end
        vim.ui.select(models, { prompt = provider .. " model" }, function(model)
          if not model then return end

          vim.g.codecompanion_adapter = provider
          vim.g.codecompanion_model   = model

          vim.cmd("CodeCompanionChat")
        end)
      end)
    end, { desc = "⟡ CodeCompanion: pick whitelisted provider + model" })
  end
}
