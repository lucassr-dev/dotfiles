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

_visible_len() {
  local text="$1"
  local clean
  clean=$(printf '%s' "$text" | _strip_ansi)
  local display_w
  if display_w=$(printf '%s' "$clean" | wc -L 2>/dev/null); then
    # wc -L counts display columns (handles wide chars/emoji on most platforms)
    echo "$display_w"
  else
    # Fallback: byte length + 1 extra per common wide emoji
    local emoji_count
    emoji_count=$(printf '%s' "$clean" | grep -oE '[🔌🎨🖼✨🎭🐟🔤🛠🤖💻🐚📦🔐📋🖥🧰🌐📝🏠⚡💡📂🔧🐧👤📁🔄⏭✅❌⚠ℹ🍺🔑🗂📤⏱🎯🔢📊]' 2>/dev/null | wc -l) || emoji_count=0
    echo $((${#clean} + emoji_count))
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
