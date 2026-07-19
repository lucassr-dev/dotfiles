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

# Emoji/simbolos usados no codebase onde `wc -L` REALMENTE subconta 1 coluna
# (verificado individualmente, um por um, contra `wc -L` -- nao assumido).
# Achado real: nem todo emoji e subcontado -- de 69 usados no repo, so 39
# vieram errado (ex: 🔧/▶/🤖 ja contam certo aqui; ←/📁/⭐ nao). Uma lista
# "todo emoji soma +1" chutada teria SOBRE-compensado quase a metade dos
# casos -- pior que o bug original. Revalidar se `wc -L` mudar de versao/OS.
#
# Alternation (a|b|c), NAO bracket class [abc]: bracket class quebra pra
# caracteres multi-byte neste grep (cada BYTE do UTF-8 vira um match
# separado -- um unico 🔧 contava como 4). Alternation trata cada emoji como
# unidade atomica, testado ao vivo. `-E` (nao `-P`) de proposito: grep do
# macOS (BSD) nao tem suporte a -P.
_WIDE_CHARS_REGEX='(←|↑|→|↓|↔|⚙|✅|✏|✓|✗|❌|❓|⭐|🌍|🌐|🍎|🎭|🐚|🐟|📁|📂|📄|📊|📋|📌|📍|📖|📚|📝|🔄|🔌|🔎|🔐|🔑|🔒|🔗|🗂|🗄|🗑)'

_visible_len() {
  local text="$1"
  local clean
  clean=$(printf '%s' "$text" | _strip_ansi)

  local wide_count=0
  wide_count=$(printf '%s' "$clean" | grep -oE "$_WIDE_CHARS_REGEX" 2>/dev/null | wc -l) || wide_count=0

  local display_w
  if display_w=$(printf '%s' "$clean" | wc -L 2>/dev/null); then
    # wc -L conta a maioria dos wide chars certo, mas subconta emoji comuns em
    # 1 coluna cada -- compensa com a lista acima (achado de auditoria).
    echo $((display_w + wide_count))
  else
    # Fallback se wc -L nao existir/falhar: comprimento em bytes + compensacao.
    echo $((${#clean} + wide_count))
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
    if [[ -z "$current" ]]; then
      current="$word"
      continue
    fi
    local cur_w word_w
    cur_w=$(_visible_len "$current")
    word_w=$(_visible_len "$word")
    if (( cur_w + 1 + word_w <= max_width )); then
      current="$current $word"
    else
      out_lines+=("$current")
      current="$word"
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
