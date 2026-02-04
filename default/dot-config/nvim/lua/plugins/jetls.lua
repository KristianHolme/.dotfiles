return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Disable LanguageServer.jl from the Julia extra
        julials = {
          enabled = false,
        },
        -- Configure JETLS instead
        jetls = {
          cmd = { "jetls", "--threads=auto", "--" },
          filetypes = { "julia" },
          root_markers = { "Project.toml", ".git" },
        },
      },
    },
  },
}
