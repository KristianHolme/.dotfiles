return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      julia = { "runic" },
      lua = { "stylua" },
      json = { "prettier" },
      tex = { "tex-fmt" },
    },
    default_format_opts = {
      timeout_ms = 10000,
    },
  },
}
