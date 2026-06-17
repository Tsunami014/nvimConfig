local function hide_when_short()
  return vim.fn.winwidth(0) > 80
end

local icons = {
  -- Stars
  '★', '☆', '✧', '✦', '✶', '✷', '✸', '✹',
  -- Runes
  'ᛟ', 'ᚨ', 'ᚱ', 'ᚷ', 'ᚲ', 'ᚠ', 'ᛉ', 'ᚹ', 'ᚦ', 'ᚢ', 'ᛊ', 'ᚺ', 'ᛏ',
  -- Waves
  '≈', '∿', '≋', '≀', '≣', '⌇',
  -- Crosses
  '☨', '♰', '', '✠', '⌀',
  -- Sky objects
  '☾', '☽', '☼',
  -- Misc symbols
  '❤', '♥', '⛧', '𖤐',
}
local function get_runes(count, xtra)
  local buf = vim.api.nvim_get_current_buf()
  local pid = vim.fn.getpid()
  math.randomseed(buf + pid + (xtra or 0))
  local s = {}
  for i = 1, count do
    s[#s+1] = icons[math.random(#icons)]
  end
  return table.concat(s, " ")
end

require("lualine").setup {
  options = {
    section_separators = { left = '', right = '' },
    component_separators = { left = '', right = '' },
    --component_separators = { left = '', right = '' }
  },

  sections = {
    lualine_a = { {"mode", separator={ left = '', right = '' }} },
    lualine_b = {
      "diff",
      { "diagnostics", sources = { "nvim_diagnostic" } },
      { "filename", file_status = false, path = 1, cond = hide_when_short },
    },
    lualine_c = { { function() return get_runes(2, 1) end, color = "CursorLineNr" } },
    lualine_x = { { function() return get_runes(2, 2) end, color = "CursorLineNr" } },
    lualine_y = { "filetype" },
    lualine_z = {
      { "%l:%c", separator={ left = ""} },
      {
        function() return "" end,
        padding = 0, separator={}
      },
      { "%p%%/%L", separator={ right = "" } },
    }
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = { { "filename", file_status = false, path = 0, cond = hide_when_short, } },
    lualine_c = {},
    lualine_x = { "filetype" },
    lualine_y = { { "%l:%c", separator = {} }, "%p%%/%L" },
    lualine_z = {}
  },
}
