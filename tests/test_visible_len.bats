#!/usr/bin/env bats
#
# Largura visivel de texto (_visible_len).
#
# Esta e a medida que decide todo alinhamento do script: moldura, coluna,
# preenchimento e quebra de linha passam por aqui. Errar por 1 coluna num
# caractere deixa a borda direita de uma tela inteira desalinhada.
#
# O defeito que motivou a suite: _visible_len fazia `wc -L` e SOMAVA +1 para
# cada caractere de uma lista, assumindo que o wc subconta emoji. Isso nao e
# propriedade do Unicode, e propriedade da implementacao do wc:
#
#   GNU coreutils      -- subconta varios emoji em 1 coluna
#   uutils (Rust)      -- conta certo, tabela Unicode moderna
#
# Numa maquina com uutils a compensacao virava dobra, e os cabecalhos do
# relatorio pos-instalacao saiam com 95, 96 e 98 colunas onde todos deviam
# dar 96. A lista tambem misturava classes: tinha 12 simbolos de largura 1
# (setas, ✓, ✗, ⚙, e 🗂/🗄/🗑, que nao tem apresentacao emoji por padrao) e
# faltavam 23 emoji de largura 2 que o script usa.
#
# As larguras esperadas abaixo sao fixas de proposito: o oraculo tem que ser
# o Unicode, nao o `wc` da maquina que roda o teste.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

_len() {
  bash -c "
    cd '$REPO_ROOT'
    . lib/core.sh
    . lib/utils.sh
    _visible_len \"\$1\"
  " _ "$1"
}

@test "ASCII puro conta um por caractere" {
  [ "$(_len 'instalando pacotes')" -eq 18 ]
  [ "$(_len '')" -eq 0 ]
}

@test "string colorida conta so o texto visivel" {
  # As cores deste codebase sao TEXTO literal ("\033[...m"), viram escape so
  # no printf %b. Uma string colorida e toda ASCII imprimivel, entao o caminho
  # rapido a aceitaria e contaria os ~20 caracteres de cada codigo de cor.
  local colorido='\033[38;2;203;166;247m\033[1mTemas\033[0m'
  [ "$(_len "$colorido")" -eq 5 ]
}

@test "emoji de largura 2 conta 2" {
  local c
  for c in ⚡ ✅ ❌ ❓ ⭐ 🌍 🍎 🎨 🎯 🏠 💻 💡 💾 📁 📊 📋 📌 📖 📝 📦 🔄 🔐 🔑 🔗 🔧 🤖 🦀 🧰; do
    if [ "$(_len "$c")" -ne 2 ]; then
      echo "\"$c\" contou $(_len "$c"), esperado 2" >&2
      return 1
    fi
  done
}

@test "simbolo de largura 1 conta 1" {
  # Sao ambiguos no East Asian Width: terminal em locale latino desenha 1.
  # A lista antiga somava +1 em todos eles.
  local c
  for c in ← ↑ → ↓ ↔ ⚙ ✏ ✓ ✗ ▶ ▸ ⚠ ★ ℹ ⌨ 🗂 🗄 🗑 🖥 🛠; do
    if [ "$(_len "$c")" -ne 1 ]; then
      echo "\"$c\" contou $(_len "$c"), esperado 1" >&2
      return 1
    fi
  done
}

@test "acento conta um por caractere, nao por byte" {
  [ "$(_len 'Extensões')" -eq 9 ]
  [ "$(_len 'Padrões do Sistema')" -eq 18 ]
  [ "$(_len 'configuração')" -eq 12 ]
}

@test "caractere de moldura conta 1" {
  local c
  for c in ─ │ ╭ ╮ ╰ ╯ ━ █ ░ ═ ║; do
    if [ "$(_len "$c")" -ne 1 ]; then
      echo "\"$c\" contou $(_len "$c"), esperado 1" >&2
      return 1
    fi
  done
}

@test "mistura de emoji, acento e moldura soma certo" {
  #  "📌 STATUS"  = 2 + 1 + 6 = 9
  [ "$(_len '📌 STATUS')" -eq 9 ]
  #  "── 🔧 FERRAMENTAS" = 2 + 1 + 2 + 1 + 11 = 17
  [ "$(_len '── 🔧 FERRAMENTAS')" -eq 17 ]
  #  "✓ Concluido" = 1 + 1 + 9 = 11, o valor que step_end assume fixo
  [ "$(_len '✓ Concluido')" -eq 11 ]
}

@test "cabecalhos do relatorio pos-instalacao tem todos a mesma largura" {
  # Integracao: e aqui que o erro de 1 coluna aparecia para o usuario.
  local saida larguras distintas
  saida=$(TERM=dumb COLUMNS=100 bash -c "
    cd '$REPO_ROOT'
    . lib/core.sh
    . lib/colors.sh 2>/dev/null
    . lib/utils.sh
    . lib/components.sh
    . lib/ui.sh
    . lib/banner.sh
    . lib/report.sh
    TARGET_OS=linux
    ui_term_cols() { echo 100; }
    print_post_install_report 2>/dev/null
  " | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' | grep -E '^\s+──')

  [ -n "$saida" ]

  larguras=$(while IFS= read -r l; do printf '%s' "$l" | wc -L; done <<< "$saida")
  distintas=$(echo "$larguras" | sort -u | wc -l)
  if [ "$distintas" -ne 1 ]; then
    echo "cabecalhos sairam com larguras diferentes:" >&2
    echo "$larguras" | sort | uniq -c >&2
    return 1
  fi
}
