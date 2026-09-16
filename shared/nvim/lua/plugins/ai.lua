-- ══════════════════════════════════════════════════════════════════════════════
-- IA — RESOLUCAO DAS COLISOES EM <leader>a
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Dois extras disputam o grupo <leader>a e os dois estao ativos no lazyvim.json:
--
--   lazyvim.plugins.extras.ai.sidekick     — camada generica de CLI de agente
--   lazyvim.plugins.extras.ai.claudecode   — integracao especifica do Claude Code
--
-- Quatro atalhos sao declarados pelos dois. Como o sidekick carrega depois, ele
-- vence em todos, e as quatro acoes do claudecode ficavam INACESSIVEIS, em
-- silencio — sem erro, sem aviso, so nao acontecia nada do que o plugin promete.
-- Confirmado comparando os dois extras instalados e o keymap real do editor:
--
--   <leader>aa   claudecode "Accept diff"   perdia para sidekick "Toggle CLI"
--   <leader>ad   claudecode "Deny diff"     perdia para sidekick "Detach CLI"
--   <leader>af   claudecode "Focus Claude"  perdia para sidekick "Send File"
--   <leader>as   claudecode "Add file" (n)  perdia para sidekick "Select CLI"
--
-- As duas primeiras sao as que doiam: aceitar e recusar diff e como se revisa o
-- que o Claude Code propoe. Sem elas, o fluxo de revisao so funciona no mouse.
--
-- Criterio da resolucao: o sidekick fica com os atalhos simples, porque e a
-- camada generica e ja era quem vencia — mexer nele mudaria musculo ja treinado.
-- O claudecode recebe slots livres, escolhidos por mnemonica e nao por sobra:
--
--   <leader>ay   aceitar diff   (y de "yes")
--   <leader>an   recusar diff   (n de "no")
--   <leader>aF   focar o Claude (F maiusculo, vizinho do af "Send File")
--   <leader>aA   adicionar arquivo ao contexto (A de "Add")
--
-- As quatro letras foram verificadas livres no grupo <leader>a antes da escolha.
--
-- <leader>as em modo VISUAL nao entra aqui: o sidekick so o declara em normal,
-- entao "Send to Claude" na selecao visual nunca colidiu e continua onde estava.
return {
  {
    "coder/claudecode.nvim",
    keys = {
      { "<leader>aa", false },
      { "<leader>ad", false },
      { "<leader>af", false },
      { "<leader>as", false, mode = "n" },

      { "<leader>ay", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Aceitar diff (Claude)" },
      { "<leader>an", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Recusar diff (Claude)" },
      { "<leader>aF", "<cmd>ClaudeCodeFocus<cr>", desc = "Focar o Claude" },
      { "<leader>aA", "<cmd>ClaudeCodeAdd %<cr>", desc = "Adicionar arquivo ao contexto (Claude)" },
    },
  },
}
