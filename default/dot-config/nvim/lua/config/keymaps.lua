vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { desc = "Scroll up half page and center" })
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { desc = "Scroll down half page and center" })

vim.keymap.set("n", "<localleader>c", function()
  require("treesitter-context").go_to_context(vim.v.count1)
end, { silent = true, desc = "Go to Treesitter context" })

-- Insert empty lines without moving cursor
vim.keymap.set("n", "<leader>o", '@="m`o<C-V><Esc>``"<CR>', { desc = "Insert empty line below" })
vim.keymap.set("n", "<leader>O", '@="m`O<C-V><Esc>``"<CR>', { desc = "Insert empty line above" })

-- Collapse multiple empty lines above into single empty line
vim.keymap.set('n', '<leader>dO', function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local start_line = line
  
  -- Find the start of consecutive empty lines above
  while start_line > 1 and vim.fn.getline(start_line - 1):match('^%s*$') do
    start_line = start_line - 1
  end
  
  -- If we found empty lines above, collapse them
  if start_line < line then
    local lines_to_delete = line - start_line - 1
    if lines_to_delete > 0 then
      vim.cmd(start_line .. ',' .. (line - 1) .. 'd')
      vim.api.nvim_win_set_cursor(0, {start_line, 0})
    end
  end
end, { desc = "Collapse empty lines above" })

-- Collapse multiple empty lines below into single empty line
vim.keymap.set('n', '<leader>do', function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local end_line = line
  local total_lines = vim.fn.line('$')
  
  -- Find the end of consecutive empty lines below
  while end_line < total_lines and vim.fn.getline(end_line + 1):match('^%s*$') do
    end_line = end_line + 1
  end
  
  -- If we found empty lines below, collapse them
  if end_line > line then
    local lines_to_delete = end_line - line - 1
    if lines_to_delete > 0 then
      vim.cmd((line + 1) .. ',' .. end_line .. 'd')
      vim.api.nvim_win_set_cursor(0, cursor)
    end
  end
end, { desc = "Collapse empty lines below" })
