-- ══════════════════════════════════════════════════════════════════════════════
-- TEMA E CORES
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- CATPPUCCIN (TEMA PRINCIPAL)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false, -- Mudar para true se quiser transparência
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = { "bold" },
        keywords = { "italic" },
        strings = {},
        variables = {},
        numbers = {},
        booleans = { "bold" },
        properties = {},
        types = { "bold" },
        operators = {},
      },
      integrations = {
        blink_cmp = true,
        flash = true,
        gitsigns = true,
        grug_far = true,
        illuminate = true,
        lsp_trouble = true,
        mason = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        neotest = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        snacks = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- SOLARIZED OSAKA (TEMA ALTERNATIVO)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = { bold = true },
        variables = {},
        sidebars = "dark",
        floats = "dark",
      },
      sidebars = { "qf", "help" },
      day_brightness = 0.3,
      hide_inactive_statusline = false,
      dim_inactive = false,
      lualine_bold = true,
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- TOKYONIGHT (TEMA ALTERNATIVO)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      style = "night", -- night, storm, day, moon
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = { bold = true },
        variables = {},
        sidebars = "dark",
        floats = "dark",
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- GRUVBOX (TEMA ALTERNATIVO)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      terminal_colors = true,
      undercurl = true,
      underline = true,
      bold = true,
      italic = {
        strings = true,
        emphasis = true,
        comments = true,
        operators = false,
        folds = true,
      },
      strikethrough = true,
      invert_selection = false,
      invert_signs = false,
      invert_tabline = false,
      invert_intend_guides = false,
      inverse = true,
      contrast = "",
      palette_overrides = {},
      overrides = {},
      dim_inactive = false,
      transparent_mode = false,
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- SELETOR DE TEMA
  -- Preview de sessao, ao vivo — nao grava nada em disco e some ao reabrir o
  -- editor. A troca persistente, propagada tambem para as outras ferramentas
  -- de terminal, e scripts/set_theme.sh (marcador tema:nome em
  -- lua/config/lazy.lua), nao este seletor.
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Trocar tema" },
    },
  },
}
