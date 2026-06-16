local function hex(n)
  return n and string.format("#%06x", n) or nil
end

local function hl(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok then return {} end
  return { fg = hex(h.fg), bg = hex(h.bg) }
end

local function pick(...)
  for i = 1, select("#", ...) do
    local h = hl(select(i, ...))
    if h.fg or h.bg then return h end
  end
  return {}
end

require("lualine").setup {
  options = {
    component_separators = "",
    section_separators = { left = "", right = "" },
  },

  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      "diff",
      { "diagnostics", sources = { "nvim_diagnostic" } },
      { "filename", file_status = false, path = 1 },
    },
    lualine_c = {},
    lualine_x = {},
    lualine_y = { "filetype" },
    lualine_z = { "%l:%c", "%p%%/%L" },
  },

  inactive_sections = {
    lualine_c = { "%f %y %m" },
    lualine_x = {},
  },
}
