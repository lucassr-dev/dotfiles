-- ══════════════════════════════════════════════════════════════════════════════
-- GIT — OVERRIDES DE KEYMAP
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- OCTO (RESOLVE COLISAO COM GIT STASH EM <leader>gS)
  -- ──────────────────────────────────────────────────────────────────────────────
  -- O extra lazyvim.plugins.extras.util.octo desabilita explicitamente gi/gI/gp/gP
  -- do snacks antes de redefini-los para o Octo, mas define <leader>gS = "Octo
  -- search" sem desabilitar o gS existente (Git Stash, vindo do extra
  -- editor.snacks_picker). Sem este override, o mapeamento do Octo vence por
  -- ultimo e o Git Stash fica inacessivel em <leader>gS, em silencio.
  -- Aqui desabilitamos o gS do Octo (preservando o Git Stash original, intocado)
  -- e movemos a busca do Octo para <leader>go — "o" de Octo, letra livre
  -- confirmada em <leader>g antes da mudanca.
  --
  -- Atencao para o futuro: <leader>go tambem e usado pelo extra
  -- lazyvim.plugins.extras.editor.mini-diff (hoje inativo — nao esta na lista
  -- de extras do lazyvim.json), que o define como "Toggle mini.diff overlay" e
  -- ainda desabilita o gitsigns.nvim que este setup usa. Se esse extra for
  -- ativado no futuro, a colisao em <leader>go se repete e precisa do mesmo
  -- tratamento (desabilitar o bind do mini-diff ou escolher outra letra).
  {
    "pwntester/octo.nvim",
    keys = {
      { "<leader>gS", false },
      { "<leader>go", "<cmd>Octo search<CR>", desc = "Search (Octo)" },
    },
  },
}
