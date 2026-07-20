-- General editor options + Neovide GUI settings.
local opt = vim.opt

-- Leader (set before lazy loads)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.showmode = false        -- lualine shows it instead
opt.splitright = true
opt.splitbelow = true
opt.pumheight = 12          -- completion popup height

-- Indentation (C/C++ friendly: 4 spaces)
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.autoindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- Files / undo
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.updatetime = 250        -- faster diagnostics / hover
opt.timeoutlen = 400

-- Misc
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.completeopt = "menu,menuone,noselect"
opt.fillchars = { eob = " " }

-- ============================================================
-- Neovide GUI — font + the "cool" cursor animations
-- ============================================================
if vim.g.neovide then
  -- Font: needs a Nerd Font. :h guifont  (Ctrl+= / Ctrl+- to resize live)
  vim.o.guifont = "JetBrainsMono Nerd Font:h13"

  vim.g.neovide_refresh_rate = 60
  vim.g.neovide_refresh_rate_idle = 5
  vim.g.neovide_no_idle = true
  vim.g.neovide_confirm_quit = true
  vim.g.neovide_hide_mouse_when_typing = true

  -- Padding around the edit area
  vim.g.neovide_padding_top = 8
  vim.g.neovide_padding_bottom = 8
  vim.g.neovide_padding_left = 8
  vim.g.neovide_padding_right = 8

  -- Subtle transparency + window blur (looks great, tweak to taste)
  vim.g.neovide_opacity = 0.95
  vim.g.neovide_window_blurred = true
  vim.g.neovide_floating_blur_amount_x = 3.0
  vim.g.neovide_floating_blur_amount_y = 3.0
  vim.g.neovide_floating_shadow = true

  -- Smooth motion for cursor / scroll / window
  vim.g.neovide_position_animation_length = 0.13
  vim.g.neovide_scroll_animation_length = 0.30
  vim.g.neovide_cursor_animation_length = 0.13
  vim.g.neovide_cursor_trail_size = 0.8
  vim.g.neovide_cursor_antialiasing = true
  vim.g.neovide_cursor_animate_in_insert_mode = true
  vim.g.neovide_cursor_animate_command_line = true
  vim.g.neovide_cursor_smooth_blink = true

  -- *** Particle trail *** — DISABLED (the "circles/shadow behind the cursor").
  -- The cursor still glides smoothly; there just aren't particles anymore.
  -- To re-enable, set one of: "railgun" | "torpedo" | "pixiedust" | "sonicboom" | "ripple" | "wireframe"
  vim.g.neovide_cursor_vfx_mode = ""

  -- Live font resize: Ctrl+= bigger, Ctrl+- smaller, Ctrl+0 reset
  local function set_font_size(delta)
    local cur = vim.o.guifont:match("h(%d+)")
    cur = tonumber(cur) or 13
    if delta == 0 then cur = 13 else cur = cur + delta end
    vim.o.guifont = "JetBrainsMono Nerd Font:h" .. cur
  end
  vim.keymap.set({ "n", "i" }, "<C-=>", function() set_font_size(1) end, { desc = "Font bigger" })
  vim.keymap.set({ "n", "i" }, "<C-->", function() set_font_size(-1) end, { desc = "Font smaller" })
  vim.keymap.set({ "n", "i" }, "<C-0>", function() set_font_size(0) end, { desc = "Font reset" })
end
