#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════
# Design Tokens — Catppuccin Mocha (paleta completa, 26 cores)
# ═══════════════════════════════════════════════════════════
#
# Fonte: https://catppuccin.com/palette
# Cada cor usa true color (24-bit). Fallback automático para 8 cores.

UI_RESET="\033[0m"
UI_BOLD="\033[1m"
UI_DIM="\033[2m"
UI_ITALIC="\033[3m"
UI_UNDERLINE="\033[4m"

# ─── Accent Colors ────────────────────────────────────────
UI_ROSEWATER="\033[38;2;245;224;220m"   # #F5E0DC
UI_FLAMINGO="\033[38;2;242;205;205m"    # #F2CDCD
UI_PINK="\033[38;2;245;194;231m"        # #F5C2E7
UI_MAUVE="\033[38;2;203;166;247m"       # #CBA6F7
UI_RED="\033[38;2;243;139;168m"         # #F38BA8
UI_MAROON="\033[38;2;235;160;172m"      # #EBA0AC
UI_PEACH="\033[38;2;250;179;135m"       # #FAB387
UI_YELLOW="\033[38;2;249;226;175m"      # #F9E2AF
UI_GREEN="\033[38;2;166;227;161m"       # #A6E3A1
UI_TEAL="\033[38;2;148;226;213m"        # #94E2D5
UI_SKY="\033[38;2;137;220;235m"         # #89DCEB
UI_SAPPHIRE="\033[38;2;116;199;236m"    # #74C7EC
UI_BLUE="\033[38;2;137;180;250m"        # #89B4FA
UI_LAVENDER="\033[38;2;180;190;254m"    # #B4BEFE

# ─── Text Hierarchy ───────────────────────────────────────
UI_TEXT="\033[38;2;205;214;244m"        # #CDD6F4 — Primary
UI_SUBTEXT1="\033[38;2;186;194;222m"    # #BAC2DE — Secondary
UI_SUBTEXT0="\033[38;2;166;173;200m"    # #A6ADC8 — Tertiary/muted

# ─── Surface / Overlay ────────────────────────────────────
UI_OVERLAY2="\033[38;2;147;153;178m"    # #9399B2 — Disabled
UI_OVERLAY1="\033[38;2;127;132;156m"    # #7F849C — Border light
UI_OVERLAY0="\033[38;2;108;112;134m"    # #6C7086 — Border dark
UI_SURFACE2="\033[38;2;88;91;112m"      # #585B70 — Card bg light
UI_SURFACE1="\033[38;2;69;71;90m"       # #45475A — Card bg
UI_SURFACE0="\033[38;2;49;50;68m"       # #313244 — Section bg
UI_BASE="\033[38;2;30;30;46m"           # #1E1E2E — Main bg
UI_MANTLE="\033[38;2;24;24;37m"         # #181825 — Deep bg
UI_CRUST="\033[38;2;17;17;27m"          # #11111B — Deepest bg

# ─── Semantic Aliases ─────────────────────────────────────
UI_SUCCESS="$UI_GREEN"
UI_ERROR="$UI_RED"
UI_WARNING="$UI_YELLOW"
UI_INFO="$UI_SKY"
UI_ACCENT="$UI_MAUVE"
UI_HIGHLIGHT="$UI_PEACH"
UI_LINK="$UI_SAPPHIRE"
UI_MUTED="$UI_SUBTEXT0"
UI_DISABLED="$UI_OVERLAY2"
UI_BORDER="$UI_OVERLAY0"

# ─── Legacy Aliases (compatibilidade com código existente) ─
UI_CYAN="$UI_SKY"
UI_WHITE="$UI_TEXT"

# ─── Fallback automático ──────────────────────────────────
_setup_color_mode() {
  # Sem cores se não for terminal ou NO_COLOR está definido
  if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
    UI_RESET="" UI_BOLD="" UI_DIM="" UI_ITALIC="" UI_UNDERLINE=""
    UI_ROSEWATER="" UI_FLAMINGO="" UI_PINK="" UI_MAUVE=""
    UI_RED="" UI_MAROON="" UI_PEACH="" UI_YELLOW=""
    UI_GREEN="" UI_TEAL="" UI_SKY="" UI_SAPPHIRE=""
    UI_BLUE="" UI_LAVENDER=""
    UI_TEXT="" UI_SUBTEXT1="" UI_SUBTEXT0=""
    UI_OVERLAY2="" UI_OVERLAY1="" UI_OVERLAY0=""
    UI_SURFACE2="" UI_SURFACE1="" UI_SURFACE0=""
    UI_BASE="" UI_MANTLE="" UI_CRUST=""
    UI_SUCCESS="" UI_ERROR="" UI_WARNING="" UI_INFO=""
    UI_ACCENT="" UI_HIGHLIGHT="" UI_LINK="" UI_MUTED=""
    UI_DISABLED="" UI_BORDER="" UI_CYAN="" UI_WHITE=""
    return
  fi

  local colors
  colors=$(tput colors 2>/dev/null || echo 8)

  # 8 cores — degradar graciosamente
  if [[ $colors -lt 256 ]]; then
    UI_RED="\033[31m"
    UI_GREEN="\033[32m"
    UI_YELLOW="\033[33m"
    UI_BLUE="\033[34m"
    UI_MAUVE="\033[35m"
    UI_SKY="\033[36m"
    UI_TEXT="\033[37m"
    UI_MUTED="\033[90m"
    UI_BORDER="\033[90m"

    # Reatribuir aliases para cores disponíveis
    UI_ROSEWATER="$UI_RED" UI_FLAMINGO="$UI_RED" UI_PINK="$UI_MAUVE"
    UI_MAROON="$UI_RED" UI_PEACH="$UI_YELLOW" UI_TEAL="$UI_SKY"
    UI_SAPPHIRE="$UI_BLUE" UI_LAVENDER="$UI_BLUE"
    UI_SUBTEXT1="$UI_TEXT" UI_SUBTEXT0="$UI_MUTED"
    UI_OVERLAY2="$UI_MUTED" UI_OVERLAY1="$UI_MUTED" UI_OVERLAY0="$UI_MUTED"
    UI_SURFACE2="$UI_MUTED" UI_SURFACE1="" UI_SURFACE0=""
    UI_BASE="" UI_MANTLE="" UI_CRUST=""

    UI_SUCCESS="$UI_GREEN" UI_ERROR="$UI_RED" UI_WARNING="$UI_YELLOW"
    UI_INFO="$UI_SKY" UI_ACCENT="$UI_MAUVE" UI_HIGHLIGHT="$UI_YELLOW"
    UI_LINK="$UI_BLUE" UI_DISABLED="$UI_MUTED"
    UI_CYAN="$UI_SKY" UI_WHITE="$UI_TEXT"
  fi
}

# Auto-detectar ao carregar
_setup_color_mode
