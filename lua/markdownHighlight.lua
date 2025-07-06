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
                parts[#parts + 1] = is_full and "" or ""
            elseif i == level then
                parts[#parts + 1] = is_full and "" or ""
            else
                parts[#parts + 1] = is_full and "" or ""
            end
        end
    end
    return table.concat(parts)
end

-- Prepare the display text for a heading line
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
    local stack_pos = {} -- numeric stack of '[' positions
    local stack_img = {} -- parallel stack: is it '!['?
    local stack_top = 0
    local count = 0
    local i = 1

    while i <= len do
        local b = byte(line, i)
        if b == 33 and i < len and byte(line, i + 1) == 91 then
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
            local is_image = stack_img[stack_top]
            stack_top = stack_top - 1

            -- only treat as link if it’s followed by '('
            if i < len and byte(line, i + 1) == 40 then
                local j = i + 2
                -- find the next ')'
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
                    i = j + 1 -- jump past ')'
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

vim.schedule(function() -- Schedule to ensure the colours have loaded by then
    vim.api.nvim_set_hl(0, "ItalicBold", { italic = true, bold = true })
    local hlRaw = vim.api.nvim_get_hl(0, { name = "Constant" })
    vim.api.nvim_set_hl(0, "InlineQuote", { fg = hlRaw.fg, italic = true })

    local bqBg = "#383838"
    local hlTx1 = vim.api.nvim_get_hl(0, { name = "Macro" })
    vim.api.nvim_set_hl(0, "BlockQuoteSurround", { fg = hlTx1.fg, bg = bqBg, bold = true })
    local hlTx2 = vim.api.nvim_get_hl(0, { name = "Special" })
    vim.api.nvim_set_hl(0, "BlockQuoteSurroundIco", { fg = hlTx2.fg, bg = bqBg, bold = true })
    vim.api.nvim_set_hl(0, "BlockQuote", { bg = bqBg })

    -- Highlight group to hide markdown markers
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

-- Redraw all overlays, skipping the cursor line
function M.redraw(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    if ft ~= "markdown" and ft ~= "codecompanion" then
        return
    end
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
                virt_text = { { disp, hl } },
                virt_text_pos = "overlay",
            })
        end

        if i ~= cursor then
            local highlights = {}

            -- helper to add a highlight spec
            local function add_hl(s, e, hl)
                table.insert(highlights, { s = s, e = e, hl = hl })
            end

            -- specs: pattern-based or handler-based
            local specs = {
                -- bold+italic
                { pat = "(%*%*%*)([^*].-[^*])(%*%*%*)", hl = "ItalicBold" },
                -- bold
                { pat = "(%*%*)([^*].-[^*])(%*%*)",     hl = "@markup.strong" },
                -- italic
                { pat = "(%*)([^*].-[^*])(%*)",         hl = "@markup.italic" },
                -- inline code
                { pat = "(`)([^`][^`]-)(`)",            hl = "InlineQuote" },
                -- strikethrough
                { pat = "(~~)(..-)(~~)",                hl = "@markup.strikethrough" },

                -- Horizontal rule
                {
                    handler = function(ln)
                        local list = {}
                        local trimmed = vim.trim(ln)
                        if trimmed:match("^[%-%*_][%-%*_][%-%*_]+$") and trimmed:match("^[%-%*_]+$") then
                            table.insert(list, { s = 1, e = #ln + 1, hl = "MarkdownHide" })
                            local width = vim.api.nvim_win_get_width(0)
                            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                                virt_text = { { string.rep("━", width), "@markup.heading.3" } },
                                virt_text_pos = "overlay",
                            })
                        end
                        return list
                    end,
                },

                -- handler for markdown checkboxes
                {
                    handler = function(ln)
                        local list = {}
                        for s, bullet, mark, task, e in ln:gmatch("()([%-%*]%s-)%[([ xX])%]%s-(.-)()") do
                            local checked = mark:lower() == "x"
                            local icon = checked and "☑" or "☐"
                            local hl = checked and "TodoChecked" or "TodoUnchecked"
                            -- Hide the original '[x]'
                            add_hl(s + #bullet, s + #bullet + 3, "MarkdownHide")
                            -- Add virtual text for the icon
                            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1 + #bullet, {
                                virt_text = { { icon, hl } },
                                virt_text_pos = "inline",
                                hl_group = hl,
                            })
                        end
                        return list
                    end,
                },
                -- custom handler for markdown links/images
                {
                    handler = function(ln)
                        local list = {}
                        for _, link in ipairs(parse_md_links(ln)) do
                            local icon = link.is_image and "" or "󰌷"
                            local hl = link.is_image and "ImageLink" or "Urllink"
                            -- Hide the full link syntax `[text](url)`
                            add_hl(link.start, link.finish + 1, "MarkdownHide")
                            -- Add virtual text for the icon and link text
                            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, link.start - 1, {
                                virt_text = { { icon .. " " .. ln:sub(link.text_s, link.text_e), hl } },
                                virt_text_pos = "inline",
                                hl_group = hl,
                            })
                        end
                        return list
                    end,
                },
            }

            -- collect matches
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

            for _, spec in ipairs(specs) do
                if spec.pat then
                    -- The pattern must have 3 captures: open marker, content, close marker
                    for s, open, content, close, e in line:gmatch("()" .. spec.pat .. "()") do
                        -- s: start index of match (1-based)
                        -- open: opening marker (e.g. ***)
                        -- content: the highlighted content
                        -- close: closing marker (e.g. ***)
                        -- e: end index (1-based, exclusive)
                        if is_range_free(s, e) then
                            local open_len = #open
                            local close_len = #close
                            local content_s = s + open_len
                            local content_e = e - close_len

                            add_hl(s, content_s, "MarkdownHide")
                            add_hl(content_s, content_e, spec.hl)
                            add_hl(content_e, e, "MarkdownHide")
                            mark_range(s, e)
                        end
                    end
                else
                    for _, m in ipairs(spec.handler(line)) do
                        if is_range_free(m.s, m.e) then
                            add_hl(m.s, m.e, m.hl)
                            mark_range(m.s, m.e)
                        end
                    end
                end
            end

            -- apply extmarks
            for _, h in ipairs(highlights) do
                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, h.s - 1, {
                    end_col = h.e - 1,
                    hl_group = h.hl,
                })
            end
        end
    end

    local start = nil
    for i, line in ipairs(lines) do
        if line:sub(1, 3) == "```" then
            if start ~= nil then
                local max_length = 0
                for index = start, i do
                    max_length = math.max(max_length, #lines[index])
                end
                max_length = max_length + 1
                local win_width = vim.api.nvim_win_get_width(0)
                for j = start, i do
                    local out = {}
                    local txt = lines[j]
                    local tlen = #txt
                    if j == start then
                        local lang = vim.trim(txt:sub(4))
                        local icon = lang_icons[lang] or ""
                        tlen = 3 + #lang
                        out = { { icon .. "  ", "BlockQuoteSurroundIco" }, { lang, "BlockQuoteSurround" } }
                    else
                        if j ~= i then
                            out = { { lines[j], "BlockQuote" } }
                        else
                            out = { { string.rep("━", max_length), "BlockQuoteSurroundIco" } }
                            tlen = max_length
                        end
                    end
                    if j ~= cursor then
                        local extmark_opts = {
                            virt_text = out,
                            virt_text_pos = "overlay",
                            hl_mode = "combine",
                        }
                        if max_length > win_width then
                            extmark_opts.line_hl_group = "BlockQuote"
                        else
                            table.insert(out, { string.rep(" ", max_length - tlen), "BlockQuote" })
                        end
                        -- overlay the blockquote content
                        vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, 0, extmark_opts)
                    end
                end
                start = nil
            else
                start = i
            end
        end
    end
end

-- Setup autocommands
function M.setup()
    vim.cmd([[augroup MarkdownNumberDisplay
    autocmd!
    autocmd CursorMoved,CursorMovedI,BufEnter,BufWritePost,TextChanged,TextChangedI * lua require('markdownHighlight').redraw()
  augroup END]])
end

M.setup()
return M
