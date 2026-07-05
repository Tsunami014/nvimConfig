local M = {}

local sig = {
    win = nil,
    result = nil,
    client_id = nil,
    request_id = nil,
}

local ns = vim.api.nvim_create_namespace("CustomSignatureHelp")

local function build_title()
    local count = sig.result and #sig.result.signatures or 1
    if count <= 1 then
        return "Signature"
    end
    local active = (sig.result.activeSignature or 0) + 1
    return string.format("Signature (%d/%d)", active, count)
end

local function close_window()
    if sig.win and vim.api.nvim_win_is_valid(sig.win) then
        vim.api.nvim_win_close(sig.win, true)
    end
    sig.win = nil
end

local function render()
    if not sig.result then
        close_window()
        return
    end

    local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(
        sig.result, vim.bo.filetype, { "(", "," }
    )
    if not lines or vim.tbl_isempty(lines) then
        close_window()
        return
    end

    local prev_win = sig.win

    local buf, win = vim.lsp.util.open_floating_preview(lines, "markdown", {
        border = "rounded",
        focusable = false,
        close_events = {},
        title = build_title(),
    })
    sig.win = win

    if hl then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.hl.range(buf, ns, "LspSignatureActiveParameter", { hl[1], hl[2] }, { hl[3], hl[4] })
    end

    if prev_win and vim.api.nvim_win_is_valid(prev_win) and prev_win ~= win then
        vim.api.nvim_win_close(prev_win, true)
    end
end

local function request()
    local params = vim.lsp.util.make_position_params(0, "utf-8")

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, method = "textDocument/signatureHelp" })) do
        if sig.request_id and sig.client_id == client.id then
            client:cancel_request(sig.request_id)
        end

        local ok, request_id = client:request("textDocument/signatureHelp", params, function(_, result)
            if result and result.signatures and #result.signatures > 0 then
                sig.result = result
                render()
            else
                sig.result = nil
                close_window()
            end
        end, 0)

        if ok then
            sig.request_id, sig.client_id = request_id, client.id
        end
    end
end

local function cycle(step)
    if not sig.result or #sig.result.signatures <= 1 then return end
    local n = #sig.result.signatures
    sig.result.activeSignature = ((sig.result.activeSignature or 0) + step) % n
    render()
end

function M.next() cycle(1) end
function M.prev() cycle(-1) end

local throttled = false
local group = vim.api.nvim_create_augroup("AutoSignatureHelp", { clear = true })

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
    group = group,
    callback = function()
        if throttled then return end
        throttled = true
        request()
        vim.defer_fn(function() throttled = false end, 50)
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
        sig.result = nil
        close_window()
    end,
})

return M
