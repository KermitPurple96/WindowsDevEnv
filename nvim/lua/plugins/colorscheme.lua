-- Colorscheme: Dracula (dark). Solid background so it stays properly dark;
-- window-level transparency still comes from Neovide's opacity setting.
return {
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("dracula").setup({
        transparent_bg = false,
        italic_comment = true,
      })
      vim.o.background = "dark"
      vim.cmd.colorscheme("dracula")
    end,
  },
}
