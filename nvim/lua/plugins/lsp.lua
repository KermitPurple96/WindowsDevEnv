-- LSP: Mason installs/updates servers; lspconfig wires clangd for C/C++.
return {
  { "williamboman/mason.nvim", cmd = "Mason", opts = { ui = { border = "rounded" } } },
  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
      "b0o/schemastore.nvim", -- JSON/YAML schemas (package.json, tsconfig, etc.)
    },
    config = function()
      require("mason").setup({ ui = { border = "rounded" } })

      -- Diagnostics look & feel
      vim.diagnostic.config({
        virtual_text = { prefix = "●" },
        severity_sort = true,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = " ",
          },
        },
      })

      -- Capabilities from nvim-cmp
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Keymaps applied when any LSP attaches to a buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local buf = ev.buf
          local function m(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = buf, desc = "LSP: " .. desc })
          end
          m("gd", vim.lsp.buf.definition, "Go to definition")
          m("gD", vim.lsp.buf.declaration, "Go to declaration")
          m("gr", vim.lsp.buf.references, "References")
          m("gi", vim.lsp.buf.implementation, "Implementation")
          m("K", vim.lsp.buf.hover, "Hover docs")
          m("<leader>rn", vim.lsp.buf.rename, "Rename")
          m("<leader>ca", vim.lsp.buf.code_action, "Code action")
          m("<leader>fm", function() vim.lsp.buf.format({ async = true }) end, "Format")
          m("<leader>d", vim.diagnostic.open_float, "Line diagnostics")
          m("[d", function() vim.diagnostic.jump({ count = -1 }) end, "Prev diagnostic")
          m("]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
          -- clangd extra: swap between .c/.h
          m("<leader>ch", "<cmd>ClangdSwitchSourceHeader<CR>", "Switch source/header")
        end,
      })

      require("mason-lspconfig").setup({
        ensure_installed = {
          "clangd",  -- C / C++
          "lua_ls",  -- Lua
          "html",    -- HTML
          "cssls",   -- CSS
          "emmet_ls",-- Emmet (HTML/CSS/JSX expansion)
          "ts_ls",   -- JavaScript / TypeScript / Node
          "jsonls",  -- JSON
          "yamlls",  -- YAML
          "bashls",  -- Bash / shell
        },
        handlers = {
          function(server)
            require("lspconfig")[server].setup({ capabilities = capabilities })
          end,
          ["clangd"] = function()
            require("lspconfig").clangd.setup({
              capabilities = capabilities,
              cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--header-insertion=iwyu",
                "--completion-style=detailed",
                "--function-arg-placeholders",
                "--fallback-style=llvm",
              },
              init_options = { fallbackFlags = { "-std=c++17" } },
            })
          end,
          ["jsonls"] = function()
            require("lspconfig").jsonls.setup({
              capabilities = capabilities,
              settings = {
                json = {
                  schemas = require("schemastore").json.schemas(),
                  validate = { enable = true },
                },
              },
            })
          end,
          ["yamlls"] = function()
            require("lspconfig").yamlls.setup({
              capabilities = capabilities,
              settings = {
                yaml = {
                  schemaStore = { enable = false, url = "" },
                  schemas = require("schemastore").yaml.schemas(),
                },
              },
            })
          end,
          ["lua_ls"] = function()
            require("lspconfig").lua_ls.setup({
              capabilities = capabilities,
              settings = {
                Lua = {
                  diagnostics = { globals = { "vim" } },
                  workspace = { checkThirdParty = false },
                  telemetry = { enable = false },
                },
              },
            })
          end,
        },
      })
    end,
  },
}
