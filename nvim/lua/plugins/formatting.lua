-- Formatting via conform.nvim. Runs clang-format on save for C/C++
-- (and stylua/others if present). Style comes from the nearest
-- .clang-format file, falling back to LLVM style.
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>fm",
      function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      mode = { "n", "v" },
      desc = "Format buffer",
    },
    {
      "<leader>tf",
      function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("Format on save: " .. (vim.g.disable_autoformat and "OFF" or "ON"))
      end,
      desc = "Toggle format on save",
    },
  },
  opts = {
    formatters_by_ft = {
      c = { "clang_format" },
      cpp = { "clang_format" },
      lua = { "stylua" },
    },
    formatters = {
      clang_format = {
        prepend_args = { "--fallback-style=LLVM" },
      },
    },
    format_on_save = function(bufnr)
      if vim.g.disable_autoformat then return end
      return { timeout_ms = 1500, lsp_format = "fallback" }
    end,
  },
}
