return {
  -- Mason configuration for LaTeX tools
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "texlab",         -- LaTeX LSP
        "latexindent",    -- LaTeX formatter
        "chktex",         -- LaTeX linter
      },
    },
  },
  
  -- Treesitter configuration for LaTeX
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "latex",
        "bibtex",
      },
    },
  },
}
