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

local function hltxt(hl)
  return '%#' .. hl .. '#'
end
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
  "",
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
  "RainbowDelimiterOrange",
  "RainbowDelimiterYellow",
  "RainbowDelimiterGreen",
  "RainbowDelimiterCyan",
  "RainbowDelimiterBlue",
  "RainbowDelimiterViolet",
}

local decors = {
  { mid = true, next = true, inv = true, bold = true },
  { sepinv = true, next = true },
  { mid = true, bgmid = true },
  { space = true, bold = true },
  { mid = true, bgmid = true, next = true, colsep = true },
  { next = true, nxtinv = true },
  { next = true, nxtinv = true, inv = true, bold = true },
}

local last = ""

local function redecorate(mode_hl)
  local idx = mode_idx[mode_hl]

  local function rotate()
    local out = colours[idx]
    idx = (idx % #colours) + 1
    return out
  end

  local function gen(name, fg, bg, dec, skipinv, isnxt, nxtfg, donesepinv)
    local info = (((not skipinv) and dec.inv) or (isnxt and dec.nxtinv)) and
            { fg = bg, bg = fg } or { fg = fg, bg = bg }
    info.bold = dec.bold
    vim.api.nvim_set_hl(0, name, info)

    if dec.sepinv and not donesepinv then
      gen(name .. '_Inv', nxtfg or bg, fg, dec, skipinv, isnxt, nxtfg, true)
    end
  end

  local norm = get_hl('Normal').bg
  local reg = get_hl('MiniStatuslineFileinfo').bg

  for index, dec in ipairs(decors) do
    local name = 'Status_' .. index
    local col = get_hl(rotate()).fg

    if dec.mid then
      local mid_fg = dec.bgmid and reg or col
      gen(name .. '_Mid', mid_fg, norm, dec, true)
    end

    if dec.next then
      local nxti = (index % #colours) + 1

      local cur = (dec.inv or dec.colsep) and col or reg
      local invcol = (cur == reg) and col or reg

      local nxtcol = get_hl(colours[idx]).fg
      local nxt = decors[nxti].inv and nxtcol or reg

      gen(name .. '_' .. nxti, cur, nxt, dec, true, true, invcol)
      if decors[nxti].sepinv then
        local ninv_bg = (nxt == reg) and nxtcol or reg
        gen(name .. '_' .. nxti .. '_NInv', cur, ninv_bg, dec, true, true, invcol)
      end
    end

    gen(name, col, dec.space and norm or reg, dec)
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
    local devinf1 = ''; local devinf2 = ''
    local nodi = false
    local arrstart = hltxt('Status_2_Inv') .. triang.right
    if diff ~= '' and diagn ~= '' then
      devinf1 = diff
      devinf2 = arrstart .. hltxt('Status_2') .. triang.right .. diagn
    elseif diff ~= '' or diagn ~= '' then
      devinf1 = (diff ~= '' and diff or diagn)
    else
      nodi = true
    end

    local filename = statlne.is_truncated(90) and '%f' or '%F'
    local fi1 = fileinfo1()

    return statlne.combine_groups({
      ns({ hl = 'Status_1_Mid', strings = { bubble.left } }),
      { hl = 'Status_1', strings = { mode } },
      ns({ hl = 'Status_1_2' .. (nodi and '_NInv' or ''), strings = { triang.right } }),
      ns({ hl = 'Status_2', strings = { nodi and triang.right..' ' or '' } }),
      { hl = 'Status_2', strings = { devinf1 } },
      ns({ hl = 'Status_2', strings = { devinf2 } }),
      ns({ hl = 'Status_2', strings = { nodi and '' or ' ' .. arrstart } }),
      ns({ hl = 'Status_2_3_Inv', strings = { nodi and '' or triang.right..' ' } }),
      '%<', -- Truncate
      { hl = 'Status_3', strings = { filename } },
      ns({ hl = 'Status_3_Mid', strings = { slant.left } }),
      '%=', -- Pad
      { hl = 'Status_4', strings = { get_runes(statlne.is_truncated(50) and 2 or (statlne.is_truncated(65) and 3 or (statlne.is_truncated(80) and 4 or 6))) } },
      '%=', -- Pad
      ns({ hl = 'Status_5_Mid', strings = { slant.right } }),
      { hl = 'Status_5', strings = { fi1 } },
      ns({ hl = 'Status_5_6', strings = { fi1 == "" and line.left or arrow.left } }),
      { hl = 'Status_6', strings = { fileinfo2() } },
      ns({ hl = 'Status_6_7', strings = { triang.left } }),
      { hl = 'Status_7', strings = { '%l:%c' } },
      ns({ hl = 'Status_7_1', strings = { triang.left } }),
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
