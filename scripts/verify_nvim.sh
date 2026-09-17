#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Verificacao da configuracao do Neovim — criterios de aceite da Fase 2
# ══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

BASELINE_MODE=0
[[ "${1:-}" == "--baseline" ]] && BASELINE_MODE=1

# Limite de sanidade contra crescimento descontrolado, nao a medida principal de
# regressao de duplicacao — essa e o criterio nominal abaixo ("Plugins que deveriam
# ter sido removidos"), que detecta a volta de cada plugin especifico diretamente.
MAX_PLUGINS=70
# Recalibrado por decisao do dono apos a fase que adicionou 6 plugins em 3 extras
# (dap.core: nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, mason-nvim-dap; util.rest:
# kulala.nvim; util.octo: octo.nvim) — mais specs para o lazy.nvim processar, mediana
# subiu do baseline auditado de 43 ms (plugins=56, /tmp/nvim-baseline.txt) para a
# faixa saudavel pos-fase de 52-59 ms.
# Limitacao conhecida, registrada de proposito: essa recalibracao perdeu a protecao
# contra o baseline pre-Fase 2 (58 ms, docs/specs/2026-09-15-neovim-fase2-design.md:29)
# — em wall-clock, 58 ms e indistinguivel da mediana saudavel atual (medido: 59 ms com
# a maquina sob carga 2.36), entao uma regressao a esse nivel especifico passa pelo
# teto sem ser detectada. Os 107 ms citados no design da Fase 2 sao o tempo com o bug
# de lspconfig ativo (corrigido na propria Fase 2, nao volta por si so) — nao servem
# de referencia do que este teto protege.
# Metrica inalterada: wall-clock (nao --startuptime interno), mediana (nao minimo nem
# percentil), 11 amostras.
MAX_STARTUP_MS=65
REPO_NVIM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/nvim"
LIVE_NVIM="$HOME/.config/nvim"
TS_FILE="$HOME/work/inovanti-credit-web/src/App.tsx"
ESPERADO_LSP="copilot eslint tailwindcss vtsls"

FALHAS=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FALHAS=$((FALHAS + 1)); }
info() { printf '  \033[34m•\033[0m %s\n' "$1"; }

nvim_bin() {
  if command -v nvim >/dev/null 2>&1 && nvim --version | head -1 | grep -qE 'v0\.(1[2-9]|[2-9][0-9])'; then
    echo "nvim"
  elif command -v mise >/dev/null 2>&1; then
    echo "mise exec neovim@0.12.5 -- nvim"
  else
    echo "nvim"
  fi
}
NVIM="$(nvim_bin)"

echo "▶ Versao do Neovim"
VER="$($NVIM --version 2>/dev/null | head -1)"
if echo "$VER" | grep -qE 'v0\.(1[2-9]|[2-9][0-9])'; then
  ok "$VER"
else
  fail "esperado 0.12+, obtido: ${VER:-nenhum}"
fi

echo "▶ Startup sem erro"
SAIDA="$($NVIM --headless +qa 2>&1 | grep -viE '^$|zoxide|_ZO_DOCTOR|configuration issue|ajeetdsouza|Please ensure|If the issue')"
if [[ -z "$SAIDA" ]]; then
  ok "nenhuma saida de erro"
else
  fail "saida inesperada no startup:"
  echo "$SAIDA" | head -10 | sed 's/^/      /'
fi

echo "▶ Contagem de plugins"
N_PLUGINS="$($NVIM --headless "+lua local n=0 for _ in pairs(require('lazy.core.config').plugins) do n=n+1 end io.stderr:write(n)" +qa 2>&1 | grep -oE '^[0-9]+$' | head -1)"
N_PLUGINS="${N_PLUGINS:-999}"
if (( N_PLUGINS < MAX_PLUGINS )); then
  ok "$N_PLUGINS plugins (limite: $MAX_PLUGINS)"
else
  fail "$N_PLUGINS plugins, esperado menos de $MAX_PLUGINS"
