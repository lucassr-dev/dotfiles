#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════
# UI Components — Componentes visuais reutilizáveis
# ═══════════════════════════════════════════════════════════
#
# Requer: lib/colors.sh (design tokens)
# Requer: lib/utils.sh (_strip_ansi, _visible_len)

# ─── Box com título ───────────────────────────────────────
# Uso: ui_box "Título" "Conteúdo linha 1\nLinha 2"
ui_box() {
  local title="$1"
  local content="$2"
  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local width=$((term_w > 70 ? 70 : term_w - 4))
  local inner=$((width - 2))

  local title_vis=${#title}
  local line_len=$((inner - title_vis - 3))
  (( line_len < 1 )) && line_len=1

  local border_line=""
  printf -v border_line '%*s' "$line_len" ''
  border_line="${border_line// /─}"

  local bottom_line=""
  printf -v bottom_line '%*s' "$((inner))" ''
  bottom_line="${bottom_line// /─}"

  echo -e "${UI_BORDER}╭─ ${UI_ACCENT}${UI_BOLD}${title}${UI_RESET}${UI_BORDER} ${border_line}╮${UI_RESET}"

  while IFS= read -r line; do
    local vis_len
    vis_len=$(_visible_len "$line")
    local pad=$((inner - vis_len))
    (( pad < 0 )) && pad=0
    printf '%b│%b %s%*s%b│%b\n' "$UI_BORDER" "$UI_RESET" "$line" "$pad" '' "$UI_BORDER" "$UI_RESET"
  done <<< "$content"

  echo -e "${UI_BORDER}╰${bottom_line}╯${UI_RESET}"
}

# ─── Seção com título ─────────────────────────────────────
# Uso: ui_section "Título da Seção"
ui_section() {
  local title="$1"
  local title_len=${#title}
  local line_len=$((title_len + 4))
  local sep=""
  printf -v sep '%*s' "$line_len" ''
  sep="${sep// /─}"

  echo ""
  echo -e "${UI_ACCENT}${UI_BOLD}▸ ${title}${UI_RESET}"
  echo -e "${UI_BORDER}${sep}${UI_RESET}"
}

# ─── Badge/tag inline ─────────────────────────────────────
# Uso: ui_badge "NEW" "$UI_GREEN"
ui_badge() {
  local text="$1"
  local color="${2:-$UI_ACCENT}"
  echo -ne "${color}${UI_BOLD} ${text} ${UI_RESET}"
}

# ─── Status inline ────────────────────────────────────────
# Uso: ui_status "✅" "Instalado com sucesso" "$UI_GREEN"
ui_status() {
  local icon="$1"
  local text="$2"
  local color="${3:-$UI_TEXT}"
  echo -e "  ${color}${icon}${UI_RESET} ${text}"
}

# ─── Progress bar ─────────────────────────────────────────
# Uso: ui_progress 5 20 "Instalando ferramentas..."
ui_progress() {
  local current="$1"
  local total="$2"
  local label="${3:-}"

  (( total <= 0 )) && total=1
  local pct=$((current * 100 / total))
  (( pct > 100 )) && pct=100
  local filled=$((pct / 5))
  local empty=$((20 - filled))

  local bar_filled="" bar_empty=""
  printf -v bar_filled '%*s' "$filled" ''
  bar_filled="${bar_filled// /█}"
  printf -v bar_empty '%*s' "$empty" ''
  bar_empty="${bar_empty// /░}"

  printf "\r  ${UI_GREEN}%s${UI_SURFACE1}%s${UI_RESET} ${UI_MUTED}%d%%${UI_RESET} %s" \
    "$bar_filled" "$bar_empty" "$pct" "${label}"
}

# ─── Separador simples ────────────────────────────────────
# Uso: ui_divider
ui_divider() {
  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local width=$((term_w > 70 ? 70 : term_w - 4))
  local line=""
  printf -v line '%*s' "$width" ''
  echo -e "${UI_SURFACE1}${line// /─}${UI_RESET}"
}

# ─── Mensagem de sucesso ──────────────────────────────────
ui_success() {
  echo -e "  ${UI_SUCCESS}✅ $1${UI_RESET}"
}

# ─── Mensagem de erro ─────────────────────────────────────
ui_error() {
  echo -e "  ${UI_ERROR}❌ $1${UI_RESET}"
}

# ─── Mensagem informativa ─────────────────────────────────
ui_info() {
  echo -e "  ${UI_INFO}ℹ️  $1${UI_RESET}"
}

# ─── Key-value pair (para reports) ────────────────────────
# Uso: ui_kv "Ferramenta" "fzf v0.50.0" 20
ui_kv() {
  local key="$1"
  local value="$2"
  local key_width="${3:-20}"
  printf "  ${UI_MUTED}%-${key_width}s${UI_RESET} %s\n" "$key" "$value"
}
