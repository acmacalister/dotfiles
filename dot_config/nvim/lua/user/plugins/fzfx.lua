return {
  -- optional for icons
  { "nvim-tree/nvim-web-devicons" },

  -- optional for the 'fzf' command
  {
    "junegunn/fzf",
    build = function() vim.fn["fzf#install"]() end,
  },

  {
    "linrongbin16/fzfx.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons", "junegunn/fzf" },
    lazy = false,

    -- specify version to avoid break changes
    -- version = 'v5.*',

    config = function() require("fzfx").setup() end,
  },
}
