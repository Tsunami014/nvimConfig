local M = {}
local ns = vim.api.nvim_create_namespace("markdownHighlight")

local heading_hl = {
    "@markup.heading.1.markdown",
    "@markup.heading.2.markdown",
    "@markup.heading.3.markdown",
    "@markup.heading.4.markdown",
    "@markup.heading.5.markdown",
    "@markup.heading.6.markdown",
    "@markup.heading.7.markdown",
    "@markup.heading.8.markdown",
}

local function make_bar(percent, level)
    local parts = {}
    for i = 1, level do
        local threshold = (i / (level+1)) * 100
        local is_full = percent >= threshold
        if i == level then
            parts[#parts + 1] = is_full and "" or ""
        elseif i == 1 then
            parts[#parts + 1] = is_full and "" or ""
        else
            parts[#parts + 1] = is_full and "" or ""
        end
    end
    return table.concat(parts)
end

local function make_bar_line(idx, total, line)
    local hashes, text = string.match(line, "^(#+)%s*(.*)$")
    if not hashes then
        return
    end
    local level = #hashes
    local percent = math.floor((idx / total) * 100)
    local bar = make_bar(percent, level)
    return level, bar .. " " .. text
end

local function parse_md_links(line)
    local res = {}
    local len = #line
    local byte = string.byte
    local stack_pos = {}
    local stack_img = {}
    local stack_top = 0
    local count = 0
    local i = 1

    while i <= len do
        local b = byte(line, i)
        if b == 33 and i < len and byte(line, i + 1) == 91 then
            stack_top = stack_top + 1
            stack_pos[stack_top] = i
            stack_img[stack_top] = true
            i = i + 2
        elseif b == 91 then
            stack_top = stack_top + 1
            stack_pos[stack_top] = i
            stack_img[stack_top] = false
            i = i + 1
        elseif b == 93 and stack_top > 0 then
            local start_pos = stack_pos[stack_top]
            local is_image = stack_img[stack_top]
            stack_top = stack_top - 1

            if i < len and byte(line, i + 1) == 40 then
                local j = i + 2
                while j <= len and byte(line, j) ~= 41 do
                    j = j + 1
                end
                if j <= len then
                    count = count + 1
                    res[count] = {
                        start = start_pos,
                        finish = j,
                        is_image = is_image,
                        text_s = start_pos + (is_image and 2 or 1),
                        text_e = i - 1,
                        url_s = i + 2,
                        url_e = j - 1,
                    }
                    i = j + 1
                else
                    i = i + 1
                end
            else
                i = start_pos + 1
            end
        else
            i = i + 1
        end
    end

    return res
end

vim.schedule(function()
    vim.api.nvim_set_hl(0, "ItalicBold", { italic = true, bold = true })
    local hlRaw = vim.api.nvim_get_hl(0, { name = "Constant" })
    vim.api.nvim_set_hl(0, "InlineQuote", { fg = hlRaw.fg, italic = true })

    local bqBg = "#383838"
    local hlTx1 = vim.api.nvim_get_hl(0, { name = "Macro" })
    vim.api.nvim_set_hl(0, "BlockQuoteSurround", { fg = hlTx1.fg, bg = bqBg, bold = true })
    local hlTx2 = vim.api.nvim_get_hl(0, { name = "Special" })
    vim.api.nvim_set_hl(0, "BlockQuoteSurroundIco", { fg = hlTx2.fg, bg = bqBg, bold = true })
    vim.api.nvim_set_hl(0, "BlockQuote", { bg = bqBg })

    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
    vim.api.nvim_set_hl(0, "MarkdownHide", { fg = normal_hl.bg, bg = normal_hl.bg })
end)

local lang_icons = {
    lua = "",
    python = "",
    py = "",
    javascript = "",
    js = "",
    typescript = "",
    html = "",
    css = "",
    json = "",
    markdown = "",
    md = "",
    sh = "",
    bash = "",
    c = "",
    cpp = "",
    ["c++"] = "",
    java = "",
    mermaid = "󰫺",
    diff = "",
    sql = "",
}

local function utf8_offset(s, n)
  if n == 0 then return 1 end
  local i, count = 1, 0
  local len = #s
  while i <= len do
    local c = s:byte(i)
    local char_len
    if c < 0x80 then
      char_len = 1
    elseif c < 0xE0 then
      char_len = 2
    elseif c < 0xF0 then
      char_len = 3
    else
      char_len = 4
    end
    count = count + 1
    if count == n then return i end
    i = i + char_len
  end
  return i
end

-- Redraw overlays only for visible lines (w0..w$). Still scan the whole buffer to find fenced-code blocks
function M.redraw(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    if ft ~= "markdown" and ft ~= "codecompanion" then
        return
    end

    -- clear all previous marks for this buffer (safe)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    local win_view = vim.fn.winsaveview()
    local x_scroll = win_view.leftcol
    local top = vim.fn.line("w0")
    local bottom = vim.fn.line("w$")
    if top < 1 then top = 1 end
    if bottom < top then bottom = top end

    -- read full buffer once (used to compute totals and code-block boundaries)
    local full_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local total = #full_lines
    local visible_lines = vim.api.nvim_buf_get_lines(bufnr, top - 1, bottom, false)
    local cursor = vim.api.nvim_win_get_cursor(0)[1]

    local function not_cursor_or_visual(line_num)
        if line_num == cursor then
            return false
        end

        local mode = vim.fn.mode()
        local s, e

        if mode == 'v' or mode == 'V' or mode == '\22' then
            s = vim.fn.getpos('v')[2]
            e = vim.fn.getpos('.')[2]
            if s == 0 or e == 0 then
                return true
            end
            if s > e then
                s, e = e, s
            end
            if line_num >= s and line_num <= e then
                return false
            end
        end
        return true
    end

    -- determine whether we are inside a code fence at the top of the window
    local pre_count = 0
    for j = 1, math.max(0, top - 1) do
        local ln = full_lines[j] or ""
        if ln:sub(1, 3) == "```" then
            pre_count = pre_count + 1
        end
    end
    local inside = (pre_count % 2) == 1

    -- iterate only visible lines, but use their true buffer line number 'i'
    for idx, line in ipairs(visible_lines) do
        local i = top + idx - 1

        -- toggle code-fence status when we hit a fence line
        if line:sub(1, 3) == "```" then
            inside = not inside
        end

        if not inside then
            -- Heading overlays
            local level, disp = make_bar_line(i, total, line)
            if disp and not_cursor_or_visual(i) then
                local hl = heading_hl[level] or heading_hl[#heading_hl]
                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                    virt_text = { { disp, hl } },
                    virt_text_pos = "overlay",
                })
            end
        end

        if not_cursor_or_visual(i) and not inside then
            local highlights = {}

            local function add_hl(s, e, hl)
                table.insert(highlights, { s = s, e = e, hl = hl })
            end

            local specs = {
                { pat = "(%*%*%*)([^*]-[^*])(%*%*%*)", hl = "ItalicBold" },
                { pat = "(%*%*)([^*]-[^*])(%*%*)",     hl = "@markup.strong" },
                { pat = "(%*)([^*]-[^*])(%*)",         hl = "@markup.italic" },
                { pat = "(`)([^`][^`]-)(`)",           hl = "InlineQuote" },
                { pat = "(~~)(..-)(~~)",               hl = "@markup.strikethrough" },
                { pat = "(==)(.-)(==)",                hl = "Todo" },

                {
                  handler = function(ln)
                    -- capture leading and trailing whitespace
                    local lead_ws, trimmed, trail_ws = ln:match("^(%s*)(.*%S)(%s*)$") 
                    if not trimmed then
                      -- line is empty or all whitespace
                      return {}
                    end

                    -- quick reject: must contain at least one pipe to be a table line
                    if not trimmed:find("|", 1, true) then
                      return {}
                    end

                    -- Count pipes and ensure all characters are from the allowed set for a separator
                    local pipe_count = 0
                    local all_sep_chars = true
                    for j = 1, #trimmed do
                      local ch = trimmed:sub(j, j)
                      if ch == "|" then
                        pipe_count = pipe_count + 1
                      end
                      if not (ch == "|" or ch == "-" or ch == ":" or ch == " ") then
                        all_sep_chars = false
                      end
                    end

                    -- CASE 2 (separator): line is composed only of |, -, :, and spaces, and has >= 2 pipes
                    if all_sep_chars and pipe_count >= 2 then
                      local chars = {}
                      local L = #trimmed
                      for j = 1, L do
                        local c = trimmed:sub(j, j)
                        if c == "|" then
                          if j == 1 then
                            table.insert(chars, "├")   -- left connector (middle-left)
                          elseif j == L then
                            table.insert(chars, "┤")   -- right connector (middle-right)
                          else
                            table.insert(chars, "┼")   -- middle intersection (connects all around)
                          end
                        elseif c == "-" or c == " " then
                          table.insert(chars, "─")
                        elseif c == ":" then
                          table.insert(chars, ".")    -- colon-specific horizontal marker
                        else
                          table.insert(chars, c)
                        end
                      end
                      local new_line = lead_ws .. table.concat(chars)

                      local offs = utf8_offset(new_line, x_scroll+1)
                      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                        virt_text = { { new_line:sub(offs), "Normal" } },
                        virt_text_pos = "overlay",
                      })

                      return {}
                    end

                    -- CASE 1 (content row): starts with a pipe and contains other content
                    if trimmed:match("^|[^|]*|") then
                      local new_line = lead_ws .. trimmed:gsub("|", "│")
                      local offs = utf8_offset(new_line, x_scroll+1)
                      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                        virt_text = { { new_line:sub(offs), "Normal" } },
                        virt_text_pos = "overlay",
                      })
                    end
                    return {}
                  end
                },

                {
                    handler = function(ln)
                        local trimmed = vim.trim(ln)
                        if trimmed:match("^[%-%*_][%-%*_][%-%*_]+$") and trimmed:match("^[%-%*_]+$") then
                            local width = vim.api.nvim_win_get_width(0)
                            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                                virt_text = { { string.rep("━", width), "@markup.heading.3" } },
                                virt_text_pos = "overlay",
                            })
                        end
                        return {}
                    end,
                },


                {
                    handler = function(ln)
                        local start_pos = 1
                        local ln2 = ln .. " "
                        local spacing = ""

                        while true do
                            -- Find the next -> and <- after start_pos
                            local s1, e1 = string.find(ln2, spacing .. "-> ", start_pos, true)
                            local s2, e2 = string.find(ln2, spacing .. "<- ", start_pos, true)

                            -- If neither found, break
                            if not s1 and not s2 then break end

                            -- Determine which comes first
                            local s, e, icon
                            if s1 and (not s2 or s1 <= s2) then
                                s, e = s1, e1
                                icon = " "  -- icon for ->
                            else
                                s, e = s2, e2
                                icon = " "  -- icon for <-
                            end
                            s = s + #spacing
                            spacing = " "

                            -- Skip if the arrow is before the scroll position
                            if x_scroll < s then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1, {
                                    virt_text = { { icon, hl } },
                                    virt_text_pos = "overlay",
                                })
                            end

                            -- Move start_pos to after this arrow
                            start_pos = e + 1
                        end
                        return {}
                    end,
                },

                {
                    handler = function(ln)
                        for s, bullet, mark, task, e in ln:gmatch("()([%-%*]%s-)%[([ xX])%]%s-(.-)()") do
                            local checked = mark:lower() == "x"
                            local icon = checked and "󰄵 " or "󰄱 "
                            local hl = checked and "TodoChecked" or "TodoUnchecked"
                            local pos = s + #bullet
                            add_hl(pos, pos + 3, "MarkdownHide")
                            if x_scroll == pos + 1 then
                                icon = icon:sub(0, #icon - 1)
                            end
                            if x_scroll <= pos + 1 then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, pos, {
                                    virt_text = { { icon, hl } },
                                    virt_text_pos = "overlay",
                                    hl_group = hl,
                                })
                            end
                        end
                        return {}
                    end,
                },

                {
                    handler = function(ln)
                        for _, link in ipairs(parse_md_links(ln)) do
                            local icon = link.is_image and " " or "󰌷"
                            local hl = link.is_image and "ImageLink" or "Urllink"
                            if link.start - x_scroll == 0 then
                                icon = link.is_image and "" or ""
                            elseif link.start - x_scroll < 0 then
                                icon = link.is_image and " " or ""
                            end
                            if link.start - x_scroll < 0 then
                                icon = icon:sub(x_scroll - link.start + 1)
                            end
                            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, link.start - 1, {
                                virt_text = { { icon, hl } },
                                virt_text_pos = "overlay",
                                hl_group = hl,
                            })
                            if link.text_s and link.text_e and link.url_s and link.url_e then
                                add_hl(link.start, link.text_s, "MarkdownHide")
                                add_hl(link.text_e + 1, link.url_s, "MarkdownHide")
                                add_hl(link.url_e + 1, link.finish + 1, "MarkdownHide")
                            end
                        end
                        return {}
                    end,
                },
            }

            local used = {}
            local function is_range_free(s, e)
                for j = s, e - 1 do
                    if used[j] then return false end
                end
                return true
            end
            local function mark_range(s, e)
                for j = s, e - 1 do
                    used[j] = true
                end
            end

            local first_non_ws = line:find("%S") or 1
            local scan_line = line
            local line_offset = 0
            -- If the first (non-space) char + next char are "* " treat this line as a bullet:
            -- start scanning one char after the star so the initial bullet isn't captured.
            if line:sub(first_non_ws, first_non_ws + 1) == "* " then
                scan_line = line:sub(first_non_ws + 1)
                line_offset = first_non_ws
            end

            -- now use scan_line for pattern matching; map back to original columns when adding highlights
            for _, spec in ipairs(specs) do
                if spec.pat then
                    for s, open, content, close, e in scan_line:gmatch("()" .. spec.pat .. "()") do
                        -- s..e are indices within scan_line; map them to original line indices:
                        local orig_s = s + line_offset
                        local orig_e = e + line_offset

                        if is_range_free(orig_s, orig_e) then
                            local open_len = #open
                            local close_len = #close
                            local content_s = orig_s + open_len
                            local content_e = orig_e - close_len

                            add_hl(orig_s, content_s, "MarkdownHide")
                            add_hl(content_s, content_e, spec.hl)
                            add_hl(content_e, orig_e, "MarkdownHide")
                            mark_range(orig_s, orig_e)
                        end
                    end
                else
                    -- handler branch unchanged (handlers operate on the original line)
                    for _, m in ipairs(spec.handler(line)) do
                        if is_range_free(m.s, m.e) then
                            add_hl(m.s, m.e, m.hl)
                            mark_range(m.s, m.e)
                        end
                    end
                end
            end

            for _, h in ipairs(highlights) do
                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, h.s - 1, {
                    end_col = h.e - 1,
                    hl_group = h.hl,
                })
            end
        end
    end

    -- find fenced-code blocks across full buffer (so blocks that start off-screen are known)
    local code_blocks = {}
    do
        local start = nil
        for j = 1, total do
            local ln = full_lines[j] or ""
            if ln:sub(1, 3) == "```" then
                if start == nil then
                    start = j
                else
                    table.insert(code_blocks, { start = start, finish = j })
                    start = nil
                end
            end
        end
    end

    -- render block overlays, but only for lines that are visible
    for _, block in ipairs(code_blocks) do
        local s = block.start
        local e = block.finish
        -- compute the visible portion of this block
        local vs = math.max(s, top)
        local ve = math.min(e, bottom)
        if vs <= ve then
            -- if wrap is enabled we build a width-aware overlay, otherwise use x_scroll cropping
            if vim.wo.wrap then
                local max_length = 0
                for index = s, e do
                    max_length = math.max(max_length, #(full_lines[index] or ""))
                end
                max_length = max_length + 1
                local win_width = vim.api.nvim_win_get_width(0)
                for j = vs, ve do
                    local out = {}
                    local txt = full_lines[j] or ""
                    local tlen = #txt
                    if j == s then
                        local lang = vim.trim(txt:sub(4))
                        local icon = lang_icons[lang] or ""
                        tlen = 3 + #lang
                        out = { { icon .. "  ", "BlockQuoteSurroundIco" }, { lang, "BlockQuoteSurround" } }
                    else
                        if j ~= e then
                            out = { { full_lines[j] or "", "BlockQuote" } }
                        else
                            out = { { string.rep("━", max_length), "BlockQuoteSurroundIco" } }
                            tlen = max_length
                        end
                    end
                    if not_cursor_or_visual(j) then
                        local extmark_opts = {
                            virt_text = out,
                            virt_text_pos = "overlay",
                        }
                        if max_length > win_width then
                            extmark_opts.line_hl_group = "BlockQuote"
                        else
                            table.insert(out, { string.rep(" ", max_length - tlen), "BlockQuote" })
                        end
                        vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, 0, extmark_opts)
                    end
                end
            else
                local max_length = 0
                for index = s, e do
                    max_length = math.max(max_length, #(full_lines[index] or ""))
                end
                max_length = max_length + 1

                for j = vs, ve do
                    local out = {}
                    local txt = full_lines[j] or ""
                    local tlen
                    if j == s then
                        local lang = vim.trim(txt:sub(4))
                        local icon = lang_icons[lang] or ""
                        tlen = 3 + #lang + x_scroll
                        out = { { icon .. "  ", "BlockQuoteSurroundIco" }, { lang, "BlockQuoteSurround" } }
                    else
                        if j ~= e then
                            out = { { (full_lines[j] or ""):sub(x_scroll + 1), "BlockQuote" } }
                            tlen = #txt + math.max(x_scroll - #txt, 0)
                        else
                            out = { { "━━━" .. string.rep("━", max_length - 3 - x_scroll), "BlockQuoteSurroundIco" } }
                            tlen = max_length
                        end
                    end
                    if not_cursor_or_visual(j) then
                        local extmark_opts = {
                            virt_text = out,
                            virt_text_pos = "overlay",
                        }
                        table.insert(out, { string.rep(" ", math.max(0, max_length - tlen)), "BlockQuote" })
                        vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, 0, extmark_opts)
                    end
                end
            end
        end
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("MarkdownNumberDisplay", { clear = true })
    local function redraw()
        M.redraw()  -- So it does not run with arguments
    end
    vim.api.nvim_create_autocmd(
        { "CursorMoved", "CursorMovedI", "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "WinScrolled" },
        {
            group = group,
            callback = redraw,
        }
    )
    -- also fire when entering or leaving visual mode
    vim.api.nvim_create_autocmd("ModeChanged", {
      pattern = { "*:[vV]*", "[vV]*:*" },  -- entering or leaving any visual mode
      callback = redraw,
    })
end

M.setup()
return M
