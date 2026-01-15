-- ══════════════════════════════════════════════════════════════════════════════
-- AUTOCMDS CUSTOMIZADOS
-- ══════════════════════════════════════════════════════════════════════════════

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- ──────────────────────────────────────────────────────────────────────────────
-- HIGHLIGHT NO YANK
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
  desc = "Destacar texto copiado",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- RESIZE SPLITS AUTOMATICAMENTE
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
  desc = "Redimensionar splits ao mudar tamanho da janela",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- VOLTAR PARA ÚLTIMA POSIÇÃO
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("BufReadPost", {
  group = augroup("last_position", { clear = true }),
  callback = function(event)
    local exclude_bt = { "help", "nofile", "quickfix" }
    local exclude_ft = { "gitcommit", "gitrebase" }
    local buf = event.buf

    if
      vim.tbl_contains(exclude_bt, vim.bo[buf].buftype)
      or vim.tbl_contains(exclude_ft, vim.bo[buf].filetype)
    then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Restaurar posição do cursor",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- FECHAR BUFFERS ESPECIAIS COM Q
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = {
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "checkhealth",
    "fugitive",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
  desc = "Fechar com q",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- WRAP E SPELL EM ARQUIVOS DE TEXTO
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("FileType", {
  group = augroup("text_settings", { clear = true }),
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
  desc = "Wrap e spell em arquivos de texto",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- CRIAR DIRETÓRIOS AUTOMATICAMENTE
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("BufWritePre", {
  group = augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
  desc = "Criar diretórios automaticamente",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- NÚMERO ABSOLUTO NO MODO DE INSERÇÃO
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("InsertEnter", {
  group = augroup("relative_numbers", { clear = true }),
  callback = function()
    vim.opt_local.relativenumber = false
  end,
  desc = "Números absolutos no modo de inserção",
})

autocmd("InsertLeave", {
  group = augroup("relative_numbers", { clear = false }),
  callback = function()
    vim.opt_local.relativenumber = true
  end,
  desc = "Números relativos no modo normal",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- REMOVER ESPAÇOS EM BRANCO
-- ──────────────────────────────────────────────────────────────────────────────

autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    pcall(function()
      vim.cmd([[%s/\s\+$//e]])
    end)
    vim.fn.setpos(".", save_cursor)
  end,
  desc = "Remover espaços em branco no final das linhas",
})

-- ──────────────────────────────────────────────────────────────────────────────
-- CONFIGURAÇÕES ESPECÍFICAS POR FILETYPE
-- ──────────────────────────────────────────────────────────────────────────────

-- Go: tabs de 4 espaços
autocmd("FileType", {
  group = augroup("go_settings", { clear = true }),
  pattern = "go",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = false
  end,
})

-- Python: tabs de 4 espaços
autocmd("FileType", {
  group = augroup("python_settings", { clear = true }),
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- Makefiles: usar tabs
autocmd("FileType", {
  group = augroup("makefile_settings", { clear = true }),
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})
