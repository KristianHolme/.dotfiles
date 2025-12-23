return {
  {
    "aspeddro/cmp-pandoc.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    ft = { "markdown", "pandoc", "rmd" },
    config = function()
      require("cmp_pandoc").setup()
      -- Add cmp_pandoc source to nvim-cmp for markdown/pandoc files
      local cmp = require("cmp")
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown", "pandoc", "rmd" },
        callback = function()
          cmp.setup.buffer({
            sources = cmp.config.sources({
              { name = "nvim_lsp" },
              { name = "cmp_pandoc" },
              { name = "buffer" },
            }),
          })
        end,
      })
    end,
  },
}
