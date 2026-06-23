local statlne = require('mini.statusline')

local slant = { left = '', right = '' }
local bubble = { left = '', right = '' }
local triang = { left = '', right = '' }
local arrow = { left = '', right = '' }
local line = { left = '╱', right = '╲' }

local diag_signs = {
  ERROR = '%#MiniStatuslineDevinfoError#!',
  WARN = '%#MiniStatuslineDevinfoWarn#*',
  INFO = '%#MiniStatuslineDevinfoInfo#@',
  HINT = '%#MiniStatuslineDevinfoHint#~',
}

local function ns(tbl)
  return '%#' .. tbl.hl .. '#' .. table.concat(tbl.strings, " ")
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
function get_runes(count, xtra)
  local buf = vim.api.nvim_get_current_buf()
  local pid = vim.fn.getpid()
  math.randomseed(buf + pid + (xtra or 0))
  local s = {}
  for i = 1, count do
    s[#s+1] = icons[math.random(#icons)]
  end
  return table.concat(s, " ")
end


local function get_hl(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function refresh_devinfo_fills()
  local bg = get_hl('MiniStatuslineDevinfo').bg
  local function fill(name, src)
    vim.api.nvim_set_hl(0, name, { fg = get_hl(src).fg, bg = bg })
  end
  fill('MiniStatuslineDevinfoError', 'DiagnosticError')
  fill('MiniStatuslineDevinfoWarn', 'DiagnosticWarn')
  fill('MiniStatuslineDevinfoInfo', 'DiagnosticInfo')
  fill('MiniStatuslineDevinfoHint', 'DiagnosticHint')
  fill('MiniStatuslineDevinfoAdd', 'MiniDiffSignAdd')
  fill('MiniStatuslineDevinfoChange', 'MiniDiffSignChange')
  fill('MiniStatuslineDevinfoDelete', 'MiniDiffSignDelete')
end
refresh_devinfo_fills()

local function fileinfo1()
  if statlne.is_truncated(95) or vim.bo.buftype ~= '' then return '' end
  local a = arr and (' ' .. arrow.right .. ' ') or ' '
  local size = math.max(vim.fn.line2byte(vim.fn.line('$') + 1) - 1, 0)
  if size < 1024 then
    return size .. 'B'
  elseif size < 1048576 then
    return string.format('%.2fKiB', size / 1024)
  else
    return string.format('%.2fMiB', size / 1048576)
  end
end
local function fileinfo2()
  local ft = vim.bo.filetype
  if ft == '' then return '[Blank]' end
  local ico = require('mini.icons').get('filetype', ft)
  if statlne.is_truncated(60) then return ico end
  return ico .. ' ' .. ft
end


local modes = {
  "MiniStatuslineModeReplace",
  "MiniStatuslineModeCommand",
  "MiniStatuslineModeInsert",
  "MiniStatuslineModeOther",
  "MiniStatuslineModeNormal",
  "MiniStatuslineModeVisual",
}
local mode_idx = {}
for i, mode in ipairs(modes) do
  if mode ~= "" then
    mode_idx[mode] = i
  end
end
local colours = {
  "RainbowDelimiterRed",
  "RainbowDelimiterYellow",
  "RainbowDelimiterGreen",
  "RainbowDelimiterCyan",
  "RainbowDelimiterBlue",
  "RainbowDelimiterViolet",
}

local decors = {
  { mid = true,
    next = true,
    inv = true,
    bold = true,
  },
  { mid = true,
    bgmid = true,
  },
  { space = true,
    bold = true,
  },
  { mid = true,
    bgmid = true,
    next = true,
    colsep = true,
  },
  { next = true,
    nxtinv = true,
  },
  { next = true,
    nxtinv = true,
    inv = true,
    bold = true,
  },
}
local last = ""
local function redecorate(mode_hl)
    local idx = mode_idx[mode_hl]
    local function rotate()
      local out = colours[idx]
      idx = (idx % #colours) + 1
      return out
    end
    local function gen(name, fg, bg, dec, skipinv, isnxt)
      local info
      if ((not skipinv) and dec.inv) or (isnxt and dec.nxtinv) then
        info = { fg = bg, bg = fg }
      else
        info = { fg = fg, bg = bg }
      end
      info.bold = dec.bold
      vim.api.nvim_set_hl(0, name, info)
    end
    local norm = get_hl('Normal').bg
    local reg = get_hl('MiniStatuslineFileinfo').bg
    for index, dec in ipairs(decors) do
      local name = 'Status_' .. index
      local col = get_hl(rotate()).fg
      if dec.mid then
        local cur
        if dec.bgmid then cur = reg
        else cur = col
        end
        gen(name .. '_Mid', cur, norm, dec, true)
      end
      if dec.next then
        local nxti = (index % #colours) + 1
        local cur
        if not (dec.inv or dec.colsep) then cur = reg
        else cur = col
        end
        local nxt
        if not decors[nxti].inv then nxt = reg
        else nxt = get_hl(colours[idx]).fg
        end
        gen(name .. '_' .. nxti, cur, nxt, dec, true, true)
      end
      if dec.space then
        gen(name, col, norm, dec)
      else
        gen(name, col, reg, dec)
      end
    end
end
vim.api.nvim_create_autocmd('ColorScheme', { callback = function() refresh_devinfo_fills(); last = "" end })

local inactivehl = 'InactiveStatusLine'
local frhl = get_hl('Normal')
vim.api.nvim_set_hl(0, inactivehl, { fg = get_hl('MiniStatuslineDevinfo').bg, bg = frhl.bg, bold = frhl.bold })
statlne.setup({ content = {
  active = function()
    local mode, mode_hl = statlne.section_mode({ trunc_width = 70 })
    if mode_hl ~= last then
      redecorate(mode_hl)
      last = mode_hl
    end

    local diff = statlne.is_truncated(65) and '' or (vim.b.minidiff_summary_string or '')
    local diagn = statlne.section_diagnostics({ trunc_width = 60, icon = '', signs = diag_signs })
    local devinf
    local arr = true
    if diff ~= '' and diagn ~= '' then
      devinf = diff, arr.left, diagn
    elseif diff ~= '' or diagn ~= '' then
      devinf = (diff ~= '' and diff or diagn)
    else
      devinf = ''
      arr = false
    end

    local filename = statlne.is_truncated(90) and '%f' or '%F'
    local fi1 = fileinfo1()

    return statlne.combine_groups({
      ns({ hl = 'Status_1_Mid', strings = { bubble.left } }),
      { hl = 'Status_1', strings = { mode } },
      ns({ hl = 'Status_1_2', strings = { triang.right } }),
      { hl = 'Status_2', strings = { devinf } },
      { hl = 'Status_2', strings = { arr and arrow.right or '' } },
      '%<', -- Truncate
      { hl = 'Status_2', strings = { filename } },
      ns({ hl = 'Status_2_Mid', strings = { slant.left } }),
      '%=', -- Pad
      { hl = 'Status_3', strings = { get_runes(statlne.is_truncated(50) and 2 or (statlne.is_truncated(65) and 3 or (statlne.is_truncated(80) and 4 or 6))) } },
      '%=', -- Pad
      ns({ hl = 'Status_4_Mid', strings = { slant.right } }),
      { hl = 'Status_4', strings = { fi1 } },
      ns({ hl = 'Status_4_5', strings = { fi1 == "" and line.left or arrow.left } }),
      { hl = 'Status_5', strings = { fileinfo2() } },
      ns({ hl = 'Status_5_6', strings = { triang.left } }),
      { hl = 'Status_6', strings = { '%l:%c' } },
      ns({ hl = 'Status_6_1', strings = { triang.left } }),
      { hl = 'Status_1', strings = { statlne.is_truncated(30) and '' or '%p%%/%L' } },
      ns({ hl = 'Status_1_Mid', strings = { bubble.right } }),
    })
  end,
  inactive = function()
    local filename = statlne.is_truncated(90) and '%f' or '%F'

    return statlne.combine_groups({
      { hl = inactivehl, strings = { filename } },
      '%=', -- Pad
      { hl = inactivehl, strings = { fileinfo1(), fileinfo2() } },
      { hl = inactivehl, strings = { '%l:%c' .. (statlne.is_truncated(20) and '' or ' %p%%/%L') } },
    })
  end,
}})

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniDiffUpdated',
  callback = function(data)
    local summary = vim.b[data.buf].minidiff_summary
    if summary == nil then return end

    local t = {}
    if summary.add > 0 then table.insert(t, '%#MiniStatuslineDevinfoAdd#+' .. summary.add) end
    if summary.change > 0 then table.insert(t, '%#MiniStatuslineDevinfoChange#~' .. summary.change) end
    if summary.delete > 0 then table.insert(t, '%#MiniStatuslineDevinfoDelete#-' .. summary.delete) end

    local str = table.concat(t, ' ')
    if str ~= '' then str = str .. '%#MiniStatuslineDevinfo#' end
    vim.b[data.buf].minidiff_summary_string = str
  end,
})
