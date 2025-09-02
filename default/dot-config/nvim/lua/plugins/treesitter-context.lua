return {
  "nvim-treesitter/nvim-treesitter-context",
  event = { "BufReadPost", "BufNewFile" },
  opts = {},
  config = function(_, opts)
    require("treesitter-context").setup(opts)
  end,
}


