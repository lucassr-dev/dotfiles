#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════
# Text Utilities — Funções compartilhadas de processamento de texto
# ═══════════════════════════════════════════════════════════

_strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

_visible_len() {
  local text="$1"
  local clean
  clean=$(printf '%s' "$text" | _strip_ansi)
  local display_w
  display_w=$(printf '%s' "$clean" | wc -L 2>/dev/null) || display_w=${#clean}
  echo "$display_w"
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
    if (( ${#current} + 1 + ${#word} <= max_width )); then
      current="$current $word"
    else
      out_lines+=("$current")
      current="$word"
    fi
  done

  [[ -n "$current" ]] && out_lines+=("$current")
}
