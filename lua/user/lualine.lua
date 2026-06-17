local function hide_when_med()
  return vim.fn.winwidth(0) > 50
end
local function hide_when_short()
  return vim.fn.winwidth(0) > 70
end

local icons = {
  -- Runes
  'ᚠ', 'ᚢ', 'ᚣ', 'ᚤ', 'ᚥ', 'ᚦ', 'ᚧ', 'ᚨ', 'ᚩ', 'ᚫ', 'ᚬ', 'ᚭ',
  'ᚮ', 'ᚯ', 'ᚰ', 'ᚱ', 'ᚲ', 'ᚳ', 'ᚴ', 'ᚵ', 'ᚷ', 'ᚸ', 'ᚹ', 'ᚺ', 'ᚻ',
  'ᚼ', 'ᚾ', 'ᚿ', 'ᛁ', 'ᛂ', 'ᛃ', 'ᛄ', 'ᛅ', 'ᛆ', 'ᛇ', 'ᛈ', 'ᛉ',
  'ᛊ', 'ᛋ', 'ᛌ', 'ᛍ', 'ᛎ', 'ᛏ', 'ᛐ', 'ᛒ', 'ᛓ', 'ᛗ',
  'ᛘ', 'ᛚ', 'ᛛ', 'ᛜ', 'ᛝ', 'ᛞ', 'ᛟ', 'ᛠ', 'ᛡ', 'ᛢ', 'ᛣ', 'ᛤ', 'ᛥ',
  'ᛦ', 'ᛨ', 'ᛩ', 'ᛪ', 'ᛮ', 'ᛯ', 'ᛰ', 'ᛳ', 'ᛵ', 'ᛶ', 'ᛷ',
  -- Waves
  '≈', '∿', '≋', '≀', '≣', '⌇',
  -- Crosses
  '☨', '♰', '', '✠', '⌀',
  -- Nature
  '☾', '☽', '☼', '❉', '♧',
  -- Stars
  '★', '☆', '✧', '✦', '✶', '✷', '✸', '✹', '⛧',
  -- Shapes
  '▵', '⋄', '⛋','❤', '♥',
  -- Misc symbols
  '᛫', '᛬', 'ː', '𖤐', '₸', '⟛', 'þ', 'ð', '∑', 'ⴵ'
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
      { "filename", file_status = false, path = 1, cond = hide_when_med },
    },
    lualine_c = { { function() return get_runes(4, 0) end, color = "CursorLineNr", cond = hide_when_short } },
    lualine_x = { { function() return get_runes(4, 1) end, color = "CursorLineNr", cond = hide_when_short } },
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
    lualine_b = { { "filename", file_status = false, path = 0, cond = hide_when_med, } },
    lualine_c = {},
    lualine_x = { "filetype" },
    lualine_y = { { "%l:%c", separator = {} }, "%p%%/%L" },
    lualine_z = {}
  },
}
