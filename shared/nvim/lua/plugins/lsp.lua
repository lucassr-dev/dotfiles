-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIGURACAO LSP
--
-- Apenas o que nenhum extra ativo cobre. Os demais servidores vem dos extras:
--   vtsls       -> lang.typescript
--   eslint      -> linting.eslint
--   tailwindcss -> lang.tailwind
--   jsonls      -> lang.json
--   yamlls      -> lang.yaml
--   dockerls    -> lang.docker
-- ══════════════════════════════════════════════════════════════════════════════

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- ────────────────────────────────────────────────────────────────────
        -- LUA
        -- ────────────────────────────────────────────────────────────────────
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              completion = { callSnippet = "Replace" },
              diagnostics = { globals = { "vim", "Snacks", "LazyVim" } },
              hint = { enable = true, arrayIndex = "Disable" },
            },
          },
        },

        -- ────────────────────────────────────────────────────────────────────
        -- WEB
        -- ────────────────────────────────────────────────────────────────────
        cssls = {},
        html = {},

        -- ────────────────────────────────────────────────────────────────────
        -- SHELL
        -- ────────────────────────────────────────────────────────────────────
        bashls = {},
      },
    },
  },
}
