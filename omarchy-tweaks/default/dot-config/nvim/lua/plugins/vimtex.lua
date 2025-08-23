return {
  "lervag/vimtex",
  lazy = false, -- we don't want to lazy load VimTeX
  -- tag = "v2.15", -- uncomment to pin to a specific release
  init = function()
    -- VimTeX configuration goes here, e.g:
    vim.g.vimtex_view_method = "zathura"
    
    -- Set compiler options
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_latexmk = {
      aux_dir = "./.latexmk/aux",
      out_dir = "./.latexmk/out",
      callback = 1,
      continuous = 1,
      executable = "latexmk",
      hooks = {},
      options = {
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
      },
    }
    
    -- Set quickfix options
    vim.g.vimtex_quickfix_mode = 0
    
    -- Ignore mappings
    vim.g.vimtex_mappings_enabled = 1
    
    -- Auto indent
    vim.g.vimtex_indent_enabled = 1
    
    -- Syntax highlighting
    vim.g.vimtex_syntax_enabled = 1
    
    -- Enable folding
    vim.g.vimtex_fold_enabled = 0
    
    -- Don't open QuickFix for warning messages if no errors are present
    vim.g.vimtex_quickfix_open_on_warning = 0
    
    -- Disable overfull/underfull \hbox and all package warnings
    vim.g.vimtex_quickfix_ignore_filters = {
      "Overfull \\hbox",
      "Underfull \\hbox",
      "LaTeX Font Warning:",
      "Package hyperref Warning:",
      "Package natbib Warning:",
    }
  end,
  keys = {
    -- Use <localleader> (comma) for LaTeX - traditional VimTeX approach
    { "<localleader>ll", "<cmd>VimtexCompile<CR>", desc = "VimTeX Compile", ft = "tex" },
    { "<localleader>lv", "<cmd>VimtexView<CR>", desc = "VimTeX View", ft = "tex" },
    { "<localleader>ls", "<cmd>VimtexStop<CR>", desc = "VimTeX Stop", ft = "tex" },
    { "<localleader>lc", "<cmd>VimtexClean<CR>", desc = "VimTeX Clean", ft = "tex" },
    { "<localleader>le", "<cmd>VimtexErrors<CR>", desc = "VimTeX Errors", ft = "tex" },
    { "<localleader>lt", "<cmd>VimtexTocToggle<CR>", desc = "VimTeX TOC Toggle", ft = "tex" },
    { "<localleader>li", "<cmd>VimtexInfo<CR>", desc = "VimTeX Info", ft = "tex" },
  },
}
