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
  local max="$2"
  local -n out_ref="$3"
  out_ref=()

  local line=""
  local word=""
  for word in $text; do
    if [[ -z "$line" ]]; then
      if [[ ${#word} -le $max ]]; then
        line="$word"
      else
        local chunk="$word"
        while [[ ${#chunk} -gt $max ]]; do
          out_ref+=("${chunk:0:$max}")
          chunk="${chunk:$max}"
        done
        line="$chunk"
      fi
    else
      local test="${line} ${word}"
      if [[ ${#test} -le $max ]]; then
        line="$test"
      else
        out_ref+=("$line")
        line="$word"
      fi
    fi
  done

  [[ -n "$line" ]] && out_ref+=("$line")
}
