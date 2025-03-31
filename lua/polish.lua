-- Delay loading the projects to give project_nvim time to initialize.
vim.defer_fn(function()
  _G.recent_projects = require("project_nvim").get_recent_projects() or {}
  require("snacks.dashboard").update()
end, 500)

if true then return end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- This will run last in the setup process and is a good place to configure
-- things like custom filetypes. This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Set up custom filetypes
vim.filetype.add {
  extension = {
    foo = "fooscript",
  },
  filename = {
    ["Foofile"] = "fooscript",
  },
  pattern = {
    ["~/%.config/foo/.*"] = "fooscript",
  },
}
