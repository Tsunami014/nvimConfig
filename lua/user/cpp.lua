local M = {}

local dap = require("dap")
local notify_impl = require("notify") -- rcarriga/nvim-notify
local uv = vim.loop

dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = "codelldb",
        args = { "--port", "${port}" },
    },
}

M.build_args = ""
M.last_executable = "./a.out"

local function reset_build_args()
    M.build_args = ""
    M.last_executable = "./a.out"
    vim.notify("Build args reset to ''", vim.log.levels.INFO)
end

vim.api.nvim_create_autocmd("DirChanged", {
    callback = function() reset_build_args() end,
})

M.set_new_build_args = function()
    vim.ui.input({ prompt = "Set build args (will be passed to make or cmake --build):", default = M.build_args },
        function(input)
            if input ~= nil and #input > 0 then
                M.build_args = input
                vim.notify("Build args set to: " .. M.build_args)
            else
                vim.notify("Build args unchanged.", vim.log.levels.INFO)
            end
        end)
end

local function exists(fname)
    return vim.fn.filereadable(fname) == 1
end

local function compile_current_file_to_tmp()
    local full = vim.fn.expand("%:p")
    if full == "" then return nil end
    local out = "/tmp/" .. vim.fn.expand("%:t:r") .. "_test"
    local cwd = vim.fn.getcwd()
    local bufdir = vim.fn.fnamemodify(full, ":h")

    local exts = { "cpp", "cc", "cxx", "c" }
    local found, seen = { full }, {}

    local function impls(base)
        local name = base:match("(.+)%..+$") or base
        local list = {}
        for _, e in ipairs(exts) do
            for _, dir in ipairs({ bufdir, cwd }) do
                local f = dir .. "/" .. name .. "." .. e
                if vim.fn.filereadable(f) == 1 then table.insert(list, f) end
            end
            local g = vim.fn.globpath(cwd, "**/" .. name .. "." .. e, 0, 1)
            vim.list_extend(list, g)
        end
        return list
    end

    local function scan(path)
        if seen[path] then return end
        seen[path] = true
        for _, l in ipairs(vim.fn.readfile(path)) do
            local inc = l:match('^%s*#%s*include%s*"(.-)"')
            if inc then
                for _, f in ipairs(impls(inc)) do
                    if not seen[f] then
                        table.insert(found, f); scan(f)
                    end
                end
                local h = bufdir .. "/" .. inc
                if vim.fn.filereadable(h) == 1 then scan(h) end
            end
        end
    end

    scan(full)
    local ext = vim.fn.expand("%:e")
    local compiler = ''
    if ext == "c" then
        compiler = 'gcc'
    else
        compiler = 'g++'
    end

    local cmd = string.format(compiler .. ' -g -O0 -std=gnu++17 -o %s %s',
        out, table.concat(found, " "))
    vim.notify("Compiling...")
    local res = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Compile failed:\n" .. res, vim.log.levels.ERROR)
        return nil
    end
    return out
end

local function chunk_to_lines(chunk)
    if not chunk or chunk == "" then return {} end
    local lines = {}
    for line in chunk:gmatch("([^\r\n]+)") do
        table.insert(lines, line)
    end
    return lines
end

