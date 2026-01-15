-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIGURAÇÃO LSP
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- NVIM-LSPCONFIG (CONFIGURAÇÃO DOS SERVIDORES LSP)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Diagnósticos
      diagnostics = {
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
        severity_sort = true,
        float = {
          focusable = true,
          style = "minimal",
          border = "rounded",
          source = "always",
        },
      },

      -- Formatação automática ao salvar
      autoformat = true,

      -- Configuração de formato
      format = {
        formatting_options = nil,
        timeout_ms = nil,
      },

      -- Servidores LSP
      servers = {
        -- TypeScript/JavaScript
        tsserver = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
            javascript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
          },
        },

        -- Lua
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              completion = { callSnippet = "Replace" },
              diagnostics = {
                globals = { "vim" },
              },
              hint = {
                enable = true,
                arrayIndex = "Disable",
              },
            },
          },
        },

        -- Python
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
              },
            },
          },
        },

        -- CSS
        cssls = {},

        -- HTML
        html = {},

        -- JSON
        jsonls = {},

        -- YAML
        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false,
            },
          },
        },

        -- Tailwind CSS
        tailwindcss = {
          filetypes = {
            "html",
            "css",
            "scss",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
            "svelte",
          },
        },

        -- Bash
        bashls = {},

        -- Go
        gopls = {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
              },
              staticcheck = true,
              gofumpt = true,
            },
          },
        },

        -- Rust
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true },
              checkOnSave = {
                command = "clippy",
              },
            },
          },
        },
      },

      -- Setup adicional para servidores específicos
      setup = {
        -- Exemplo de setup customizado:
        -- tsserver = function(_, opts)
        --   -- Configuração adicional aqui
        -- end,
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- MASON (GERENCIADOR DE SERVIDORES LSP)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP
        "typescript-language-server",
        "lua-language-server",
        "css-lsp",
        "html-lsp",
        "json-lsp",
        "yaml-language-server",
        "tailwindcss-language-server",
        "pyright",
        "bash-language-server",

        -- Linters
        "eslint_d",
        "shellcheck",
        "luacheck",

        -- Formatters
        "prettier",
        "stylua",
        "shfmt",
        "black",
        "isort",
      },
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- NULL-LS / NONE-LS (FORMATAÇÃO E LINTING)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local null_ls = require("null-ls")
      opts.sources = vim.list_extend(opts.sources or {}, {
        -- Formatação
        null_ls.builtins.formatting.prettier.with({
          filetypes = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
            "css",
            "scss",
            "html",
            "json",
            "jsonc",
            "yaml",
            "markdown",
            "graphql",
          },
        }),
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.shfmt,
        null_ls.builtins.formatting.black,
        null_ls.builtins.formatting.isort,

        -- Diagnósticos
        null_ls.builtins.diagnostics.shellcheck,
      })
    end,
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- KEYMAPS LSP
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()

      -- Adicionar keymaps customizados
      vim.list_extend(keys, {
        { "gd", "<cmd>Telescope lsp_definitions<cr>", desc = "Ir para definição" },
        { "gr", "<cmd>Telescope lsp_references<cr>", desc = "Referências" },
        { "gI", "<cmd>Telescope lsp_implementations<cr>", desc = "Implementações" },
        { "gy", "<cmd>Telescope lsp_type_definitions<cr>", desc = "Type Definition" },
        { "K", vim.lsp.buf.hover, desc = "Hover" },
        { "gK", vim.lsp.buf.signature_help, desc = "Signature Help" },
        { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" } },
        { "<leader>cf", vim.lsp.buf.format, desc = "Formatar" },
      })
    end,
  },
}
