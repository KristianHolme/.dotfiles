return {
  -- Mason configuration for LaTeX tools
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "texlab",         -- LaTeX LSP
        "latexindent",    -- LaTeX formatter
        -- Note: chktex is not available in Mason registry
        -- You can install it system-wide with: sudo pacman -S texlive-core
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
