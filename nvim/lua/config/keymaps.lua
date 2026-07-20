-- Global keymaps (LSP-specific maps live in lsp.lua on attach).
local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear highlight" })

-- Save / quit
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Resize with arrows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Grow height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Shrink height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Shrink width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Grow width" })

-- Move lines up/down
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep cursor centered on jumps
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Buffers
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- ============================================================
-- Compile & Run the current C / C++ file  ->  <F5>
-- Compiles with clang/clang++ into a temp exe, then runs it
-- in a bottom terminal split. Warnings on, C11 / C++17.
-- ============================================================
local function compile_and_run()
  vim.cmd("w")
  local file = vim.fn.expand("%:p")
  local ft = vim.bo.filetype
  local out = vim.fn.expand("%:p:r") .. ".exe"
  local cc, std
  if ft == "cpp" then cc, std = "clang++", "c++17"
  elseif ft == "c" then cc, std = "clang", "c11"
  else
    vim.notify("Not a C/C++ file (" .. ft .. ")", vim.log.levels.WARN)
    return
  end
  local cmd = string.format(
    '%s -std=%s -Wall -Wextra -g "%s" -o "%s" && "%s"',
    cc, std, file, out, out
  )
  vim.cmd("botright split | resize 15 | terminal " .. cmd)
  vim.cmd("startinsert")
end
map("n", "<F5>", compile_and_run, { desc = "Compile & run C/C++" })
map("n", "<leader>r", compile_and_run, { desc = "Compile & run C/C++" })

-- Terminal: escape to normal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
