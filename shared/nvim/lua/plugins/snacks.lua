-- ══════════════════════════════════════════════════════════════════════════════
-- SNACKS
--
-- Substitui telescope, neo-tree, dashboard-nvim, indent-blankline e mini-animate.
-- Os modulos default do LazyVim nao sao redeclarados; aqui ficam apenas os
-- ajustes proprios e os modulos que o LazyVim nao liga sozinho.
-- ══════════════════════════════════════════════════════════════════════════════

return {
  {
    "folke/snacks.nvim",
    opts = {
      -- ──────────────────────────────────────────────────────────────────────
      -- PICKER
      -- Layout telescope mantem o visual anterior: prompt no topo, preview 55%.
      -- ──────────────────────────────────────────────────────────────────────
      picker = {
        layout = { preset = "telescope" },
        sources = {
          files = { hidden = true, follow = true },
          grep = { hidden = true },
        },
        win = {
          input = {
            keys = {
              ["<C-j>"] = { "list_down", mode = { "i", "n" } },
              ["<C-k>"] = { "list_up", mode = { "i", "n" } },
            },
          },
        },
      },

      -- ──────────────────────────────────────────────────────────────────────
      -- EXPLORER
      -- ──────────────────────────────────────────────────────────────────────
      explorer = { enabled = true },

      -- ──────────────────────────────────────────────────────────────────────
      -- MODULOS EXTRAS
      -- ──────────────────────────────────────────────────────────────────────
      image = { enabled = true },
      zen = { enabled = true },
      dim = { enabled = true },
      scratch = { enabled = true },
    },
    keys = {
      { "<leader>uz", function() Snacks.zen() end, desc = "Modo foco (zen)" },
      { "<leader>uZ", function() Snacks.zen.zoom() end, desc = "Zoom na janela" },
      { "<leader>.", function() Snacks.scratch() end, desc = "Rascunho do projeto" },
      { "<leader>S", function() Snacks.scratch.select() end, desc = "Selecionar rascunho" },
    },
  },
}
