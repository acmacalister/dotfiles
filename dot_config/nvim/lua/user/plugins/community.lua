return {
  -- Add the community repository of plugin specifications
  "AstroNvim/astrocommunity",
  -- example of imporing a plugin, comment out to use it or add your own
  -- available plugins can be found at https://github.com/AstroNvim/astrocommunity

  { import = "astrocommunity.colorscheme.catppuccin" },
  -- { import = "astrocommunity.completion.copilot-lua-cmp" },
  { import = "astrocommunity.completion.copilot-lua" },
  { import = "astrocommunity.pack.typescript" },
  -- {
  --   "williamboman/mason-lspconfig.nvim",
  --   init = function()
  --     vim.api.nvim_create_autocmd("BufWritePost", {
  --       desc = "Fix all eslint errors",
  --       pattern = { "*.tsx", "*.ts", "*.jsx", "*.js" },
  --       group = "...",
  --       callback = function()
  --         if vim.fn.exists ":EslintFixAll" > 0 then vim.cmd "EslintFixAll" end
  --       end,
  --     })
  --   end,
  -- },

  { -- further customize the options set by the community
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        keymap = {
          accept = "<C-l>",
          accept_word = false,
          accept_line = false,
          next = "<C-.>",
          prev = "<C-,>",
          dismiss = "<C/>",
        },
      },
    },
  },
}
