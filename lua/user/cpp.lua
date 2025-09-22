-- C++ configuration
local M = {}

dap = require("dap")

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

-- reset when dir changes
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function() reset_build_args() end,
})

M.set_new_build_args = function()
  vim.ui.input({ prompt = "Set build args (will be passed to make or cmake --build):", default = M.build_args }, function(input)
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
          if not seen[f] then table.insert(found, f); scan(f) end
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

-- helper to run the project's build command (make or cmake --build)
local function run_project_build()
  local has_make = exists("Makefile") or exists("makefile")
  local has_cmake = exists("CMakeLists.txt")

  if has_make and has_cmake then
    vim.notify("Both Makefile and CMakeLists.txt exist — ambiguous. Aborting build.", vim.log.levels.WARN)
    return false, "ambiguous"
  end

  local cmd
  if has_make then
    cmd = "make " .. M.build_args
  elseif has_cmake then
    -- `cmake --build <dir>` is standard; our build_args defaults to '.'
    cmd = "cmake --build " .. M.build_args
  else
    vim.notify("No Makefile or CMakeLists.txt found in cwd.", vim.log.levels.WARN)
    return false, "no_build_files"
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

M.config = {
  {
    name = "Compile current file and debug (/tmp)",
    type = "codelldb",
    request = "launch",
    program = function()
      local out = compile_current_file_to_tmp()
      if not out then
        return nil
      end
      return out
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    args = {},
    runInTerminal = false,
  },

  {
    name = "Build (make/cmake)",
    type = "codelldb",
    request = "launch",
    program = run_project_build,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    args = {},
    runInTerminal = false,
  },

  {
    name = "Build (make/cmake) then run",
    type = "codelldb",
    request = "launch",
    program = function()
      local ok, _ = run_project_build()
      if not ok then
        return nil
      end
      local result = vim.fn.input("Path to executable to debug: ", M.last_executable)
      if not result or result == "" then
        vim.notify("No program provided. Aborting debug.", vim.log.levels.WARN)
        return nil
      end
      M.last_executable = result
      return result
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    args = {},
    runInTerminal = false,
  },
}

dap.configurations.c = M.config
dap.configurations.cpp = M.config

return M
