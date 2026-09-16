-- ══════════════════════════════════════════════════════════════════════════════
-- PLUGINS DE CODIFICAÇÃO
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- NVIM-TS-AUTOTAG (FECHAR TAGS HTML/JSX AUTOMATICAMENTE)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- INC-RENAME (RENOMEAR COM PREVIEW)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    config = true,
    keys = {
      {
        "<leader>cr",
        function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Renomear (inc-rename)",
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- REFACTORING (FERRAMENTAS DE REFATORAÇÃO)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {},
    keys = {
      {
        "<leader>re",
        function()
          require("refactoring").select_refactor()
        end,
        mode = { "n", "x" },
        desc = "Refatorar",
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- TREESITTER CONTEXT (MOSTRAR CONTEXTO DO CÓDIGO)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      enable = true,
      max_lines = 3,
      min_window_height = 0,
      line_numbers = true,
      multiline_threshold = 20,
      trim_scope = "outer",
      mode = "cursor",
      separator = nil,
      zindex = 20,
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- RAINBOW DELIMITERS (PARÊNTESES COLORIDOS)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local rainbow_delimiters = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
          vim = rainbow_delimiters.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },
}
