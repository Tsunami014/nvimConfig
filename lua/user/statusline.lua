local statlne = require('mini.statusline')

local slant = { left = '', right = '' }
local bubble = { left = '', right = '' }
local triang = { left = '', right = '' }
local arrow = { left = '', right = '' }
local clipping = { left = '', right = '' }

local diag_signs = {
  ERROR = '%#MiniStatuslineDevinfoError#',
  WARN = '%#MiniStatuslineDevinfoWarn#',
  INFO = '%#MiniStatuslineDevinfoInfo#',
  HINT = '%#MiniStatuslineDevinfoHint#󰌶',
}

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


local function file_size()
  local size = math.max(vim.fn.line2byte(vim.fn.line('$') + 1) - 1, 0)
  if size < 1024 then
    return size .. 'B'
  elseif size < 1048576 then
    return string.format('%.2fKiB', size / 1024)
  else
    return string.format('%.2fMiB', size / 1048576)
  end
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
vim.api.nvim_create_autocmd('ColorScheme', { callback = refresh_devinfo_fills })
refresh_devinfo_fills()

local function fileinfo(arr)
  local ft = vim.bo.filetype
  if ft == '' then return '[Blank]' end
  local ico = require('mini.icons').get('filetype', ft)
  if statlne.is_truncated(60) then return ico end
  local txt = ico .. ' ' .. ft
  if statlne.is_truncated(95) or vim.bo.buftype ~= '' then return txt end
  local a = arr and (' ' .. arrow.right .. ' ') or ' '
  return file_size() .. a .. txt
end

local function hlcat(from, to)
  local name = 'MiniStatuslineSep_' .. to .. '_' .. from
  local frhl = get_hl(from)
  vim.api.nvim_set_hl(0, name, { fg = get_hl(to).bg, bg = frhl.bg, bold = frhl.bold })
  return name
end
local function sep(from, to)
  return '%#' .. hlcat(from, to) .. '#'
end

statlne.setup({ content = {
  active = function()
    local mode, mode_hl = statlne.section_mode({ trunc_width = 70 })

    local diff = statlne.is_truncated(65) and '' or (vim.b.minidiff_summary_string or '')
    local diagn = statlne.section_diagnostics({ trunc_width = 60, icon = '', signs = diag_signs })
    local devinf
    local arr = sep('MiniStatuslineDevinfo', mode_hl) .. arrow.left
    if diff ~= '' and diagn ~= '' then
      devinf = { diff, arrow.left, diagn, arr }
    elseif diff ~= '' or diagn ~= '' then
      devinf = { (diff ~= '' and diff or diagn), arr }
    else
      devinf = {''}
    end

    local filename = statlne.is_truncated(90) and '%f' or '%F'

    return statlne.combine_groups({
      sep('Normal', mode_hl) .. bubble.left,
      { hl = mode_hl, strings = { mode } },
      sep('MiniStatuslineDevinfo', mode_hl) .. bubble.right,
      { hl = hlcat('MiniStatuslineDevinfo', mode_hl), strings = devinf },
      '%<', -- Truncate
      { hl = hlcat('MiniStatuslineDevinfo', mode_hl), strings = { filename } },
      sep('StatusLine', 'MiniStatuslineDevinfo') .. slant.left,
      '%=', -- Pad
      { hl = hlcat('Title', mode_hl), strings = { get_runes(statlne.is_truncated(50) and 2 or (statlne.is_truncated(65) and 3 or (statlne.is_truncated(80) and 4 or 6))) } },
      '%=', -- Pad
      sep('StatusLine', 'MiniStatuslineFileinfo') .. slant.right,
      { hl = hlcat('MiniStatuslineFileinfo', mode_hl), strings = { fileinfo(true) } },
      sep('MiniStatuslineFileinfo', mode_hl) .. triang.left,
      { hl = mode_hl, strings = { '%l:%c' .. (statlne.is_truncated(30) and '' or (' ' .. arrow.right .. ' %p%%/%L')) } },
      sep('Normal', mode_hl) .. triang.right,
    })
  end,
  inactive = function()
    local hl = hlcat('Normal', 'MiniStatuslineDevinfo')
    local filename = statlne.is_truncated(90) and '%f' or '%F'

    return statlne.combine_groups({
      { hl = hl, strings = { filename } },
      '%=', -- Pad
      { hl = hl, strings = { fileinfo(false) } },
      { hl = hl, strings = { '%l:%c' .. (statlne.is_truncated(30) and '' or ' %p%%/%L') } },
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
