return {
  "folke/flash.nvim",
  keys = {
    -- Disable default s/S to avoid conflicts with surround (e.g., dsc)
    { "s", false, mode = { "n", "x", "o" } },
    { "S", false, mode = { "n", "x", "o" } },

    -- Remap Flash to Enter / Shift-Enter
    {
      "<CR>",
      function()
        require("flash").jump()
      end,
      mode = { "n", "x", "o" },
      desc = "Flash: jump",
    },
    {
      "<S-CR>",
      function()
        require("flash").treesitter()
      end,
      mode = { "n", "x", "o" },
      desc = "Flash: treesitter",
    },
  },
}


