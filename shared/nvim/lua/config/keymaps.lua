-- ══════════════════════════════════════════════════════════════════════════════
-- KEYMAPS CUSTOMIZADOS
--
-- Apenas o que diverge do LazyVim. Atalhos que o LazyVim ja define nao sao
-- redeclarados aqui. Consultar o mapa completo na secao LazyVim do README.
-- ══════════════════════════════════════════════════════════════════════════════

local map = vim.keymap.set

-- ──────────────────────────────────────────────────────────────────────────────
-- GERAIS
-- ──────────────────────────────────────────────────────────────────────────────

map("i", "jk", "<Esc>", { desc = "Sair do modo de insercao" })
map("i", "jj", "<Esc>", { desc = "Sair do modo de insercao" })
map({ "n", "i", "v", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Salvar arquivo" })
map("n", "<C-q>", "<cmd>qa<cr>", { desc = "Sair do Neovim" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Limpar highlight da busca" })

-- ──────────────────────────────────────────────────────────────────────────────
-- BUSCA (PREFIXO ;)
--
-- Substitui os antigos atalhos de Telescope pelo snacks.picker.
-- ──────────────────────────────────────────────────────────────────────────────

map("n", ";f", function() Snacks.picker.files() end, { desc = "Buscar arquivos" })
map("n", ";r", function() Snacks.picker.grep() end, { desc = "Buscar texto (grep)" })
map("n", ";b", function() Snacks.picker.buffers() end, { desc = "Listar buffers" })
map("n", ";h", function() Snacks.picker.help() end, { desc = "Buscar ajuda" })
map("n", ";e", function() Snacks.picker.diagnostics() end, { desc = "Listar diagnosticos" })
map("n", ";s", function() Snacks.picker.lsp_symbols() end, { desc = "Simbolos do documento" })
map("n", ";;", function() Snacks.picker.resume() end, { desc = "Continuar ultima busca" })

-- ──────────────────────────────────────────────────────────────────────────────
-- NAVEGACAO
--
-- <C-hjkl> nao e definido aqui: vem do vim-tmux-navigator, em plugins/editor.lua.
-- ──────────────────────────────────────────────────────────────────────────────

map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Aumentar altura da janela" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Diminuir altura da janela" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Diminuir largura da janela" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Aumentar largura da janela" })

map("n", "H", "^", { desc = "Inicio da linha" })
map("n", "L", "$", { desc = "Fim da linha" })

map("n", "<C-d>", "<C-d>zz", { desc = "Meia pagina para baixo" })
map("n", "<C-u>", "<C-u>zz", { desc = "Meia pagina para cima" })
map("n", "n", "nzzzv", { desc = "Proxima ocorrencia" })
map("n", "N", "Nzzzv", { desc = "Ocorrencia anterior" })

-- ──────────────────────────────────────────────────────────────────────────────
-- EDICAO
-- ──────────────────────────────────────────────────────────────────────────────

map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Mover selecao para baixo" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Mover selecao para cima" })
map("v", "<", "<gv", { desc = "Diminuir indentacao" })
map("v", ">", ">gv", { desc = "Aumentar indentacao" })
map("n", "J", "mzJ`z", { desc = "Juntar linhas" })

map("x", "<leader>p", '"_dP', { desc = "Colar sem substituir register" })
map({ "n", "v" }, "<leader>D", '"_d', { desc = "Deletar sem copiar" })

map("n", "<leader>j", "<cmd>t.<cr>", { desc = "Duplicar linha abaixo" })
map("n", "<leader>k", "<cmd>t.-1<cr>", { desc = "Duplicar linha acima" })
map("n", "<leader>o", "o<Esc>", { desc = "Nova linha abaixo" })
map("n", "<leader>O", "O<Esc>", { desc = "Nova linha acima" })

-- ──────────────────────────────────────────────────────────────────────────────
-- DIAGNOSTICOS
--
-- vim.diagnostic.jump substitui goto_prev/goto_next, deprecados no 0.11.
-- ──────────────────────────────────────────────────────────────────────────────

map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Diagnostico anterior" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Proximo diagnostico" })

-- ──────────────────────────────────────────────────────────────────────────────
-- TERMINAL
-- ──────────────────────────────────────────────────────────────────────────────

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Sair do modo terminal" })
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Ir para janela da esquerda" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Ir para janela de baixo" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Ir para janela de cima" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Ir para janela da direita" })

-- ──────────────────────────────────────────────────────────────────────────────
-- UTILITARIOS
-- ──────────────────────────────────────────────────────────────────────────────

map("n", "<leader>cx", "<cmd>!chmod +x %<cr>", { silent = true, desc = "Tornar executavel" })
