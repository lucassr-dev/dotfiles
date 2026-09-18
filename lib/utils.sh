#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════
# Text Utilities — Funções compartilhadas de processamento de texto
# ═══════════════════════════════════════════════════════════

_strip_ansi() {
  # Remove both actual ESC bytes (\x1b) and bash literal forms (\033 / \e)
  # Colors in this codebase are defined as "\033[...m" strings (not $'\033[...m'),
  # so they contain literal backslash+033 — not the ESC byte — until printf %b renders them.
  sed -E 's/\x1b\[[0-9;]*m//g; s/\\(033|e)\[[0-9;]*m//g'
}

# Os caracteres de largura 2 usados no codebase. Ao acrescentar um, meca com
# `printf %s CHAR | wc -L` antes -- nem todo emoji ocupa duas colunas.
#
# Alternation, NAO bracket class: em [abc] o grep casa cada BYTE do UTF-8
# separadamente e um 🔧 conta 4. `-E` e nao `-P` porque o grep do macOS nao
# tem -P.
_WIDE_CHARS_REGEX='(⏩|⚡|✅|✨|❌|❓|⭐|🌍|🌐|🍎|🍺|🎨|🎭|🎯|🎵|🏠|🐚|🐟|🐧|👤|👻|💡|💬|💻|💼|💾|📁|📂|📄|📊|📋|📌|📍|📖|📚|📝|📤|📥|📦|🔄|🔌|🔎|🔐|🔑|🔒|🔗|🔤|🔧|🤖|🦀|🧰)'

# O GNU coreutils subconta emoji no `wc -L`; o uutils conta certo. Compensar
# as cegas dobra a conta em metade das maquinas, entao pergunta uma vez.
_WC_SUBCONTA_WIDE=""
_wc_subconta_wide() {
  if [[ -z "$_WC_SUBCONTA_WIDE" ]]; then
    local medido
    medido=$(printf '%s' '📌' | wc -L 2>/dev/null) || medido=""
    if [[ "$medido" == "2" ]]; then
      _WC_SUBCONTA_WIDE=0
    else
      _WC_SUBCONTA_WIDE=1
    fi
  fi
  [[ "$_WC_SUBCONTA_WIDE" == "1" ]]
}

_conta_wide() {
  printf '%s' "$1" | grep -oE "$_WIDE_CHARS_REGEX" 2>/dev/null | wc -l
}

_visible_len() {
  local text="$1"

  # Caminho rapido para ASCII: o lento abre tres subprocessos por chamada, e
  # _wrap_text chama isto uma vez por palavra (no Git Bash isso custou 3-5s
  # POR LINHA e estourou o CI).
  #
  # A exclusao da barra invertida NAO e zelo: as cores aqui sao texto literal
  # ("\033[...m"), entao uma string colorida e toda ASCII imprimivel e o
  # caminho rapido contaria cada codigo de cor como ~20 colunas visiveis.
  if [[ "$text" != *$'\033'* && "$text" != *'\'* && "$text" != *[!$'\x20'-$'\x7e']* ]]; then
    echo "${#text}"
    return 0
  fi
  local clean
  clean=$(printf '%s' "$text" | _strip_ansi)

  local display_w
  if display_w=$(printf '%s' "$clean" | wc -L 2>/dev/null) && [[ "$display_w" =~ ^[0-9]+$ ]]; then
    # Onde o wc -L ja conhece a largura dos emoji, nao ha nada a compensar --
    # e ainda economiza os dois subprocessos de _conta_wide por chamada, que
    # e o custo que fez o seletor de apps travar no Git Bash.
    if _wc_subconta_wide; then
      display_w=$(( display_w + $(_conta_wide "$clean") ))
    fi
    echo "$display_w"
  else
    # Sem wc -L: ${#clean} conta CARACTERES, entao todo caractere de largura 2
    # precisa do +1, independente de qual wc a maquina tem.
    echo $(( ${#clean} + $(_conta_wide "$clean") ))
  fi
}

_wrap_text() {
  local text="$1"
  local max_width="$2"
  local -n out_lines="$3"

  out_lines=()
  if [[ -z "$text" ]]; then
    out_lines+=("")
    return 0
  fi

  local current=""
  local word
  local -a words=()
  read -r -a words <<< "$text"

  for word in "${words[@]}"; do
    # Palavra sozinha mais larga que max_width (path ou URL sem espaco pra
    # quebrar) nao tem ponto de quebra natural -- corta em pedacos de
    # max_width caracteres. So seguro pra ASCII (path/URL sao); largura de
    # exibicao de caractere largo/emoji e outra conta, fora do caso aqui.
    if (( $(_visible_len "$word") > max_width )); then
      if [[ -n "$current" ]]; then
        out_lines+=("$current")
        current=""
      fi
      local remaining="$word"
      while (( $(_visible_len "$remaining") > max_width )); do
        out_lines+=("${remaining:0:max_width}")
        remaining="${remaining:max_width}"
      done
      current="$remaining"
      continue
    fi
    if [[ -z "$current" ]]; then
      current="$word"
    else
      local cur_w word_w
      cur_w=$(_visible_len "$current")
      word_w=$(_visible_len "$word")
      if (( cur_w + 1 + word_w <= max_width )); then
        current="$current $word"
      else
        out_lines+=("$current")
        current="$word"
      fi
    fi
  done

  [[ -n "$current" ]] && out_lines+=("$current")
}

# ═══════════════════════════════════════════════════════════
# Constantes de timeout para curl (unificar em toda a codebase)
# ═══════════════════════════════════════════════════════════
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-10}"
CURL_TIMEOUT_FAST="${CURL_TIMEOUT_FAST:-15}"      # Imagens de preview, checks rápidos
CURL_TIMEOUT_NORMAL="${CURL_TIMEOUT_NORMAL:-120}" # Fontes, plugins, tarballs pequenos
CURL_TIMEOUT_LONG="${CURL_TIMEOUT_LONG:-180}"     # Scripts de instalação, arquivos grandes

# Gera array de argumentos seguros para curl com timeout configurável.
# Uso: local -a args; read -r -a args <<< "$(make_curl_args 120)"
# Ou:  curl $(make_curl_args 180) -o file URL
make_curl_args() {
  local max_time="${1:-$CURL_TIMEOUT_LONG}"
  local connect_timeout="${2:-$CURL_CONNECT_TIMEOUT}"
  echo "-fsSL --proto =https --tlsv1.2 --retry 3 --retry-delay 1 --connect-timeout $connect_timeout --max-time $max_time"
}
