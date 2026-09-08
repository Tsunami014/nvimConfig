local p = require("profile")

return {
    {
        "Tsunami014/dbug.nvim",
        dependencies = {
            "mfussenegger/nvim-dap",
        },
        opts = {
            use_dap = not p.OPTS.Minimal,
        },
    },
}
