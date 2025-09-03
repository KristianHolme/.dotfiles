return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			julia = { "julia-lsp" },
			lua = { "stylua" },
			json = { "prettier" },
			latex = { "tex-fmt" },
		},
	},
}
