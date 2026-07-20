-- Visual layer: icons, statusline, tabs, file tree, dashboard,
-- indent guides, git signs, keybinding hints.
return {
  -- Icons (needs a Nerd Font)
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "dracula",
        globalstatus = true,
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics", "encoding", "filetype" },
      },
    },
  },

  -- Buffer tabs
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        separator_style = "slant",
        show_buffer_close_icons = true,
        offsets = {
          { filetype = "neo-tree", text = "Explorer", highlight = "Directory", separator = true },
        },
      },
    },
  },

  -- File explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Explorer" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      close_if_last_window = true,
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = { visible = true, hide_dotfiles = false, hide_gitignored = false },
      },
      window = { width = 32 },
    },
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    opts = { indent = { char = "│" }, scope = { enabled = true } },
  },

  -- Git signs in the gutter
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
      },
    },
  },

  -- Keybinding popup hints
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Startup dashboard
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {
        "                                                     ",
        "  ██████╗    ██╗      ██████╗    ██████╗   ██████╗    ",
        " ██╔════╝   ██╔╝     ██╔════╝    ██╔══██╗ ██╔════╝    ",
        " ██║        ██║      ██║         ██████╔╝ ██████╗     ",
        " ██║        ██║      ██║         ██╔══██╗ ╚═══██║     ",
        " ╚██████╗ ██╗██║  ██╗╚██████╗    ██║  ██║ ██████╔╝    ",
        "  ╚═════╝ ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝  ╚═╝ ╚═════╝     ",
        "                                                     ",
      }
      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", "<cmd>Telescope find_files<CR>"),
        dashboard.button("r", "  Recent files", "<cmd>Telescope oldfiles<CR>"),
        dashboard.button("n", "  New file", "<cmd>ene | startinsert<CR>"),
        dashboard.button("e", "  File explorer", "<cmd>Neotree toggle<CR>"),
        dashboard.button("l", "  Lazy (plugins)", "<cmd>Lazy<CR>"),
        dashboard.button("m", "  Mason (LSP)", "<cmd>Mason<CR>"),
        dashboard.button("q", "  Quit", "<cmd>qa<CR>"),
      }
      dashboard.section.footer.val = "happy hacking, jaime — C/C++ ready"
      alpha.setup(dashboard.opts)
    end,
  },
}
