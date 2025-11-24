if not vim.g.vscode then
  return {}
end

local vscode = require("vscode")

-- Add VSCode keymaps
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimKeymapsDefaults",
  callback = function()
    -- Open lazygit in VSCode
    vim.keymap.set("n", "<leader>gg", function()
      vscode.call("lazygit.openLazygit")
    end)
    
    -- Toggle sidebar visibility
    vim.keymap.set("n", "<C-b>", function()
      vscode.call("workbench.action.toggleSidebarVisibility")
    end)
    
    -- Toggle panel
    vim.keymap.set("n", "<C-j>", function()
      vscode.call("workbench.action.togglePanel")
    end)
  end,
})