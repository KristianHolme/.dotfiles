return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			julia = { "juliaformatter" },
			lua = { "stylua" },
			json = { "prettier" },
			-- add other languages as needed
		},
	},
}
