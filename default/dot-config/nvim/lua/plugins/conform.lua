return {
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      runic = {
        command = "julia",
        args = { "--project=@runic", "--startup-file=no", "-e", "using Runic; exit(Runic.main(ARGS))" },
      },
    },
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