fi

echo "▶ Tempo de startup"
# Mediana de 11 execucoes, descartando a primeira (cache frio). A media simples se
# mostrou sensivel demais a carga da maquina: variou de 58 a 89 ms na mesma config.
# Eram 7 amostras, mas com 3 novos extras lazy / 6 plugins novos (nenhum carrega no
# startup — so o lazy.nvim processa mais specs) a mediana de 7 oscilou 49/49/55/49/48 ms
# contra o teto de 55, uma falha em cinco execucoes ociosas: ruido de medicao, nao
# regressao.
# 11 amostras reduz esse ruido sem mascarar uma regressao real. Com 11 valores
# ordenados a mediana e o 6o elemento, indice 5 em array base-zero.
$NVIM --headless +qa >/dev/null 2>&1
AMOSTRAS=()
for _ in 1 2 3 4 5 6 7 8 9 10 11; do
  INICIO=$(date +%s%N)
  $NVIM --headless +qa >/dev/null 2>&1
  FIM=$(date +%s%N)
  AMOSTRAS+=( $(( (FIM - INICIO) / 1000000 )) )
done
mapfile -t ORDENADAS < <(printf '%s\n' "${AMOSTRAS[@]}" | sort -n)
MEDIA="${ORDENADAS[5]}"
if (( MEDIA < MAX_STARTUP_MS )); then
  ok "${MEDIA} ms mediana (limite: ${MAX_STARTUP_MS} ms) — amostras: ${ORDENADAS[*]}"
else
  fail "${MEDIA} ms mediana, esperado menos de ${MAX_STARTUP_MS} ms — amostras: ${ORDENADAS[*]}"
fi

