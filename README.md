# nvim-cpp-setup

A one-command **Neovim + Neovide C/C++ development environment** for Windows.
Clangd LSP, autocompletion, Treesitter, a debugger, clang-format on save, and
flashy Neovide cursor animations.

## Quick start

```powershell
git clone <your-repo-url> nvim-cpp-setup
cd nvim-cpp-setup
powershell -ExecutionPolicy Bypass -File .\install.ps1
neovide
```

The installer is idempotent — safe to re-run.

### Flags

| Flag | Effect |
|------|--------|
| `-SkipBuildTools` | Skip the large VS Build Tools download |
| `-SkipFont` | Skip the Nerd Font installs |
| `-SkipSync` | Skip the headless plugin bootstrap |

## What it installs

- **Neovim** (`Neovim.Neovim`)
- **LLVM/clang** (`LLVM.LLVM`) — `clang`, `clang++`, `clangd`, `clang-format`, `lldb-dap`
- **Git** (`Git.Git`)
- **Node.js LTS** (`OpenJS.NodeJS.LTS`) — runtime for the web/JSON language servers
- **VS Build Tools** (`Microsoft.VisualStudio.2022.BuildTools`, VCTools workload) — MSVC compiler/headers
- **Claude Code** (`Anthropic.ClaudeCode`)
- **ripgrep** (`BurntSushi.ripgrep.MSVC`) — required by Telescope's `<leader>fg` live grep
- **fd** (`sharkdp.fd`) — faster `<leader>ff` file finding
- **StyLua** (`JohnnyMorganz.StyLua`) — Lua formatter used by conform.nvim
- **JetBrainsMono** and **Hack** Nerd Fonts (per-user)

### Language support (LSP autocompletion + diagnostics)

C, C++, Lua, HTML, CSS, Emmet, JavaScript, TypeScript / Node, JSON (with
schemas), YAML (with schemas), and Bash — auto-installed via Mason on first
launch. JSON/YAML get schema-aware completion (package.json, tsconfig, GitHub
Actions, etc.) via SchemaStore.

## What it deploys

| Source (repo) | Destination |
|---------------|-------------|
| `nvim/` | `%LOCALAPPDATA%\nvim` (existing config backed up to `nvim.bak`) |
| `neovide/config.toml` | `%APPDATA%\neovide\config.toml` |
| `.clang-format` | `%USERPROFILE%\.clang-format` |

## Key bindings (leader = `Space`)

### Edit / navigate
| Key | Action |
|-----|--------|
| `Space e` | File explorer |
| `Space ff` / `Space fg` | Find files / live grep |
| `Space fb` / `Space fr` | Buffers / recent files |
| `Shift+h` / `Shift+l` | Prev / next buffer |
| `Ctrl+\` | Floating terminal |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | Font bigger / smaller / reset (Neovide) |

### C/C++ (clangd)
| Key | Action |
|-----|--------|
| `gd` `gD` `gr` `gi` | Definition / declaration / references / implementation |
| `K` | Hover docs |
| `Space rn` / `Space ca` | Rename / code action |
| `Space fm` | Format now |
| `Space ch` | Switch source/header |
| `[d` / `]d` | Prev / next diagnostic |

### Build & debug
| Key | Action |
|-----|--------|
| `F5` / `Space r` | Compile & run current file |
| `F9` / `Space db` | Toggle breakpoint |
| `Space dc` | Start / continue debugging |
| `F10` `F11` `F12` | Step over / into / out |
| `Space du` | Toggle debugger UI |
| `Space dt` | Terminate |

## Customizing the Neovide cursor effect

Edit `nvim/lua/config/options.lua`:

```lua
vim.g.neovide_cursor_vfx_mode = "railgun"
```

Options: `railgun`, `torpedo`, `pixiedust`, `sonicboom`, `ripple`, `wireframe`,
or `""` for smooth motion without particles. Transparency is `neovide_opacity`.

## Formatting

`clang-format` runs on every save (via conform.nvim). Style comes from the
nearest `.clang-format`; a global default lives at `~\.clang-format`. Toggle
format-on-save with `Space tf`.