-- Async build using luv (vim.loop). Streams stdout/stderr into a single updating notify.
-- build_type: "Release" or "Debug"
-- opts: table: { title = ..., max_lines = N }
-- on_exit(success, text)
local function run_project_build_async(build_type, opts, on_exit)
    build_type = build_type or "Release"
    opts = opts or {}
    local title = opts.title or ("Build: " .. build_type)
    local max_lines = opts.max_lines or 2000

    local has_make = exists("Makefile") or exists("makefile")
    local has_cmake = exists("CMakeLists.txt")

    if has_make and has_cmake then
        vim.notify("Both Makefile and CMakeLists.txt exist — ambiguous. Aborting build.", vim.log.levels.WARN)
        if on_exit then on_exit(false, "ambiguous") end
        return nil
    end
    if not has_make and not has_cmake then
        vim.notify("No Makefile or CMakeLists.txt found in cwd.", vim.log.levels.WARN)
        if on_exit then on_exit(false, "no_build_files") end
        return nil
    end

    local cmd
    if has_make then
        if build_type == "Debug" then
            -- test for a debug target quickly
            local has_debug = false
            if vim.fn.filereadable("Makefile") == 1 then
                vim.fn.system('grep -E "^debug:|^debug[ \t]*:" Makefile >/dev/null 2>&1')
                has_debug = (vim.v.shell_error == 0)
            end
            if has_debug then
                cmd = "make debug " .. M.build_args
            else
                vim.notify("No 'debug' target found in Makefile; running plain 'make' for Debug build.",
                    vim.log.levels.WARN)
                cmd = "make " .. M.build_args
            end
        else
            cmd = "make " .. M.build_args
        end
    else
        cmd = string.format(
            'cmake -B build -S . -DCMAKE_BUILD_TYPE=%s && cmake --build build --parallel --config %s',
            build_type, build_type
        )
    end

    -- accumulator for lines
    local out_lines = {}

    local function append_and_trim(new_lines)
        for _, l in ipairs(new_lines) do
            table.insert(out_lines, l)
        end
        -- trim head if too big
        if #out_lines > max_lines then
            local keep = {}
            for i = #out_lines - max_lines + 1, #out_lines do
                table.insert(keep, out_lines[i])
            end
            out_lines = keep
        end
    end

    local function current_output_text()
        if #out_lines == 0 then return "" end
        return table.concat(out_lines, "\n")
    end

    -- initial notification; capture returned id so we can replace it later
    local initial_msg = "Starting build...\nCommand: " .. cmd
    local notif = nil
    local ok, ret = pcall(function()
        return notify_impl(initial_msg, vim.log.levels.INFO, { title = title, timeout = false })
    end)
    if ok and ret then notif = ret end

    -- spawn using `/bin/bash -lc` so the cmake && works. This is unixy — adjust if you need windows support.
    local bash = "/bin/bash"
    if vim.loop.os_uname().sysname:match("Windows") then
        -- basic fallback: use 'sh' if bash not available; windows handling should be added explicitly if required
        bash = vim.fn.executable("bash") == 1 and "bash" or "sh"
    end

    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local handle
    local function safe_notify_update(level)
        -- send the entire current output as the message; replace previous notification if possible
        local msg = current_output_text()
        if msg == "" then msg = "(no output yet)" end
        local new_ok, new_ret = pcall(function()
            if notif then
                return notify_impl(msg, level, { title = title, timeout = false, replace = notif })
            else
                return notify_impl(msg, level, { title = title, timeout = false })
            end
        end)
        if new_ok and new_ret then notif = new_ret end
    end

    -- start the process
    handle = uv.spawn(bash, {
        args = { "-lc", cmd },
        stdio = { nil, stdout, stderr },
    }, function(code, signal)
        -- on exit: schedule notify updates & call callback
        vim.schedule(function()
            local final_text = current_output_text()
            if code == 0 then
                local ok_msg = (final_text ~= "" and final_text) or "Build finished successfully."
                -- final success notification briefly visible
                local new_ok, new_ret = pcall(function()
                    if notif then
                        return notify_impl(ok_msg, vim.log.levels.INFO,
                            { title = title, timeout = 3000, replace = notif })
                    else
                        return notify_impl(ok_msg, vim.log.levels.INFO, { title = title, timeout = 3000 })
                    end
                end)
                if new_ok and new_ret then notif = new_ret end
                if on_exit then on_exit(true, final_text) end
            else
                local err_msg = (final_text ~= "" and final_text) or
                    ("Build failed (exit code " .. tostring(code) .. ")")
                local new_ok, new_ret = pcall(function()
                    if notif then
                        return notify_impl(err_msg, vim.log.levels.ERROR, { title = title, timeout = 0, replace = notif })
                    else
                        return notify_impl(err_msg, vim.log.levels.ERROR, { title = title, timeout = 0 })
                    end
                end)
                if new_ok and new_ret then notif = new_ret end
                if on_exit then on_exit(false, final_text) end
            end
            -- close pipes & handle (defensive)
            pcall(function() stdout:read_stop() end)
            pcall(function() stderr:read_stop() end)
            pcall(function() stdout:close() end)
            pcall(function() stderr:close() end)
            pcall(function() handle:close() end)
        end)
    end)

    if not handle then
        vim.notify("Failed to spawn build process.", vim.log.levels.ERROR)
        if on_exit then on_exit(false, "spawn_failed") end
        return nil
    end

    -- stdout reader
    uv.read_start(stdout, function(err, data)
        if err then
            -- schedule an error notification but keep process running
            vim.schedule(function()
                notify_impl("Error reading build stdout: " .. tostring(err), vim.log.levels.WARN)
            end)
            return
        end
        if data and #data > 0 then
            local lines = chunk_to_lines(data)
            append_and_trim(lines)
            vim.schedule(function() safe_notify_update(vim.log.levels.INFO) end)
        end
    end)

    -- stderr reader
    uv.read_start(stderr, function(err, data)
        if err then
            vim.schedule(function()
                notify_impl("Error reading build stderr: " .. tostring(err), vim.log.levels.WARN)
            end)
            return
        end
        if data and #data > 0 then
            local lines = chunk_to_lines(data)
            append_and_trim(lines)
            vim.schedule(function() safe_notify_update(vim.log.levels.ERROR) end)
        end
    end)

    vim.notify("Build started in background (spawned).", vim.log.levels.INFO)
    return true
