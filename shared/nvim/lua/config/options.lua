-- ══════════════════════════════════════════════════════════════════════════════
-- OPÇÕES DO NEOVIM
-- ══════════════════════════════════════════════════════════════════════════════

local opt = vim.opt

-- ──────────────────────────────────────────────────────────────────────────────
-- INTERFACE
-- ──────────────────────────────────────────────────────────────────────────────

opt.number = true              -- Números de linha
opt.relativenumber = true      -- Números relativos
opt.cursorline = true          -- Destacar linha atual
opt.signcolumn = "yes"         -- Coluna de sinais sempre visível
opt.showmode = false           -- Não mostrar modo (lualine já mostra)
opt.cmdheight = 1              -- Altura da linha de comando
opt.laststatus = 3             -- Status bar global
opt.termguicolors = true       -- Cores 24-bit
opt.pumblend = 10              -- Transparência do popup menu
opt.pumheight = 10             -- Altura máxima do popup

-- ──────────────────────────────────────────────────────────────────────────────
-- INDENTAÇÃO
-- ──────────────────────────────────────────────────────────────────────────────

opt.tabstop = 2                -- Largura do tab
opt.shiftwidth = 2             -- Largura da indentação
opt.softtabstop = 2            -- Tab no modo de inserção
opt.expandtab = true           -- Usar espaços em vez de tabs
opt.smartindent = true         -- Indentação inteligente
opt.shiftround = true          -- Arredondar indentação

-- ──────────────────────────────────────────────────────────────────────────────
-- BUSCA
-- ──────────────────────────────────────────────────────────────────────────────

opt.ignorecase = true          -- Ignorar case na busca
opt.smartcase = true           -- Case sensitive se houver maiúscula
opt.hlsearch = true            -- Destacar resultados
opt.incsearch = true           -- Busca incremental

-- ──────────────────────────────────────────────────────────────────────────────
-- EDIÇÃO
-- ──────────────────────────────────────────────────────────────────────────────

opt.wrap = false               -- Não quebrar linhas longas
opt.linebreak = true           -- Quebrar em palavras (quando wrap=true)
opt.scrolloff = 8              -- Linhas de contexto vertical
opt.sidescrolloff = 8          -- Colunas de contexto horizontal
opt.virtualedit = "block"      -- Cursor em qualquer lugar no visual block

-- ──────────────────────────────────────────────────────────────────────────────
-- ARQUIVOS E BACKUP
-- ──────────────────────────────────────────────────────────────────────────────

opt.autowrite = true           -- Auto-salvar antes de comandos
opt.confirm = true             -- Confirmar antes de sair sem salvar
opt.undofile = true            -- Persistir histórico de undo
opt.undolevels = 10000         -- Níveis de undo
opt.swapfile = false           -- Não criar arquivos swap
opt.backup = false             -- Não criar backups
opt.writebackup = false        -- Não criar backup durante escrita

-- ──────────────────────────────────────────────────────────────────────────────
-- SPLITS E JANELAS
-- ──────────────────────────────────────────────────────────────────────────────

opt.splitbelow = true          -- Split horizontal abre embaixo
opt.splitright = true          -- Split vertical abre à direita
opt.splitkeep = "screen"       -- Manter posição ao dividir

-- ──────────────────────────────────────────────────────────────────────────────
-- COMPLETION
-- ──────────────────────────────────────────────────────────────────────────────

opt.completeopt = "menu,menuone,noselect"
opt.wildmode = "longest:full,full"

-- ──────────────────────────────────────────────────────────────────────────────
-- PERFORMANCE
-- ──────────────────────────────────────────────────────────────────────────────

opt.updatetime = 200           -- Tempo para CursorHold (ms)
opt.timeoutlen = 300           -- Tempo para sequência de teclas (ms)
opt.redrawtime = 1500          -- Tempo máximo para syntax highlight
opt.lazyredraw = false         -- Atualizar tela durante macros

-- ──────────────────────────────────────────────────────────────────────────────
-- CLIPBOARD
-- ──────────────────────────────────────────────────────────────────────────────

opt.clipboard = "unnamedplus"  -- Usar clipboard do sistema

-- ──────────────────────────────────────────────────────────────────────────────
-- CARACTERES ESPECIAIS
-- ──────────────────────────────────────────────────────────────────────────────

opt.list = true                -- Mostrar caracteres invisíveis
opt.listchars = {
  tab = "→ ",
  trail = "·",
  nbsp = "␣",
  extends = "❯",
  precedes = "❮",
}
opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}

-- ──────────────────────────────────────────────────────────────────────────────
-- FOLDING
-- ──────────────────────────────────────────────────────────────────────────────

opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- ──────────────────────────────────────────────────────────────────────────────
-- MOUSE
-- ──────────────────────────────────────────────────────────────────────────────

opt.mouse = "a"                -- Habilitar mouse em todos os modos
opt.mousemoveevent = true      -- Eventos de movimento do mouse

-- ──────────────────────────────────────────────────────────────────────────────
-- SPELL (PORTUGUÊS E INGLÊS)
-- ──────────────────────────────────────────────────────────────────────────────

opt.spell = false              -- Desabilitado por padrão
opt.spelllang = { "en", "pt_br" }

-- ──────────────────────────────────────────────────────────────────────────────
-- GREP
-- ──────────────────────────────────────────────────────────────────────────────

if vim.fn.executable("rg") == 1 then
  opt.grepprg = "rg --vimgrep --smart-case"
  opt.grepformat = "%f:%l:%c:%m"
end
