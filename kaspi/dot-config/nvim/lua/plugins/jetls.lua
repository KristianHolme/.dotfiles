return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			-- dont use jetls on kaspi, uses too much resources
			servers = {
				-- Disable LanguageServer.jl from the Julia extra
				julials = {
					enabled = true,
				},
				-- -- configure JETLS instead
				-- jetls = {
				--   cmd = { "jetls", "serve" },
				--   filetypes = { "julia" },
				--   root_markers = { "Project.toml", ".git" },
				-- },
			},
		},
	},
}
