-- ══════════════════════════════════════════════════════════════════════════════
-- KEYMAPS CUSTOMIZADOS
-- ══════════════════════════════════════════════════════════════════════════════

local map = vim.keymap.set

-- ──────────────────────────────────────────────────────────────────────────────
-- GERAIS
-- ──────────────────────────────────────────────────────────────────────────────

-- Sair do modo de inserção com jk/jj
map("i", "jk", "<Esc>", { desc = "Sair do modo de inserção" })
map("i", "jj", "<Esc>", { desc = "Sair do modo de inserção" })

-- Salvar com Ctrl+s
map({ "n", "i", "v", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Salvar arquivo" })

-- Sair com Ctrl+q
map("n", "<C-q>", "<cmd>qa<cr>", { desc = "Sair do Neovim" })

-- Limpar busca com Esc
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Limpar highlight da busca" })

-- ──────────────────────────────────────────────────────────────────────────────
-- NAVEGAÇÃO
-- ──────────────────────────────────────────────────────────────────────────────

-- Mover entre janelas com Ctrl+hjkl
map("n", "<C-h>", "<C-w>h", { desc = "Ir para janela da esquerda" })
map("n", "<C-j>", "<C-w>j", { desc = "Ir para janela de baixo" })
map("n", "<C-k>", "<C-w>k", { desc = "Ir para janela de cima" })
map("n", "<C-l>", "<C-w>l", { desc = "Ir para janela da direita" })

-- Redimensionar janelas com Ctrl+setas
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Aumentar altura da janela" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Diminuir altura da janela" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Diminuir largura da janela" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Aumentar largura da janela" })

-- Navegar no buffer com H e L
map("n", "H", "^", { desc = "Início da linha" })
map("n", "L", "$", { desc = "Fim da linha" })

-- Manter cursor no centro ao navegar
map("n", "<C-d>", "<C-d>zz", { desc = "Meia página para baixo" })
map("n", "<C-u>", "<C-u>zz", { desc = "Meia página para cima" })
map("n", "n", "nzzzv", { desc = "Próxima ocorrência" })
map("n", "N", "Nzzzv", { desc = "Ocorrência anterior" })

-- ──────────────────────────────────────────────────────────────────────────────
-- BUFFERS
-- ──────────────────────────────────────────────────────────────────────────────

-- Navegar entre buffers
map("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Próximo buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Buffer anterior" })

-- Fechar buffer
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Fechar buffer" })
map("n", "<leader>bD", "<cmd>bdelete!<cr>", { desc = "Forçar fechar buffer" })

-- Fechar outros buffers
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<cr>", { desc = "Fechar outros buffers" })

-- ──────────────────────────────────────────────────────────────────────────────
-- SPLITS
-- ──────────────────────────────────────────────────────────────────────────────

map("n", "<leader>-", "<cmd>split<cr>", { desc = "Split horizontal" })
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Split vertical" })
map("n", "ss", "<cmd>split<cr>", { desc = "Split horizontal" })
map("n", "sv", "<cmd>vsplit<cr>", { desc = "Split vertical" })

-- ──────────────────────────────────────────────────────────────────────────────
-- EDIÇÃO
-- ──────────────────────────────────────────────────────────────────────────────

-- Mover linhas no visual mode
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Mover seleção para baixo" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Mover seleção para cima" })

-- Manter seleção ao indentar
map("v", "<", "<gv", { desc = "Diminuir indentação" })
map("v", ">", ">gv", { desc = "Aumentar indentação" })

-- Join sem mover cursor
map("n", "J", "mzJ`z", { desc = "Juntar linhas" })

-- Colar sem substituir register
map("x", "<leader>p", '"_dP', { desc = "Colar sem substituir register" })

-- Deletar sem copiar
map({ "n", "v" }, "<leader>d", '"_d', { desc = "Deletar sem copiar" })

-- Duplicar linha
map("n", "<leader>j", "<cmd>t.<cr>", { desc = "Duplicar linha abaixo" })
map("n", "<leader>k", "<cmd>t.-1<cr>", { desc = "Duplicar linha acima" })

-- ──────────────────────────────────────────────────────────────────────────────
-- QUICKFIX E LOCATION LIST
-- ──────────────────────────────────────────────────────────────────────────────

map("n", "[q", "<cmd>cprevious<cr>", { desc = "Item anterior do quickfix" })
map("n", "]q", "<cmd>cnext<cr>", { desc = "Próximo item do quickfix" })
map("n", "[l", "<cmd>lprevious<cr>", { desc = "Item anterior do location list" })
map("n", "]l", "<cmd>lnext<cr>", { desc = "Próximo item do location list" })

-- ──────────────────────────────────────────────────────────────────────────────
-- DIAGNÓSTICOS
-- ──────────────────────────────────────────────────────────────────────────────

map("n", "[d", vim.diagnostic.goto_prev, { desc = "Diagnóstico anterior" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Próximo diagnóstico" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Mostrar diagnóstico" })

-- ──────────────────────────────────────────────────────────────────────────────
-- TERMINAL
-- ──────────────────────────────────────────────────────────────────────────────

-- Sair do terminal com Esc
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Sair do modo terminal" })

-- Navegar do terminal com Ctrl+hjkl
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Ir para janela da esquerda" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Ir para janela de baixo" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Ir para janela de cima" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Ir para janela da direita" })

-- ──────────────────────────────────────────────────────────────────────────────
-- ATALHOS ÚTEIS
-- ──────────────────────────────────────────────────────────────────────────────

-- Selecionar todo o arquivo
map("n", "<C-a>", "gg<S-v>G", { desc = "Selecionar tudo" })

-- Adicionar linha em branco sem entrar no modo de inserção
map("n", "<leader>o", "o<Esc>", { desc = "Nova linha abaixo" })
map("n", "<leader>O", "O<Esc>", { desc = "Nova linha acima" })

-- Substituir palavra sob cursor
map("n", "<leader>rw", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Substituir palavra" })

-- Tornar arquivo executável
map("n", "<leader>x", "<cmd>!chmod +x %<cr>", { silent = true, desc = "Tornar executável" })

-- Source arquivo atual (para config)
map("n", "<leader><leader>x", "<cmd>source %<cr>", { desc = "Source arquivo atual" })

-- ══════════════════════════════════════════════════════════════════════════════
-- ATALHOS RÁPIDOS (REFERÊNCIA)
-- ══════════════════════════════════════════════════════════════════════════════
--
-- LEADER = Espaço
--
-- ARQUIVOS:
--   <leader>ff = Buscar arquivos
--   <leader>fg = Buscar com grep
--   <leader>fr = Arquivos recentes
--   <leader>e  = Explorador de arquivos
--
-- CÓDIGO:
--   gd = Ir para definição
--   gr = Ver referências
--   K  = Hover documentation
--   <leader>ca = Code actions
--   <leader>cr = Renomear
--   <leader>cf = Formatar
--
-- GIT:
--   <leader>gg = Lazygit
--   <leader>gd = Diff
--   <leader>gb = Blame
--
-- BUFFERS:
--   <Tab>       = Próximo buffer
--   <S-Tab>     = Buffer anterior
--   <leader>bd  = Fechar buffer
--
-- JANELAS:
--   ss = Split horizontal
--   sv = Split vertical
--   Ctrl+hjkl = Navegar janelas
--
-- ══════════════════════════════════════════════════════════════════════════════
