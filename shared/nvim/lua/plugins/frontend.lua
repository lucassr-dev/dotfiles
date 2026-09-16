-- ══════════════════════════════════════════════════════════════════════════════
-- FRONTEND
--
-- A coloracao de classes Tailwind e de hex vem do extra util.mini-hipatterns.
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- PACKAGE INFO (VERSOES DE DEPENDENCIAS NO package.json)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "vuki656/package-info.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    event = { "BufReadPre package.json" },
    opts = {
      hide_up_to_date = false,
      package_manager = "npm",
    },
    keys = {
      { "<leader>is", function() require("package-info").show({ force = true }) end, desc = "Mostrar versoes das dependencias" },
      { "<leader>ih", function() require("package-info").hide() end, desc = "Esconder versoes" },
      { "<leader>iu", function() require("package-info").update() end, desc = "Atualizar dependencia" },
      { "<leader>ic", function() require("package-info").change_version() end, desc = "Trocar versao da dependencia" },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- GRUPO DO WHICH-KEY
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>i", group = "info/deps" },
      },
    },
  },
}
