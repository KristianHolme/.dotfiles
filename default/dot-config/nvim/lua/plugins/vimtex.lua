return {
	"lervag/vimtex",
	lazy = false,
	init = function()
		vim.g.vimtex_view_method = "zathura_simple"
		vim.g.vimtex_root_method = { "latexmkrc", "toc" }
		-- Set compiler options
		vim.g.vimtex_compiler_latexmk = {
			aux_dir = "../aux",
			out_dir = "../output",
		}
		-- Set quickfix options
		vim.g.vimtex_quickfix_mode = 0
		-- Syntax highlighting
		vim.g.vimtex_syntax_enabled = 0
		-- Enable folding
		vim.g.vimtex_fold_enabled = 0
		-- Disable overfull/underfull \hbox and all package warnings
		vim.g.vimtex_quickfix_ignore_filters = {
			"Overfull \\hbox",
			"Underfull \\hbox",
			"LaTeX Font Warning:",
			"Package hyperref Warning:",
			"Package natbib Warning:",
		}
	end,
	-- keys = {
	-- 	-- Use <localleader> (comma) for LaTeX - traditional VimTeX approach
	-- 	{ "<localleader>ll", "<cmd>VimtexCompile<CR>", desc = "VimTeX Compile", ft = "tex" },
	-- 	{ "<localleader>lv", "<cmd>VimtexView<CR>", desc = "VimTeX View", ft = "tex" },
	-- 	{ "<localleader>ls", "<cmd>VimtexStop<CR>", desc = "VimTeX Stop", ft = "tex" },
	-- 	{ "<localleader>lc", "<cmd>VimtexClean<CR>", desc = "VimTeX Clean", ft = "tex" },
	-- 	{ "<localleader>le", "<cmd>VimtexErrors<CR>", desc = "VimTeX Errors", ft = "tex" },
	-- 	{ "<localleader>lt", "<cmd>VimtexTocToggle<CR>", desc = "VimTeX TOC Toggle", ft = "tex" },
	-- 	{ "<localleader>li", "<cmd>VimtexInfo<CR>", desc = "VimTeX Info", ft = "tex" },
	-- },
}