echo "▶ LSPs em arquivo TypeScript real"
if [[ -f "$TS_FILE" ]]; then
  # Cada nome de LSP e emitido numa linha propria com prefixo, para nao depender de
  # separador em regex: grep -o consome o delimitador e pula termos alternados.
  # timeout 30 evita que um erro de Lua antes do defer_fn deixe o nvim --headless
  # pendurado indefinidamente (o modo de falha vira FAIL, nao hang).
  LSPS="$(timeout 30 $NVIM --headless "$TS_FILE" \
    "+lua vim.defer_fn(function()
       local n={} for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do n[#n+1]=c.name end
       table.sort(n)
       for _, nome in ipairs(n) do io.stderr:write('LSPCLIENT:' .. nome .. '\n') end
       vim.cmd('qa!') end, 20000)" 2>&1 \
    | sed -n 's/^LSPCLIENT://p' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  if [[ "$LSPS" == "$ESPERADO_LSP" ]]; then
    ok "$LSPS"
  else
    fail "obtido '$LSPS', esperado '$ESPERADO_LSP'"
  fi
else
  info "arquivo de teste ausente, pulado: $TS_FILE"
fi

echo "▶ Plugins que deveriam ter sido removidos"
REMOVIDOS="telescope.nvim telescope-file-browser.nvim neo-tree.nvim mini.files dashboard-nvim indent-blankline.nvim mini.animate Comment.nvim nvim-autopairs LuaSnip neotest-pest neotest-phpunit neotest-python venv-selector.nvim typst-preview.nvim telescope-terraform.nvim telescope-terraform-doc.nvim"
PRESENTES="$($NVIM --headless "+lua
local c = require('lazy.core.config')
local alvo = vim.split([[$REMOVIDOS]], ' ')
for _, nome in ipairs(alvo) do
  if nome ~= '' and c.plugins[nome] then io.stderr:write('ORFAO:' .. nome .. '\n') end
end" +qa 2>&1 | sed -n 's/^ORFAO://p' | sort -u | tr '\n' ' ')"
if [[ -z "${PRESENTES// /}" ]]; then
  ok "nenhum plugin removido continua instalado"
else
  fail "ainda instalados: $PRESENTES"
fi

echo "▶ Extras em fonte unica"
if grep -q 'lazyvim\.plugins\.extras' "$LIVE_NVIM/lua/config/lazy.lua" 2>/dev/null; then
  fail "lazy.lua ainda declara extras; a fonte unica deve ser lazyvim.json"
else
  ok "lazy.lua nao declara extras"
fi

echo "▶ Atalhos criticos (colisoes resolvidas nas fases anteriores)"
# LazyVim carrega grande parte dos keymaps no evento VeryLazy, que depende de
# UIEnter e nunca dispara por conta propria em --headless. Ler keymaps sem forcar
# o evento a mao daria falso negativo generalizado — medido: 238 keymaps lidos (nao
# "poucas dezenas") e 10 dos 16 checks abaixo falhando, entre eles o mais importante
# do bloco, git-stash-vs-octo. Por isso o bloco dispara VeryLazy manualmente.
# Guarda: um limiar de contagem nao distingue os dois estados — 238 (sem disparo) e
# 343 (com disparo) ficam ambos "altos"; qualquer limiar que reprovasse 238 teria
# que ficar perto de 300+, fragil a variacao normal entre maquinas. Em vez disso a
# guarda exige a presenca de <leader>gg (lazygit), atalho que so existe depois do
# VeryLazy e que esta entre os 10 que desaparecem sem ele — se ausente, os
# resultados individuais abaixo nao sao confiaveis.
# timeout 30 evita que um erro de Lua antes do defer_fn deixe o nvim --headless
# pendurado indefinidamente (o modo de falha vira FAIL, nao hang).
# O defer de leitura foi reduzido de 7000ms para 500ms: nvim_exec_autocmds despacha
# o VeryLazy de forma sincrona, o carregamento ja terminou quando o defer roda.
# Medido: 10ms e 7000ms dao os mesmos 343 mapas e os mesmos 16 resultados; 500ms
# fica de margem confortavel sem os ~6,5s desperdicados por execucao.
KEYMAP_SAIDA="$(timeout 30 $NVIM --headless "+lua
vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
vim.defer_fn(function()
  local maps = vim.api.nvim_get_keymap('n')
  local by_lhs = {}
  for _, m in ipairs(maps) do by_lhs[m.lhs] = m.desc or '' end
  io.stderr:write('TOTALMAPS:' .. #maps .. '\n')
  io.stderr:write('VERYLAZY_SENTINEL:' .. (by_lhs[' gg'] ~= nil and '1' or '0') .. '\n')

  local function chk(rotulo, tecla, desc_esperado)
    local lhs = tecla:gsub('<leader>', ' ')
    local obtido = by_lhs[lhs]
    if obtido == desc_esperado then
      io.stderr:write('PASS:' .. rotulo .. ' (' .. tecla .. ') -> ' .. desc_esperado .. '\n')
    elseif obtido == nil then
      io.stderr:write('FAIL:' .. rotulo .. ' (' .. tecla .. ') ausente; esperado \"' .. desc_esperado .. '\"\n')
    else
      io.stderr:write('FAIL:' .. rotulo .. ' (' .. tecla .. ') aponta para \"' .. obtido .. '\"; esperado \"' .. desc_esperado .. '\"\n')
    end
  end

  -- Busca via snacks.picker (prefixo ; — telescope removido nas fases anteriores)
  chk('busca-arquivos', ';f', 'Buscar arquivos')
  chk('busca-grep', ';r', 'Buscar texto (grep)')
  chk('busca-buffers', ';b', 'Listar buffers')
  chk('busca-ajuda', ';h', 'Buscar ajuda')
  chk('busca-diagnosticos', ';e', 'Listar diagnosticos')
  chk('busca-simbolos', ';s', 'Simbolos do documento')
  chk('busca-resume', ';;', 'Continuar ultima busca')
  -- Git Stash preservado contra o override do octo (shared/nvim/lua/plugins/git.lua)
  chk('git-stash-vs-octo', '<leader>gS', 'Git Stash')
  chk('lazygit', '<leader>gg', 'Lazygit (Root Dir)')
  -- Busca do Octo realocada para <leader>go, liberando <leader>gS para o Git Stash
  chk('octo-search-realocada', '<leader>go', 'Search (Octo)')
  -- Deletar sem copiar: movido de <leader>d para <leader>D, liberando o grupo de debug
  chk('deletar-sem-copiar', '<leader>D', 'Deletar sem copiar')
  -- Tornar executavel: movido de <leader>x para <leader>cx, liberando o grupo Trouble
  chk('tornar-executavel', '<leader>cx', 'Tornar executavel')
  -- <leader>e e o explorer (snacks_explorer), nao diagnosticos (LazyVim v1 antigo)
  chk('explorer-nao-diagnostico', '<leader>e', 'Explorer Snacks (root dir)')
  -- package-info: movido de <leader>n (Notification History) para <leader>i
  chk('package-info-realocado', '<leader>is', 'Mostrar versoes das dependencias')
  -- Trouble API v3
  chk('trouble-v3', '<leader>xx', 'Diagnosticos (documento)')

  -- Removido de proposito para liberar <leader><space> (Find Files) sem latencia
  local leader_leader_x = by_lhs['  x']
  if leader_leader_x == nil then
    io.stderr:write('PASS:leader-leader-x removido corretamente (nao existe, libera <leader><space>)\n')
  else
    io.stderr:write('FAIL:leader-leader-x deveria ter sido removido, mas ainda aponta para \"' .. leader_leader_x .. '\"\n')
  end

  vim.cmd('qa!')
end, 500)
" 2>&1)"

N_KEYMAPS="$(echo "$KEYMAP_SAIDA" | grep -oE '^TOTALMAPS:[0-9]+$' | head -1 | cut -d: -f2)"
N_KEYMAPS="${N_KEYMAPS:-0}"
SENTINEL="$(echo "$KEYMAP_SAIDA" | grep -oE '^VERYLAZY_SENTINEL:[01]$' | head -1 | cut -d: -f2)"
if [[ "$SENTINEL" == "1" ]]; then
  ok "VeryLazy disparado, $N_KEYMAPS keymaps lidos (sentinela <leader>gg presente)"
else
  fail "VeryLazy pode nao ter disparado — sentinela <leader>gg (lazygit) ausente; $N_KEYMAPS keymaps lidos; resultados abaixo nao sao confiaveis"
fi

while IFS= read -r LINHA; do
  case "$LINHA" in
    PASS:*) ok "${LINHA#PASS:}" ;;
    FAIL:*) fail "${LINHA#FAIL:}" ;;
  esac
