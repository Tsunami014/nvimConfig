local starter = require('mini.starter')
local LEFT_SECTIONS = {
  ['Open'] = true,
  ['Actions'] = true,
}
local MIN_WIDTH = 90
local GAP = 6

local function block_width(lines)
  local w = 0
  for _, line in ipairs(lines) do
    local s = table.concat(vim.tbl_map(function(u) return u.string end, line))
    w = math.max(w, vim.fn.strdisplaywidth(s))
  end
  return w
end

local function line_kind(line)
  local header, footer, item_unit, section_unit
  for _, u in ipairs(line) do
    if u.type == 'header' then header = u
    elseif u.type == 'footer' then footer = u
    elseif u.type == 'item' then item_unit = item_unit or u
    elseif u.type == 'section' then section_unit = section_unit or u
    end
  end
  if header then return 'header' end
  if footer then return 'footer' end
  if item_unit then return 'item', item_unit.item.section end
  if section_unit then return 'section', section_unit.string end
  return nil
end

local function vcenter(lines, target_h)
  local diff = target_h - #lines
  if diff <= 0 then return lines end
  local top = math.floor(diff / 2)
  local bottom = diff - top
  local out = {}
  for _ = 1, top do table.insert(out, { { type = 'empty', string = '' } }) end
  vim.list_extend(out, lines)
  for _ = 1, bottom do table.insert(out, { { type = 'empty', string = '' } }) end
  return out
end

local function indent_line(line, pad)
  if pad <= 0 then return line end
  local new_line = { { type = 'empty', string = string.rep(' ', pad) } }
  vim.list_extend(new_line, line)
  return new_line
end

local function center_block(lines, width, height)
  local w = block_width(lines)
  local hpad = math.max(0, math.floor((width - w) / 2))
  local out = {}
  for _, line in ipairs(lines) do
    table.insert(out, indent_line(line, hpad))
  end

  local diff = height - #out
  if diff > 0 then
    local top, bottom = math.floor(diff / 2), diff - math.floor(diff / 2)
    local final = {}
    for _ = 1, top do table.insert(final, { { type = 'empty', string = '' } }) end
    vim.list_extend(final, out)
    for _ = 1, bottom do table.insert(final, { { type = 'empty', string = '' } }) end
    return final
  end
  return out
end

local two_column_hook = function(content, buf_id)
  local win_id = vim.fn.bufwinid(buf_id)
  local width = win_id ~= -1 and vim.api.nvim_win_get_width(win_id) or vim.o.columns
  local height = win_id ~= -1 and vim.api.nvim_win_get_height(win_id) or vim.o.lines

  local left, right_body, right_footer = {}, {}, {}
  for _, line in ipairs(content) do
    if #line > 0 then
      local kind, name = line_kind(line)
      if kind == 'header' then
        table.insert(left, line)
      elseif kind == 'footer' then
        table.insert(right_footer, line)
      elseif (kind == 'item' or kind == 'section') and LEFT_SECTIONS[name] then
        table.insert(left, line)
      elseif kind ~= nil then
        table.insert(right_body, line)
      end
    end
  end

  -- one blank row between the last group and the footer, right column only
  local right = {}
  vim.list_extend(right, right_body)
  if #right_footer > 0 then
    table.insert(right, { { type = 'empty', string = '' } })
    vim.list_extend(right, right_footer)
  end

  if width < MIN_WIDTH then
    local single = {}
    vim.list_extend(single, left)
    table.insert(single, { { type = 'empty', string = '' } })
    vim.list_extend(single, right)
    return center_block(single, width, height)
  end

  local left_w = block_width(left)
  local n = math.max(#left, #right)
  left = vcenter(left, n)
  right = vcenter(right, n)

  local merged = {}
  for i = 1, n do
    local l, r = left[i], right[i]
    local l_str = table.concat(vim.tbl_map(function(u) return u.string end, l))
    local pad = string.rep(' ', left_w - vim.fn.strdisplaywidth(l_str) + GAP)

    local new_line = {}
    vim.list_extend(new_line, l)
    table.insert(new_line, { type = 'empty', string = pad })
    vim.list_extend(new_line, r)
    table.insert(merged, new_line)
  end
  return center_block(merged, width, height)
end

local foldp = require('user.utils.folder-pick')
starter.setup({
  header = [[
                  ▄▄▓█
                ▄▓▀░▒▓▄
 ▄▄           ▄▓▓▀    █
█▒▒█▀▀▄▄   ▄▄▄▓▒▓▄  ▒░██▄▄▄▄▄
█▒░ ▀▀▓▒▓▓▓▒▒▒▒▒▒▒▓▒▒▓▓▓▒▒▒▒▒▓▓▄
 █░   █▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▒▒▒▒▒▒▒▒▓▓▄
 █▒░ ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▀▓▒▒▒▒▒▒▒▒▒▒█
  █▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓░  █▒▒▒▓▓▓▓▒▒▒▒█
  ▀▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒█    █▓▓▓▒▒▒▒▒▒▒▒█
   ▀▓█░▒▒▒▒▒▒▒▒▒▒▒▒▓  ▄▓▒▒▒▒▒▒▒▒▒▒▒▒▒█
     █  ░▀▀▀▓▓▒▒▒▒▒  █░░░▒░░░░▒▒▒▒▒▒▓▀
      ▀▄          ▀▄▓█ ░     ▒░▒▒▒▒▒█
        ▀▀▀█▓▀▀▀█▓▓▒▒█          ▒▒▓▀
           █▒▒▄█▒▒▒▓▀█         ░▓▀
            ▀▀▀▓▓▓▀  █     ▄▄▄▀▀
                      █▄▄▀▀
  ]],

  evaluate_single = true,
  items = {
    { name = "New", action = function() starter.close() vim.cmd('startinsert') end, section = "Open" },
    { name = "Files", action = ":Telescope find_files", section = "Open" },
    { name = "Folders", action = foldp.pick_folder_in, section = "Open" },
    { name = "Config", action = function() foldp.pick_folder_in(confDir) end, section = "Open" },
    { name = "Recent", action = MiniExtra.pickers.oldfiles, section = "Open" },
    { name = "Text", action = ":Telescope live_grep", section = "Open" },
    { name = "Lazy", action = ":Lazy", section = "Actions" },
    starter.sections.recent_files(10, false),
  },
  content_hooks = {
    starter.gen_hook.adding_bullet(),
    starter.gen_hook.indexing('all', { 'Open', 'Actions' }),
    two_column_hook,
    starter.gen_hook.padding(2, 0),
  },
})
