return {
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
}