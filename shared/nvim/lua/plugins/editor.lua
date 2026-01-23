-- ══════════════════════════════════════════════════════════════════════════════
-- PLUGINS DE EDITOR
-- ══════════════════════════════════════════════════════════════════════════════

return {
  -- ──────────────────────────────────────────────────────────────────────────────
  -- TELESCOPE (FUZZY FINDER)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      { ";f", "<cmd>Telescope find_files<cr>", desc = "Buscar arquivos" },
      { ";r", "<cmd>Telescope live_grep<cr>", desc = "Buscar texto (grep)" },
      { ";b", "<cmd>Telescope buffers<cr>", desc = "Listar buffers" },
      { ";h", "<cmd>Telescope help_tags<cr>", desc = "Buscar ajuda" },
      { ";e", "<cmd>Telescope diagnostics<cr>", desc = "Listar diagnósticos" },
      { ";s", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Símbolos do documento" },
      { ";;", "<cmd>Telescope resume<cr>", desc = "Continuar última busca" },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = {
            prompt_position = "top",
            preview_width = 0.55,
          },
          width = 0.87,
          height = 0.80,
        },
        sorting_strategy = "ascending",
        winblend = 0,
        file_ignore_patterns = {
          "node_modules",
          ".git/",
          "dist/",
          "build/",
          "%.lock",
          "__pycache__",
          "%.pyc",
        },
        mappings = {
          i = {
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<C-n>"] = "cycle_history_next",
            ["<C-p>"] = "cycle_history_prev",
          },
        },
      },
      pickers = {
        find_files = {
          hidden = true,
          follow = true,
        },
        live_grep = {
          additional_args = function()
            return { "--hidden" }
          end,
        },
      },
    },
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- TELESCOPE FILE BROWSER
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      {
        "sf",
        function()
          require("telescope").extensions.file_browser.file_browser({
            path = "%:p:h",
            cwd = vim.fn.expand("%:p:h"),
            respect_gitignore = false,
            hidden = true,
            grouped = true,
            previewer = false,
            initial_mode = "normal",
            layout_config = { height = 40 },
          })
        end,
        desc = "Explorador de arquivos",
      },
    },
    config = function()
      require("telescope").load_extension("file_browser")
    end,
  },

  -- ──────────────────────────────────────────────────────────────────────────────
  -- NEO-TREE (EXPLORADOR DE ARQUIVOS)
  -- ──────────────────────────────────────────────────────────────────────────────
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          show_hidden_count = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          never_show = {
            ".DS_Store",
            "thumbs.db",
          },
        },
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 35,
        mappings = {
          ["<space>"] = "none",
          ["h"] = "close_node",
          ["l"] = "open",
        },
      },
      default_component_configs = {
        indent = {
          with_expanders = true,
          expander_collapsed = "",
          expander_expanded = "",
          expander_highlight = "NeoTreeExpander",
        },
        git_status = {
          symbols = {
            added = "",
            modified = "",
            deleted = "✖",
            renamed = "󰁕",
            untracked = "",
            ignored = "",
            unstaged = "󰄱",
            staged = "",
            conflict = "",
          },
        },
      },
    },
  },

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
      spec = {
        mode = { "n", "v" },
        { "g", group = "goto" },
        { "gs", group = "surround" },
        { "]", group = "next" },
        { "[", group = "prev" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "file/find" },
        { "<leader>g", group = "git" },
        { "<leader>q", group = "quit/session" },
        { "<leader>s", group = "search" },
        { "<leader>u", group = "ui" },
        { "<leader>w", group = "windows" },
        { "<leader>x", group = "diagnostics/quickfix" },
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
      { "<leader>xx", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Diagnósticos (documento)" },
      { "<leader>xX", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Diagnósticos (workspace)" },
      { "<leader>xL", "<cmd>TroubleToggle loclist<cr>", desc = "Location List" },
      { "<leader>xQ", "<cmd>TroubleToggle quickfix<cr>", desc = "Quickfix List" },
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
