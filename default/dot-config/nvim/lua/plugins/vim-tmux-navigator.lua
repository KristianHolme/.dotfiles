return {
	"christoomey/vim-tmux-navigator",
	lazy = false,
	init = function()
		-- Disable tmux navigator when zooming the Vim pane
		vim.g.tmux_navigator_disable_when_zoomed = 1
	end,
	keys = {
		{ "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Navigate left to tmux pane" },
		{ "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Navigate down to tmux pane" },
		{ "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Navigate up to tmux pane" },
		{ "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Navigate right to tmux pane" },
		{ "<C-\\>", "<cmd>TmuxNavigatePrevious<CR>", desc = "Navigate to previous tmux pane" },
	},
}
