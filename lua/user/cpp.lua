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

local function reset_build_args()
  M.build_args = ""
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

-- small helper to check file existence (case-sensitive)
local function exists(fname)
  return vim.fn.filereadable(fname) == 1
end

-- helper to choose compiler based on extension
local function compile_current_file_to_tmp()
  local fullpath = vim.fn.expand("%:p")
  if fullpath == "" then
    vim.notify("No file to compile.", vim.log.levels.ERROR)
    return nil
  end
  local ext = vim.fn.expand("%:e")
  local base = vim.fn.expand("%:t:r")
  local out = "/tmp/" .. base
  local cmd
  if ext == "c" then
    cmd = string.format('gcc -g -O0 -o %s %s', out, fullpath)
  else
    -- default to g++ for cpp and others
    cmd = string.format('g++ -g -O0 -std=gnu++17 -o %s %s', out, fullpath)
  end

  vim.notify("Compiling: " .. cmd)
  local res = vim.fn.system(cmd)
  local code = vim.v.shell_error
  if code ~= 0 then
    vim.notify("Compile failed:\n" .. (res or "<no output>"), vim.log.levels.ERROR)
    return nil
  end
  vim.notify("Compiled to: " .. out)
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
    name = "Build (make/cmake) then debug (will prompt for program)",
    type = "codelldb",
    request = "launch",
    program = function()
      local ok, _ = run_project_build()
      if not ok then
        return nil
      end
      local default_prog = "./a.out"
      -- synchronous prompt: use vim.fn.input here instead of async vim.ui.input + busy-wait.
      -- vim.fn.input blocks for user input but does not require a busy-wait and won't freeze the UI.
      local result = vim.fn.input("Path to executable to debug: ", default_prog)
      if not result or result == "" then
        vim.notify("No program provided. Aborting debug.", vim.log.levels.WARN)
        return nil
      end
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
