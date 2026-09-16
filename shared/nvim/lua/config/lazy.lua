-- ══════════════════════════════════════════════════════════════════════════════
-- BOOTSTRAP LAZY.NVIM
-- ══════════════════════════════════════════════════════════════════════════════

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Falha ao clonar lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPressione qualquer tecla para sair..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Configurar leader antes de carregar lazy.nvim
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Configurar lazy.nvim
require("lazy").setup({
  spec = {
    -- ══════════════════════════════════════════════════════════════════════════
    -- BASE: LAZYVIM
    -- ══════════════════════════════════════════════════════════════════════════
    {
      "LazyVim/LazyVim",
      import = "lazyvim.plugins",
      opts = {
        -- >>> tema:nome inicio (gerenciado por scripts/set_theme.sh; edicoes manuais aqui serao perdidas) >>>
        colorscheme = "catppuccin-mocha",
        -- <<< tema:nome fim <<<
        news = { lazyvim = true, neovim = true },
      },
    },

    -- ══════════════════════════════════════════════════════════════════════════
    -- EXTRAS
    -- Fonte unica: lazyvim.json. Gerenciar com :LazyExtras, nunca aqui.
    -- ══════════════════════════════════════════════════════════════════════════

    -- ══════════════════════════════════════════════════════════════════════════
    -- PLUGINS CUSTOMIZADOS
    -- ══════════════════════════════════════════════════════════════════════════
    { import = "plugins" },
  },

  defaults = {
    lazy = false,
    version = false,
  },

  install = { colorscheme = { "catppuccin", "tokyonight", "habamax" } },

  checker = {
    enabled = true,
    notify = false,
  },

  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },

  ui = {
    border = "rounded",
    icons = {
      cmd = " ",
      config = "",
      event = " ",
      ft = " ",
      init = " ",
      import = " ",
      keys = " ",
      lazy = "󰒲 ",
      loaded = "●",
      not_loaded = "○",
      plugin = " ",
      runtime = " ",
      require = "󰢱 ",
      source = " ",
      start = " ",
      task = "✔ ",
      list = {
        "●",
        "➜",
        "★",
        "‒",
      },
    },
  },
})
