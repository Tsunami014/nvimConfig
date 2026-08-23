-- CHECKCHAR - places I need to check if all the characters are there because they sometimes get lost
local M = {}
local ns = vim.api.nvim_create_namespace("markdownHighlight")

local heading_hl = {
    "@markup.heading.1.markdown",
    "@markup.heading.2.markdown",
    "@markup.heading.3.markdown",
    "@markup.heading.4.markdown",
    "@markup.heading.5.markdown",
    "@markup.heading.6.markdown",
    "Normal",
}

local function make_bar(percent, level, offs)
    local parts = {}
    for i = offs, level do
        local threshold = (i / (level+1)) * 100
        local is_full = percent >= threshold
        -- CHECKCHAR
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

local function make_bar_line(idx, total, line, offs)
    local hashes, text = string.match(line, "^(#+)%s*(.*)$")
    if not hashes then
        return
    end
    local level = #hashes
    local percent = math.floor((idx / total) * 100)
    local bar = make_bar(percent, level, offs)
    return level, bar
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

local function blend(fg, bg, alpha)
    local fr, fg_, fb = math.floor(fg / 65536) % 256, math.floor(fg / 256) % 256, fg % 256
    local br, bg_, bb = math.floor(bg / 65536) % 256, math.floor(bg / 256) % 256, bg % 256
    local r = math.floor(fr * alpha + br * (1 - alpha) + 0.5)
    local g = math.floor(fg_ * alpha + bg_ * (1 - alpha) + 0.5)
    local b = math.floor(fb * alpha + bb * (1 - alpha) + 0.5)
    return r * 65536 + g * 256 + b
end

local function setup_highlights()
    local function gethl(name)
        return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    local function sethl(name, inf)
        vim.api.nvim_set_hl(0, name, inf)
    end

    sethl("ItalicBold", { italic = true, bold = true })
    sethl("MarkdownUnderline", { underline = true })
    sethl("MarkdownSquiggle", { undercurl = true })
    sethl("MarkdownDblUnderln", { underdouble = true })

    local normal_hl = gethl("Normal")
    local normal_bg = normal_hl.bg
    local normal_fg = normal_hl.fg

    -- Single shared tint used for blockquote bodies, the code-block fence
    -- background, and inline code
    local tint = normal_bg and blend(normal_fg or 0x808080, normal_bg, 0.10) or nil

    local macro_fg = gethl("Macro").fg or normal_fg
    local special_fg = gethl("Special").fg or normal_fg
    sethl("BlockQuoteSurround", { fg = macro_fg, bg = tint, bold = true })
    sethl("BlockQuoteSurroundIco", { fg = special_fg, bg = tint, bold = true })
    sethl("BlockQuote", tint and { bg = tint } or {})

    local function callout(name, src)
        local c = gethl(src)
        sethl(name, { fg = c.fg or normal_fg, bg = tint, bold = true })
    end
    callout("BlockQuoteNote", "DiagnosticInfo")
    callout("BlockQuoteTip", "DiagnosticHint")
    callout("BlockQuoteImport", "Statement")
    callout("BlockQuoteWarn", "DiagnosticWarn")
    callout("BlockQuoteCaution", "DiagnosticError")
    sethl("BlockQuoteCode", tint and { bg = tint } or {})

    local inline_base = gethl("@markup.raw.markdown_inline")
    if vim.tbl_isempty(inline_base) then
        inline_base = { link = "@markup.raw.markdown_inline" }
    end
    sethl("InlineQuote", vim.tbl_extend("force", inline_base, tint and { bg = tint } or {}))

    sethl("MarkdownHide", { fg = normal_bg, bg = normal_bg })
    local todo_hl = gethl("Todo")
    sethl("TodoHide", { fg = todo_hl.bg, bg = todo_hl.bg })
    sethl("TodoFg", { fg = (todo_hl.bg or todo_hl.fg), bold = todo_hl.bold })

    sethl("MarkdownHideBQ", { fg = (tint or normal_bg), bg = (tint or normal_bg) })
    local link_base = gethl("markdownLinkText")
    if vim.tbl_isempty(link_base) then
        link_base = { link = "markdownLinkText" }
    end
    sethl("markdownLinkTextBQ", vim.tbl_extend("force", link_base, tint and { bg = tint } or {}))
