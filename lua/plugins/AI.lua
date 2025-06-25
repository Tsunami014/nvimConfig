local ok, secrets = pcall(require, "lua.user.secrets")
if not ok then
  vim.schedule(
    function()
      vim.notify(
        "[codecompanion] secrets.lua not found. Skipping API key setup.",
        vim.log.levels.WARN
      )
    end)
  secrets = {}  -- fallback to empty table
end

return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("codecompanion").setup({
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
  end
}
