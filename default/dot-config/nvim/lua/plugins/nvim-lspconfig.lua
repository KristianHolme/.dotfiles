return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			texlab = {
				keys = {
					{
						"<localleader>lK",
						"<plug>(vimtex-doc-package)",
						desc = "VimTeX Docs",
						silent = true,
						ft = "tex",
					},
				},
				settings = {
					texlab = {
						auxDirectory = "./.latexmk/aux",
						bibtexFormatter = "texlab",
						build = {
							args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
							executable = "latexmk",
							forwardSearchAfter = false,
							onSave = false,
						},
						diagnosticsDelay = 300,
						formatterLineLength = 80,
						forwardSearch = {
							args = {},
						},
						latexFormatter = "latexindent",
						latexindent = {
							modifyLineBreaks = false,
						},
					},
				},
			},
		},
	},
}