end

vim.schedule(setup_highlights)
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("MarkdownHighlightTheme", { clear = true }),
    callback = setup_highlights,
})

-- CHECKCHAR
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

-- CHECKCHAR
local all_bullets = "xX~!-> "
local bullet_icons = {
    x = "󰄵 ",
    X = "󰄵 ",
    ["~"] = "󰅘 ",
    ["!"] = "󰳤 ",
    ["-"] = "󰛲 ",
    [">"] = "󰧛 ",
}

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
            local level, disp = make_bar_line(i, total, line, x_scroll+1)
            if disp and not_cursor_or_visual(i) then
                local hl = heading_hl[level] or heading_hl[#heading_hl]
                local heading_opts = {
                    virt_text = { { disp, hl } },
                    virt_text_pos = "overlay",
                    hl_mode = "combine",
                }
                if vim.wo.wrap and vim.fn.strdisplaywidth(line) > vim.api.nvim_win_get_width(0) then
                    heading_opts.line_hl_group = hl
                end
                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, heading_opts)
            end
        end

        local on_cursor_line = not not_cursor_or_visual(i)

        local bef = line:match("^(%s*[>%s]+ )")
        if not bef then
            bef = line:match("^(%s*[>%s]+)$")
        end
        local in_blockquote = bef ~= nil and bef:find(">") ~= nil

        local hide_hl = in_blockquote and "MarkdownHideBQ" or "MarkdownHide"
        local link_hl = in_blockquote and "markdownLinkTextBQ" or "markdownLinkText"

        if not inside then
            local highlights = {}

            local function add_hl(s, e, hl)
                table.insert(highlights, { s = s, e = e, hl = hl })
            end

            local cursor_line_hl = {
                MarkdownUnderline = "MarkdownUnderline",
                MarkdownSquiggle = "MarkdownSquiggle",
                MarkdownDblUnderln = "MarkdownDblUnderln",
            }

            local specs = {
                { pat = "(``)(.-)(``)",                  hl = "InlineQuote" },
                { pat = "(`)([^`]-[^`\\])(`)",           hl = "InlineQuote" },
                { pat = "(~~)([^~]-[^~\\])(~~)",         hl = "@markup.strikethrough" },

                { pat = "(___)([^_]-[^_\\])(___)",       hl = "MarkdownDblUnderln" },
                { pat = "(__)([^_]-[^_\\])(__)",         hl = "MarkdownSquiggle" },
                { pat = "(_)([^_]-[^_\\])(_)",           hl = "MarkdownUnderline" },

                { pat = "(%*%*%*)([^*]-[^*\\])(%*%*%*)", hl = "ItalicBold" },
                { pat = "(%*%*)([^*]-[^*\\])(%*%*)",     hl = "@markup.strong" },
                { pat = "(%*)([^*]-[^*\\])(%*)",         hl = "@markup.italic" },

                -- Tables
                {
                  handler = function(ln)
                    if on_cursor_line then return end
                    local lead_ws, trimmed, trail_ws = ln:match("^(%s*)(|.*|)(%s*)$")
                    if not trimmed then
                      return
                    end
                    if not trimmed:find("|", 1, true) then
                      return
                    end

                    local pipe_count = 0
                    local all_sep_chars = true
                    local has_cont = false
                    for j = 1, #trimmed do
                      local ch = trimmed:sub(j, j)
                      if ch == "|" then
                        pipe_count = pipe_count + 1
                      end
                      if not (ch == "|" or ch == " ") then
                        has_cont = true
                      end
                      if not (ch == "|" or ch == "-" or ch == ":" or ch == " ") then
                        all_sep_chars = false
                      end
                    end

                    -- Separator: line is composed only of |, -, :, and spaces, and has >= 2 pipes and is not blank (|  |)
                    if all_sep_chars and has_cont and pipe_count >= 2 then
                      local full = ""
                      local L = #trimmed
                      for j = x_scroll+1, L do
                        local c = trimmed:sub(j, j)
                        if c == "|" then
                          if j == 1 then
                            full = full .. "├"
                          elseif j == L then
                            full = full .. "┤"
                          else
                            full = full .. "┼"
                          end
                        elseif c == "-" or c == " " then
                          full = full .. "─"
                        elseif c == ":" then
                          full = full .. ":"
                        else
                          full = full .. c
                        end
                      end
                      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                        virt_text = { { full, "@punctuation.special.markdown" } },
                        virt_text_pos = "overlay",
                        hl_mode = "combine",
                      })
                    else
                      -- Content row: is not all separators
                      local start = x_scroll
                      while true do
                        local pos = string.find(ln, "|", start, true)
                        if not pos then
                          break
                        end
                        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, pos - 1, {
                          virt_text = { { "│", "Normal" } },
                          virt_text_pos = "overlay",
                          hl_mode = "combine",
                        })
                        start = pos + 1
                      end
                    end
                  end
                },

                -- Horizontal rules & ones for headings
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        local trimmed = vim.trim(ln)
                        local fill, hl

                        local is_equals = trimmed:match("^=+$") ~= nil
                        local is_dashes = trimmed:match("^-+$") ~= nil

                        local setext_cap
                        if is_equals or is_dashes then
                            local prev = full_lines[i - 1]
                            if prev and vim.trim(prev) ~= "" then
                                local prev_first = prev:find("%S")
                                if prev_first then
                                    local captures = vim.treesitter.get_captures_at_pos(0, i - 2, prev_first - 1)
                                    for _, c in ipairs(captures) do
                                        if string.sub(c.capture, 1, string.len("markup.heading.")) == "markup.heading." then
                                            setext_cap = c.capture
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        if setext_cap then
                            fill = is_equals and "═" or "─"
                            hl = "@" .. setext_cap .. ".markdown"
                        elseif is_dashes and #trimmed >= 3 then
                            fill = "━"
                            hl = "@punctuation.special.markdown"
                        elseif trimmed:match("^[%-%*_][%-%*_][%-%*_]+$") then
                            fill = "━"
                            local first = string.sub(trimmed, 1, 1)
                            for j = 2, #trimmed do
                                if string.sub(trimmed, j, j) ~= first then
                                    return
                                end
                            end
                            hl = "@punctuation.special.markdown"
                        else
                            return
                        end

                        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                            virt_text = { { string.rep(fill, vim.api.nvim_win_get_width(0)), hl } },
                            virt_text_pos = "overlay",
                            hl_mode = "combine",
                        })
                    end,
                },

                -- Block quotes
                {
                  handler = function(ln)
                    if on_cursor_line then return end
                    local bef, txt = ln:match("^(%s*[>%s]+ )(.*)$")
                    if not bef then
                        bef = ln:match("^(%s*[>%s]+)$")
                        if bef then
                            bef = bef .. " "
                        end
                        txt = ""
                    end
                    if not bef or not bef:find(">") then return end
                    local txtsub = math.max(x_scroll - #bef + 1, 0)
                    local ico
                    local hl
                    local innr = txt:match("^%[!(.-)%]%s*$")
                    if innr then
                        local low = innr:lower()
                        -- CHECKCHAR
                        if low == "note" then
                            ico = ""
                            txt = "Note "
                            hl = "BlockQuoteNote"
                        elseif low == "tip" then
                            ico = ""
                            txt = "Tip "
                            hl = "BlockQuoteTip"
                        elseif low == "important" or low == "import" then
                            ico = "󰅽"
                            txt = "Important "
                            hl = "BlockQuoteImport"
                        elseif low == "warning" or low == "warn" then
                            ico = ""
                            txt = "Warning "
                            hl = "BlockQuoteWarn"
                        elseif low == "caution" then
                            ico = ""
                            txt = "Caution "
                            hl = "BlockQuoteCaution"
                        end
                        if ico then
                            if txtsub > 2 then ico = "  "
                            elseif txtsub == 2 then ico = " " .. ico
                            else ico = ico .. " "
                            end
                        else
                            ico = ""
                        end
                    else
                        ico = ""
                    end

                    local body_s = #bef
                    local body_e = #ln
                    if body_e > body_s then
                        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, body_s, {
                            end_col = body_e,
                            hl_group = "BlockQuote",
                            hl_mode = "combine",
                        })
                    end

                    local extmark_opts = {
                      virt_text = {
                        { bef:sub(x_scroll + 1):gsub(">", "│"), hl or "BlockQuoteSurroundIco" },
                      },
                      virt_text_pos = "overlay",
                      hl_mode = "combine",
                    }
                    if hl and (ico .. txt) ~= "" then
                        table.insert(extmark_opts.virt_text, { (ico .. txt):sub(txtsub), hl })
                    end
                    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, extmark_opts)
                  end,
                },

                -- <- and -> arrows
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        local start_pos = 1
                        while true do
                            local s1, e1 = string.find(ln, "->", start_pos, true)
                            local s2, e2 = string.find(ln, "<-", start_pos, true)
                            if not s1 and not s2 then break end

                            local s, e, icon
                            -- CHECKCHAR
                            if s1 and (not s2 or s1 <= s2) then
                                s, e = s1, e1
                                icon = (x_scroll == s and '' or "—") .. ""
                            else
                                s, e = s2, e2
                                icon = "" .. (x_scroll == s and '' or "—")
                            end
                            if x_scroll <= s then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1, {
                                    virt_text = { { icon, hl } },
                                    virt_text_pos = "overlay",
                                    hl_mode = "combine",
                                })
                            end
                            start_pos = e + 1
                        end
                    end,
                },

                -- Todos
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        for s, bullet, mark, task, e in ln:gmatch("()([%-%*]%s-)%[([" .. all_bullets .. "])%]%s-(.-)()") do
                            -- CHECKCHAR
                            local icon = bullet_icons[mark:lower()] or "󰄱 "
                            local pos = s + #bullet
                            add_hl(pos, pos + 3, hide_hl)
                            if x_scroll == pos + 1 then
                                icon = icon:sub(0, #icon - 1)
                            end
                            if x_scroll <= pos + 1 then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, pos, {
                                    virt_text = { { icon, in_blockquote and "BlockQuote" or "@markup.link.label.markdown_inline" } },
                                    virt_text_pos = "overlay",
                                    hl_mode = "combine",
                                })
                            end
                        end
                    end,
                },

                -- ==Highlights==
                {
                    handler = function(ln)
                        for s, cont, e in ln:gmatch("()==([^=]-[^=\\])==()") do
                            if on_cursor_line then
                                add_hl(s, e, "TodoFg")
                            else
                                add_hl(s, s+1, hide_hl)
                                add_hl(s+1, s+2, "TodoHide")
                                add_hl(s+2, e-2, "Todo")
                                add_hl(e-2, e-1, "TodoHide")
                                add_hl(e-1, e, hide_hl)
                            end
                        end
                    end,
                },

                -- Images and links
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        for _, link in ipairs(parse_md_links(ln)) do
                            -- CHECKCHAR
                            local icon = link.is_image and " " or "󰌷"
                            if link.start - x_scroll == 0 then
                                icon = link.is_image and "" or ""
                            elseif link.start - x_scroll < 0 then
                                icon = link.is_image and " " or ""
                            end
                            if link.start - x_scroll < 0 then
                                icon = icon:sub(x_scroll - link.start + 1)
                            end
                            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, link.start - 1, {
                                virt_text = { { icon, link_hl } },
                                virt_text_pos = "overlay",
                                hl_group = link_hl,
                                hl_mode = "combine",
                            })
                            if link.text_s and link.text_e and link.url_s and link.url_e then
                                add_hl(link.start, link.text_s, hide_hl)
                                add_hl(link.text_e + 1, link.url_s, hide_hl)
                                add_hl(link.url_e + 1, link.finish + 1, hide_hl)
                            end
                        end
                    end,
                },
                -- [[wiki links]]
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        for s, conts, e in ln:gmatch("()%[%[([^[%]]-[^[%]])%]%]()") do
                            if s >= x_scroll then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1, {
                                    virt_text = { { "󰌷", link_hl } }, -- CHECKCHAR
                                    virt_text_pos = "overlay",
                                    hl_group = link_hl,
                                    hl_mode = "combine",
                                })
                            end
                            add_hl(s, s + 2, hide_hl)
                            add_hl(s + 2, e - 2, "markdownUrl")
                            add_hl(e - 2, e, hide_hl)
                        end
                    end,
                },
                -- <links>
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        for s, e in line:gmatch("()<%a[%w+.-]*:[^<>%s]*>()") do
                            if s > x_scroll then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1, {
                                    virt_text = { { "󰌷", link_hl } }, -- CHECKCHAR
                                    virt_text_pos = "overlay",
                                    hl_group = link_hl,
                                    hl_mode = "combine",
                                })
                            end
                            add_hl(e - 1, e, hide_hl)
                        end
                    end,
                },
                -- [References][name]
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        for s, part1, e in line:gmatch("()(%[[^%[%]]+%])%[%d+%]()") do
                            local midp = s + #part1 - 1
                            if x_scroll <= midp then
                                add_hl(s, s + 1, hide_hl)
                                add_hl(midp, midp + 2, hide_hl)
                                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, midp, {
                                    virt_text = { { "↩", link_hl } }, -- CHECKCHAR
                                    virt_text_pos = "overlay",
                                    hl_mode = "combine",
                                })
                            end
                            add_hl(e - 1, e, hide_hl)
                        end
                    end,
                },
                -- Footnotes[^nme]
                {
                    handler = function(ln)
                        if on_cursor_line then return end
                        local first_non_ws = line:find("%S") or 1
                        for s, e in line:gmatch("()%[^[^%[%]]+%]()") do
                            if s > first_non_ws then
                                if x_scroll <= s then
                                    add_hl(s, s + 1, hide_hl)
                                    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s, {
                                        virt_text = { { "↩", link_hl } }, -- CHECKCHAR
                                        virt_text_pos = "overlay",
                                        hl_mode = "combine",
                                    })
                                end
                                add_hl(e - 1, e, hide_hl)
                            end
                        end
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
                        if orig_s == 0 or line:sub(orig_s - 1, orig_s - 1) ~= "\\" then
                            local orig_e = e + line_offset

                            local open_len = #open
                            local close_len = #close
                            local content_s = orig_s + open_len
                            local content_e = orig_e - close_len

                            if content_e > content_s and is_range_free(orig_s, orig_e) then
                                if on_cursor_line then
                                    local keep_hl = cursor_line_hl[spec.hl]
                                    if keep_hl then
                                        add_hl(content_s, content_e, keep_hl)
                                        mark_range(orig_s, orig_e)
                                    end
                                else
                                    add_hl(orig_s, content_s, hide_hl)
                                    add_hl(content_s, content_e, spec.hl)
                                    add_hl(content_e, orig_e, hide_hl)
                                    mark_range(orig_s, orig_e)
                                end
                            end
                        end
                    end
                else
                    spec.handler(line)
                end
            end

            local no_spell_hl = {
                MarkdownHide = true, TodoHide = true,
                MarkdownHideBQ = true, TodoHideBQ = true,
            }
            for _, h in ipairs(highlights) do
                local opts = {
                    end_col = h.e - 1,
                    hl_group = h.hl,
                }
                if no_spell_hl[h.hl] then
                    opts.spell = false
                end
                vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, h.s - 1, opts)
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
                local total_width = vim.api.nvim_win_get_width(0)
                local win_width = total_width - vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
                for j = vs, ve do
                    local out = {}
                    local txt = full_lines[j] or ""
                    local tlen = #txt
                    local is_code_line = false
                    if j == s then
                        local lang = vim.trim(txt:sub(4))
                        local icon = lang_icons[lang] or "" -- CHECKCHAR
                        tlen = 3 + #lang
                        out = { { " " .. icon .. " ", "BlockQuoteSurroundIco" }, { lang, "BlockQuoteSurround" } }
                    else
                        if j ~= e then
                            is_code_line = true
                        else
                            out = { { string.rep("━", max_length), "BlockQuoteSurroundIco" } }
                            tlen = max_length
                        end
                    end
                    if not_cursor_or_visual(j) then
                        local extmark_opts = {}
                        if is_code_line then
                            extmark_opts.end_col = #txt
                            extmark_opts.hl_group = "BlockQuoteCode"
                            extmark_opts.hl_mode = "combine"
                            if max_length > win_width then
                                extmark_opts.line_hl_group = "BlockQuote"
                            else
                                vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, tlen, {
                                    virt_text = { { string.rep(" ", max_length - tlen), "BlockQuoteCode" } },
                                    virt_text_pos = "overlay",
                                    hl_mode = "combine",
                                })
                            end
                            vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, 0, extmark_opts)
                        else
                            extmark_opts.virt_text = out
                            extmark_opts.virt_text_pos = "overlay"
                            extmark_opts.hl_mode = "combine"
                            if max_length > win_width then
                                extmark_opts.line_hl_group = "BlockQuote"
                            else
                                table.insert(out, { string.rep(" ", max_length - tlen), "BlockQuote" })
                            end
                            vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, 0, extmark_opts)
                        end
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
                    local is_code_line = false
                    if j == s then
                        local ico = ""
                        local lang = txt:sub(4)
                        if x_scroll <= 0 then ico = ico .. " " end
                        if x_scroll <= 1 then ico = ico .. (lang_icons[vim.trim(lang)] or "") end -- CHECKCHAR
                        if x_scroll <= 2 then ico = ico .. " " end
                        out = { { ico, "BlockQuoteSurroundIco" }, { lang:sub(math.max(x_scroll-2, 0)), "BlockQuoteSurround" } }
                    else
                        if j ~= e then
                            is_code_line = true
                        else
                            out = { { string.rep("━", max_length - x_scroll), "BlockQuoteSurroundIco" } }
                            tlen = max_length
                        end
                    end
                    if not tlen then
                        tlen = #txt + math.max(x_scroll - #txt, 0)
                    end
                    if not_cursor_or_visual(j) then
                        if is_code_line then
                            local visible_len = math.max(#txt - x_scroll, 0)
                            local pad = math.max(max_length - math.max(tlen, x_scroll), 0)
                            if visible_len > 0 then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, x_scroll, {
                                    end_col = x_scroll + visible_len,
                                    hl_group = "BlockQuoteCode",
                                    hl_mode = "combine",
                                })
                            end
                            if pad > 0 then
                                vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, #txt, {
                                    virt_text = { { string.rep(" ", pad), "BlockQuoteCode" } },
                                    virt_text_pos = "overlay",
                                    hl_mode = "combine",
                                })
                            end
                        else
                            local extmark_opts = {}
                            table.insert(out, { string.rep(" ", math.max(0, max_length - tlen)), "BlockQuote" })
                            extmark_opts.virt_text = out
                            extmark_opts.virt_text_pos = "overlay"
                            extmark_opts.hl_mode = "combine"
                            vim.api.nvim_buf_set_extmark(bufnr, ns, j - 1, 0, extmark_opts)
                        end
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
      pattern = { "*:[vV]*", "[vV]*:*" },  -- entering or leaving any visual mode
      callback = redraw,
    })
end

M.setup()
return M