end

-- synchronous wrapper kept for compatibility (old behaviour)
local function run_project_build(blocking_build_type)
    blocking_build_type = blocking_build_type or "Release"

    local has_make = exists("Makefile") or exists("makefile")
    local has_cmake = exists("CMakeLists.txt")

    if has_make and has_cmake then
        vim.notify("Both Makefile and CMakeLists.txt exist — ambiguous. Aborting build.", vim.log.levels.WARN)
        return false, "ambiguous"
    end
    if not has_make and not has_cmake then
        vim.notify("No Makefile or CMakeLists.txt found in cwd.", vim.log.levels.WARN)
        return false, "no_build_files"
    end

    local cmd
    if has_make then
        if blocking_build_type == "Debug" then
            if vim.fn.filereadable("Makefile") == 1 then
                vim.fn.system('grep -E "^debug:|^debug[ \t]*:" Makefile >/dev/null 2>&1')
                if vim.v.shell_error == 0 then
                    cmd = "make debug " .. M.build_args
                else
                    vim.notify("No 'debug' target found in Makefile; running plain 'make'.", vim.log.levels.WARN)
                    cmd = "make " .. M.build_args
                end
            else
                cmd = "make " .. M.build_args
            end
        else
            cmd = "make " .. M.build_args
        end
    else
        cmd = string.format(
            'cmake -B build -S . -DCMAKE_BUILD_TYPE=%s && cmake --build build --parallel --config %s',
            blocking_build_type, blocking_build_type
        )
    end

    vim.notify("Running build: " .. cmd)
    local res = vim.fn.system(cmd)
    local code = vim.v.shell_error
    if code ~= 0 then
        vim.notify("Build failed:\n" .. (res or "<no output>"), vim.log.levels.ERROR)
        return false, res
    end

    vim.notify("Build finished.")
    return true, res
end

-- DAP configurations
M.config = {
    {
        name = "Compile current file and debug (/tmp)",
        type = "codelldb",
        request = "launch",
        program = function()
            local out = compile_current_file_to_tmp()
            if not out then return nil end
            return out
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
        runInTerminal = false,
    },

    -- Async Release build (starts background build and returns immediately)
    {
        name = "Build (make/cmake)",
        type = "codelldb",
        request = "launch",
        program = function()
            run_project_build_async("Release", { title = "Build (Release)", max_lines = 2000 }, function(success, _out)
                if success then
                    -- optional: update last_executable guessing, etc.
                end
            end)
            return nil
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
        runInTerminal = false,
    },

    -- Async Debug build then prompt and launch the debugger when done
    {
        name = "Build (make/cmake) then run",
        type = "codelldb",
        request = "launch",
        program = function()
            run_project_build_async("Debug", { title = "Build (Debug)", max_lines = 2000 }, function(success, _out)
                if not success then
                    return
                end

                -- try to guess executable path if using a top-level CMake target named after the folder
                local guess = M.last_executable
                if exists("CMakeLists.txt") then
                    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
                    local candidate = vim.fn.getcwd() .. "/build/" .. project_name
                    if vim.fn.executable(candidate) == 1 or vim.fn.filereadable(candidate) == 1 then
                        guess = candidate
                    else
                        local c2 = vim.fn.getcwd() .. "/build/Debug/" .. project_name
                        if vim.fn.executable(c2) == 1 or vim.fn.filereadable(c2) == 1 then guess = c2 end
                    end
                end

                local result = vim.fn.input("Path to executable to debug: ", guess or M.last_executable)
                if not result or result == "" then
                    vim.notify("No program provided. Aborting debug launch.", vim.log.levels.WARN)
                    return
                end
                M.last_executable = result

                dap.run({
                    name = "Auto-run after build",
                    type = "codelldb",
                    request = "launch",
                    program = result,
                    cwd = vim.fn.getcwd(),
                    stopOnEntry = false,
                    args = {},
                    runInTerminal = false,
                })
            end)
            return nil
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
        runInTerminal = false,
    },
}

dap.configurations.c = M.config
dap.configurations.cpp = M.config

-- Do not include the 'build this file' in cmake config
local slice = {}
for i = 2, #M.config do
    slice[#slice + 1] = M.config[i]
end
dap.configurations.cmake = slice

return M
