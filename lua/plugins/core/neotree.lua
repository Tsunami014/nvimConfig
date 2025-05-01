return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    {"3rd/image.nvim", opts = {}}, -- Optional image support in preview window: See `# Preview Mode` for more information
  },
  branch = "v3.x",
  lazy = false, -- neo-tree will lazily load itself
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
      },
    },
  }
}
