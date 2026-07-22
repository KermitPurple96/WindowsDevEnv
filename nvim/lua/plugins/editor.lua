-- Editing power tools: fuzzy finder, treesitter, comments, autopairs, terminal.
return {
  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Symbols" },
    },
    opts = {
      defaults = {
        prompt_prefix = "   ",
        selection_caret = " ",
        sorting_strategy = "ascending",
        layout_config = { prompt_position = "top" },
      },
    },
  },

  -- Treesitter — better syntax highlighting & indentation
  {
    "nvim-treesitter/nvim-treesitter",
    -- Pinned to master: the `main` branch is a rewrite that removed
    -- nvim-treesitter.configs along with ensure_installed/highlight/indent.
    -- Without this pin lazy tracks `main`, the config below throws
    -- "module 'nvim-treesitter.configs' not found", and treesitter silently
    -- never initializes - no highlighting, no parsers installed.
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "c", "cpp", "lua", "vim", "vimdoc", "bash", "cmake", "make", "markdown", "markdown_inline",
        "html", "css", "javascript", "typescript", "tsx", "json", "jsonc", "yaml", "toml",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
      incremental_selection = { enable = true },
    },
  },

  -- Comment toggling: gcc (line), gc (visual)
  { "numToStr/Comment.nvim", event = "VeryLazy", opts = {} },

  -- Auto-close brackets/quotes
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

  -- Floating terminal:  Ctrl+\  to toggle
  {
    "akinsho/toggleterm.nvim",
    keys = { [[<C-\>]] },
    opts = {
      open_mapping = [[<C-\>]],
      direction = "float",
      float_opts = { border = "rounded" },
    },
  },
}
