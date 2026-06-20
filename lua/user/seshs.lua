local home = vim.fs.normalize(vim.fn.expand("~"))
local ignored_exact = {
  home,
  home .. "/Downloads",
  home .. "/Documents",
  "/",
}
local ignored_trees = {
  "/tmp",
  "/var/tmp",
}

local function should_save_session()
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  for _, v in ipairs(ignored_exact) do
    if v == cwd then
      return false
    end
  end

  for _, dir in ipairs(ignored_trees) do
    if cwd == dir or vim.startswith(cwd, dir .. "/") then
      return false
    end
  end
  return true
end

local pend = false
local loading = false
vim.api.nvim_create_user_command(
  'LoadUI',
  function(opts)
    local ncwd = opts.args
    loading = true
    if ncwd ~= "" then
      vim.cmd("cd " .. vim.fn.fnameescape(ncwd))
      local saved_eventignore = vim.o.eventignore
      vim.o.eventignore = "all"
      vim.cmd("Neotree close")
      local loaded, err = pcall(function() require("resession").load(vim.fn.getcwd(), { silence_errors = true, reset = true }) end)
      vim.o.eventignore = saved_eventignore
      vim.defer_fn(function()
        vim.cmd("Neotree focus")
        vim.cmd("wincmd w")
        pcall(function() vim.cmd("edit!") end)
        vim.defer_fn(function() vim.cmd("Neotree close") end, 10)
      end, 10)
    else
      vim.cmd("Neotree show")
      vim.cmd("wincmd w")
    end
    loading = false
  end, { nargs = '?' }
)

vim.api.nvim_create_autocmd({
  "BufAdd",
  "BufNewFile",
  "BufDelete",
  "BufWipeout",
}, {
  callback = function()
    if pend or loading then
      return
    end
    pend = true
    vim.defer_fn(function()
      if vim.api.nvim_get_mode().mode == "n" and should_save_session() then
        require("resession").save(vim.fn.getcwd(), { notify = false })
      end
      pend = false
    end, 500)
  end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc(-1) > 0 then
      local dir = vim.fn.argv(0)
      if vim.fn.isdirectory(dir) == 1 then
        vim.defer_fn(function()
          vim.cmd("LoadUI " .. vim.fn.fnameescape(dir))
        end, 10)
      end
    end
  end,
  nested = true,
})