done <<< "$KEYMAP_SAIDA"

echo "▶ Repositorio sincronizado com o sistema"
if [[ -d "$REPO_NVIM" ]]; then
  DIFF="$(diff -rq -x 'lazy-lock.json' "$REPO_NVIM" "$LIVE_NVIM" 2>&1 | grep -v '\.git' || true)"
  if [[ -z "$DIFF" ]]; then
    ok "shared/nvim identico a ~/.config/nvim"
  else
    fail "divergencia entre repo e sistema:"
    echo "$DIFF" | head -10 | sed 's/^/      /'
  fi
else
  fail "diretorio ausente: $REPO_NVIM"
fi

echo
if (( BASELINE_MODE == 1 )); then
  {
    echo "plugins=$N_PLUGINS"
    echo "startup_ms=$MEDIA"
    echo "data=$(date -Iseconds)"
  } > /tmp/nvim-baseline.txt
  echo "Baseline gravado em /tmp/nvim-baseline.txt: $N_PLUGINS plugins, ${MEDIA} ms"
  exit 0
fi

if (( FALHAS == 0 )); then
  printf '\033[32mTodos os criterios passaram.\033[0m\n'
  exit 0
fi
printf '\033[31m%d criterio(s) falharam.\033[0m\n' "$FALHAS"
exit 1
