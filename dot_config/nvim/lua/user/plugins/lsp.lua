return {
  { "lvimuser/lsp-inlayhints.nvim", config = true },
  {
    "simrat39/rust-tools.nvim",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    ft = { "rs" },
    opts = function()
      return {
        server = astronvim.lsp.server_settings "rust_analyzer",
      }
    end,
  },
}
