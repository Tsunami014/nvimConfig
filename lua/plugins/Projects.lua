return {
  {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
    config = function()
      require("project_nvim").setup {
        manual_mode = false, -- Automatically detect projects
        detection_methods = { "pattern" }, -- Use patterns to detect projects
        patterns = { ".git", "Makefile", "package.json" }, -- Customize patterns
        show_hidden = true,
        }
    end,
  },
}
