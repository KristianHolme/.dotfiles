return {
	-- Mason configuration for LaTeX tools
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = {
				"texlab", -- LaTeX LSP
				"julia-lsp",
				"prettier",
			},
		},
	},
	-- Treesitter configuration for LaTeX
	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"bash",
				"latex",
				"bibtex",
				"julia",
				"json",
			},
		},
	},
}
