-- ══════════════════════════════════════════════════════════════════════════════
-- PLUGINS DE EDITOR
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- FLASH (NAVEGAÇÃO RÁPIDA)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/flash.nvim",
    opts = {
      labels = "asdfghjklqwertyuiopzxcvbnm",
      search = {
        mode = "fuzzy",
      },
      jump = {
        autojump = true,
      },
      label = {
        uppercase = false,
        rainbow = {
          enabled = true,
          shade = 5,
        },
      },
      modes = {
        search = { enabled = false },
        char = { enabled = true },
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- WHICH-KEY (AJUDA DE ATALHOS)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/which-key.nvim",
    opts = {
      plugins = {
        marks = true,
        registers = true,
        spelling = { enabled = true },
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- TODO COMMENTS (DESTACAR COMENTÁRIOS TODO)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/todo-comments.nvim",
    opts = {
      signs = true,
      keywords = {
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- TROUBLE (LISTA DE DIAGNÓSTICOS)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/trouble.nvim",
    opts = {
      use_diagnostic_signs = true,
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnosticos (documento)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnosticos (workspace)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List" },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- GITSIGNS (INDICADORES GIT)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 500,
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- VIM-TMUX-NAVIGATOR (NAVEGAÇÃO ENTRE TMUX E NEOVIM)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navegar para esquerda" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navegar para baixo" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navegar para cima" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navegar para direita" },
    },
  },
}
