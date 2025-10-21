vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { desc = "Scroll up half page and center" })
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { desc = "Scroll down half page and center" })

vim.keymap.set("n", "<localleader>c", function()
  require("treesitter-context").go_to_context(vim.v.count1)
end, { silent = true, desc = "Go to Treesitter context" })

-- Insert empty lines without moving cursor
vim.keymap.set("n", "<leader>o", '@="m`o<C-V><Esc>``"<CR>', { desc = "Insert empty line below" })
vim.keymap.set("n", "<leader>O", '@="m`O<C-V><Esc>``"<CR>', { desc = "Insert empty line above" })
