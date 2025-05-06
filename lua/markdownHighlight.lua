local M = {}
local ns = vim.api.nvim_create_namespace("markdownHighlight")
local filetype = "markdown"

local heading_hl = {
  "@markup.heading.1.markdown",
  "@markup.heading.2.markdown",
  "@markup.heading.3.markdown",
  "@markup.heading.4.markdown",
  "@markup.heading.5.markdown",
  "@markup.heading.6.markdown",
}

-- Build progress bar based on percent and heading level
local function make_bar(percent, level)
  local parts = {}
  if level == 1 then
    parts[1] = percent >= 50 and "" or ""
  else
    for i = 1, level do
      local threshold = (i / level) * 100
      local is_full = percent >= threshold
      if i == 1 then
        parts[#parts+1] = is_full and "" or ""
      elseif i == level then
        parts[#parts+1] = is_full and "" or ""
      else
        parts[#parts+1] = is_full and "" or ""
      end
    end
  end
  return table.concat(parts)
end

-- Prepare the display text for a heading line
local function make_bar_line(idx, total, line)
  local hashes, text = string.match(line, "^(#+)%s*(.*)$")
  if not hashes then return end
  local level = #hashes
  local percent = math.floor((idx / total) * 100)
  local bar = make_bar(percent, level)
  return level, bar .. " " .. text
end

local function parse_md_links(line)
  local res        = {}
  local len        = #line
  local byte       = string.byte
  local stack_pos  = {}    -- numeric stack of '[' positions
  local stack_img  = {}    -- parallel stack: is it '!['?
  local stack_top  = 0
  local count      = 0
  local i          = 1

  while i <= len do
    local b = byte(line, i)
    if b == 33 and i < len and byte(line, i+1) == 91 then
      -- '![' opener
      stack_top = stack_top + 1
      stack_pos[stack_top] = i
      stack_img[stack_top] = true
      i = i + 2

    elseif b == 91 then
      -- '[' opener
      stack_top = stack_top + 1
      stack_pos[stack_top] = i
      stack_img[stack_top] = false
      i = i + 1

    elseif b == 93 and stack_top > 0 then
      -- ']' matched
      local start_pos = stack_pos[stack_top]
      local is_image  = stack_img[stack_top]
      stack_top = stack_top - 1

      -- only treat as link if it’s followed by '('
      if i < len and byte(line, i+1) == 40 then
        local j = i + 2
        -- find the next ')'
        while j <= len and byte(line, j) ~= 41 do
          j = j + 1
        end
        if j <= len then
          count = count + 1
          res[count] = {
            start    = start_pos,
            finish   = j,
            is_image = is_image,
            text_s   = start_pos + (is_image and 2 or 1),
            text_e   = i - 1,
            url_s    = i + 2,
            url_e    = j - 1,
          }
          i = j + 1  -- jump past ')'
        else
          -- no closing ')'
          i = i + 1
        end
      else
        -- not a link, rewind to just after the original '['
        i = start_pos + 1
      end

    else
      i = i + 1
    end
  end

  return res
end

vim.api.nvim_set_hl(0, "ItalicBold", { italic = true, bold = true })
local hl = vim.api.nvim_get_hl(0, { name = "@markup.raw" })
vim.api.nvim_set_hl(0, "InlineQuote", { fg = hl.fg, italic = true })

-- Redraw all overlays, skipping the cursor line
function M.redraw(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_option(bufnr, "filetype") ~= filetype then return end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total = #lines
  local cursor = vim.api.nvim_win_get_cursor(0)[1]

  for i, line in ipairs(lines) do
    -- Heading overlays
    local level, disp = make_bar_line(i, total, line)
    if disp and i ~= cursor then
      local hl = heading_hl[level] or heading_hl[#heading_hl]
      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
        virt_text = {{disp, hl}},
        virt_text_pos = 'overlay',
      })
    end

    if i ~= cursor then
      local overlays = {}

      -- helper to add an overlay spec
      local function add(s, e, content, hl, strip)
        table.insert(overlays, {
          start   = s - 1,
          stop    = e - 1,
          content = content,
          hl      = hl,
          strip   = strip,
        })
      end

      -- specs: pattern-based or handler-based
      local specs = {
        -- bold+italic
        { pat   = "%*%*%*(.-)%*%*%*",      hl = "ItalicBold",       strip = 3 },
        -- bold
        { pat   = "%*%*(.-)%*%*",          hl = "@markup.strong",   strip = 2 },
        -- italic
        { pat   = "%*(.-)%*",              hl = "@markup.italic",   strip = 1 },
        -- inline code
        { pat   = "`([^`]-)`",             hl = "InlineQuote",      strip = 1 },
        -- code block line
        {
          handler = function(ln)
            local list = {}
            if ln:sub(1, 3) == "```" then
              local lang = vim.trim(ln:sub(4))
              local ico = " "
              if lang ~= "" then
                ico = ""
              end
              table.insert(list, {
                start   = 0,
                stop    = #ln,
                content = ico .. "  " .. lang,
                hl      = "@markup.list.checked",
                strip   = 0,
              })
            end
            return list
          end
        },

        -- handler for markdown checkboxes
        {
          handler = function(ln)
            local list = {}
            -- match items like '- [ ] Task' or '* [x] Task', capturing start and end
            for s, bullet, mark, task, e in ln:gmatch("()([%-%*]%s-)%[([ xX])%]%s-(.-)()") do
              local checked = mark:lower() == 'x'
              local icon    = checked and "☑" or "☐"
              table.insert(list, {
                start   = s - 1 + #bullet,
                stop    = e - 1,
                content = " " .. icon .. " ",
                hl      = checked and "TodoChecked" or "TodoUnchecked",
                strip   = 0,
              })
            end
            return list
          end
        },
        -- custom handler for markdown links/images
        {
          handler = function(ln)
            local list = {}
            for _, link in ipairs(parse_md_links(ln)) do
              local icon = link.is_image and "" or "󰌷"
              local pad  = string.rep(" ", (link.url_e - link.url_s) + 4)
              local txt  = (link.is_image and " " or "") .. icon
                              .. ln:sub(link.text_s, link.text_e) .. pad
              table.insert(list, {
                start   = link.start - 1,
                stop    = link.url_e - 1,
                content = txt,
                hl      = link.is_image and "ImageLink" or "Urllink",
                strip   = 0,
              })
            end
            return list
          end
        },
      }

      -- collect matches
      for _, spec in ipairs(specs) do
        if spec.pat then
          for s, c, e in line:gmatch("()"..spec.pat.."()") do
            add(s, e, c, spec.hl, spec.strip)
          end
        else
          for _, m in ipairs(spec.handler(line)) do
            table.insert(overlays, m)
          end
        end
      end

      -- sort overlays by start pos
      table.sort(overlays, function(a, b) return a.start < b.start end)

      -- apply extmarks
      for _, m in ipairs(overlays) do
        local spacing = string.rep(" ", m.strip)
        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, m.start, {
          virt_text     = { { spacing .. m.content .. spacing, m.hl } },
          virt_text_pos = "overlay",
          hl_mode       = "combine",
        })
      end
    end
  end
end

-- Setup autocommands
function M.setup()
  vim.cmd([[augroup MarkdownNumberDisplay
    autocmd!
    autocmd CursorMoved,CursorMovedI,BufEnter,BufWritePost,TextChanged,TextChangedI *.md lua require('markdownHighlight').redraw()
  augroup END]])
end

M.setup()
return M
