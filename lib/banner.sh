#!/usr/bin/env bash
# Banner de boas-vindas moderno e responsivo

# ══════════════════════════════════════════════════════════════════════════════
# CORES (definição centralizada)
# ══════════════════════════════════════════════════════════════════════════════
declare -g BANNER_CYAN='\033[0;36m'
declare -g BANNER_GREEN='\033[0;32m'
declare -g BANNER_YELLOW='\033[1;33m'
declare -g BANNER_BLUE='\033[0;34m'
declare -g BANNER_MAGENTA='\033[0;35m'
declare -g BANNER_WHITE='\033[1;37m'
declare -g BANNER_BOLD='\033[1m'
declare -g BANNER_DIM='\033[2m'
declare -g BANNER_RESET='\033[0m'

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES UTILITÁRIAS
# ══════════════════════════════════════════════════════════════════════════════
clear_screen() {
  [[ -t 1 ]] && printf '\033[2J\033[H\033[3J'
}

get_term_width() {
  local width

  # Método 1: Variável COLUMNS (set by shell)
  if [[ -n "${COLUMNS:-}" && "${COLUMNS:-}" =~ ^[0-9]+$ ]]; then
    width="$COLUMNS"
  # Método 2: tput (mais confiável)
  elif width=$(tput cols 2>/dev/null) && [[ "$width" =~ ^[0-9]+$ ]]; then
    : # width já definido
  # Método 3: stty (fallback)
  elif width=$(stty size 2>/dev/null | cut -d' ' -f2) && [[ "$width" =~ ^[0-9]+$ ]]; then
    : # width já definido
  # Método 4: Escape sequence (último recurso)
  elif [[ -t 1 ]]; then
    # Salva posição, move para coluna 999, lê posição, restaura
    local pos
    printf '\033[s\033[999C\033[6n\033[u' >/dev/tty 2>/dev/null
    IFS='[;' read -rs -t 1 -d 'R' _ _ width </dev/tty 2>/dev/null || width=""
  fi

  # Fallback final
  [[ -z "$width" || ! "$width" =~ ^[0-9]+$ || "$width" -lt 20 ]] && width=80
  echo "$width"
}

# Centraliza texto baseado na largura do terminal
center_text() {
  local text="$1"
  local width="${2:-$(get_term_width)}"
  local text_len=${#text}
  local padding=$(( (width - text_len) / 2 ))
  [[ $padding -gt 0 ]] && printf "%${padding}s" ""
  printf '%s\n' "$text"
}

# Remove códigos ANSI de uma string (suporta cores 256 e RGB)
_strip_ansi() {
  local text="$1"
  # Remove: CSI sequences, OSC sequences, e outros escapes comuns
  printf '%s' "$text" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][^\\]*\\//g; s/\x1b\([A-Z]//g'
}

# Calcula largura visual de uma string (emojis = 2 colunas)
_display_width() {
  local text="$1"
  local clean
  clean=$(_strip_ansi "$text")

  # Usa wc -L se disponível (conta largura visual real)
  if command -v wc &>/dev/null; then
    local visual_width
    visual_width=$(printf '%s' "$clean" | wc -L 2>/dev/null)
    if [[ "$visual_width" =~ ^[0-9]+$ && "$visual_width" -gt 0 ]]; then
      echo "$visual_width"
      return
    fi
  fi

  # Fallback: conta caracteres normalmente
  echo "${#clean}"
}

# Centraliza texto com cores (remove códigos ANSI para calcular)
center_colored() {
  local text="$1"
  local width="${2:-$(get_term_width)}"
  local text_len
  text_len=$(_display_width "$text")
  local padding=$(( (width - text_len) / 2 ))
  [[ $padding -gt 0 ]] && printf "%${padding}s" ""
  printf '%b\n' "$text"
}

# ══════════════════════════════════════════════════════════════════════════════
# BANNER PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════
show_banner() {
  local term_width
  term_width=$(get_term_width)

  clear_screen
  show_ascii_banner_responsive "$term_width"
  show_welcome_message "$term_width"
}

show_ascii_banner_responsive() {
  local width="${1:-$(get_term_width)}"

  echo ""
  if [[ $width -ge 100 ]]; then
    show_banner_large "$width"
  elif [[ $width -ge 65 ]]; then
    show_banner_medium "$width"
  else
    show_banner_small "$width"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# BANNER GRANDE (≥100 cols) - LUCASSR-DEV completo
# ══════════════════════════════════════════════════════════════════════════════
show_banner_large() {
  local width="$1"

  echo -e "${BANNER_CYAN}${BANNER_BOLD}"
  center_text "██╗     ██╗   ██╗ ██████╗ █████╗ ███████╗███████╗██████╗       ██████╗ ███████╗██╗   ██╗" "$width"
  center_text "██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗      ██╔══██╗██╔════╝██║   ██║" "$width"
  center_text "██║     ██║   ██║██║     ███████║███████╗███████╗██████╔╝█████╗██║  ██║█████╗  ██║   ██║" "$width"
  center_text "██║     ██║   ██║██║     ██╔══██║╚════██║╚════██║██╔══██╗╚════╝██║  ██║██╔══╝  ╚██╗ ██╔╝" "$width"
  center_text "███████╗╚██████╔╝╚██████╗██║  ██║███████║███████║██║  ██║      ██████╔╝███████╗ ╚████╔╝ " "$width"
  center_text "╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝      ╚═════╝ ╚══════╝  ╚═══╝  " "$width"
  echo -e "${BANNER_RESET}"
  echo ""
  center_colored "${BANNER_BLUE}🌐${BANNER_RESET} ${BANNER_BOLD}https://lucassr.dev${BANNER_RESET}  ${BANNER_DIM}│${BANNER_RESET}  ${BANNER_GREEN}📦${BANNER_RESET} ${BANNER_BOLD}https://github.com/lucassr-dev/.config${BANNER_RESET}" "$width"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# BANNER MÉDIO (65-99 cols) - LUCASSR-DEV completo (compacto)
# ══════════════════════════════════════════════════════════════════════════════
show_banner_medium() {
  local width="$1"

  echo -e "${BANNER_CYAN}${BANNER_BOLD}"
  center_text "██╗     ██╗   ██╗ ██████╗ █████╗ ███████╗███████╗██████╗ " "$width"
  center_text "██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗" "$width"
  center_text "██║     ██║   ██║██║     ███████║███████╗███████╗██████╔╝" "$width"
  center_text "██║     ██║   ██║██║     ██╔══██║╚════██║╚════██║██╔══██╗" "$width"
  center_text "███████╗╚██████╔╝╚██████╗██║  ██║███████║███████║██║  ██║" "$width"
  center_text "╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝" "$width"
  echo -e "${BANNER_RESET}"
  echo ""
  center_colored "${BANNER_BLUE}🌐${BANNER_RESET} https://lucassr.dev  ${BANNER_GREEN}📦${BANNER_RESET} https://github.com/lucassr-dev/.config" "$width"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# BANNER PEQUENO (<65 cols) - Texto simples estilizado
# ══════════════════════════════════════════════════════════════════════════════
show_banner_small() {
  local width="$1"

  echo ""
  center_colored "${BANNER_CYAN}${BANNER_BOLD}╭───────────────╮${BANNER_RESET}" "$width"
  center_colored "${BANNER_CYAN}│${BANNER_RESET} ${BANNER_WHITE}${BANNER_BOLD}LUCASSR-DEV${BANNER_RESET} ${BANNER_CYAN}│${BANNER_RESET}" "$width"
  center_colored "${BANNER_CYAN}╰───────────────╯${BANNER_RESET}" "$width"
  echo ""
  center_colored "${BANNER_BLUE}🌐${BANNER_RESET} https://lucassr.dev" "$width"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MENSAGEM DE BOAS-VINDAS
# ══════════════════════════════════════════════════════════════════════════════
show_welcome_message() {
  local width="$1"

  echo ""
  if [[ $width -ge 70 ]]; then
    center_colored "${BANNER_BOLD}Bem-vindo ao Instalador de Dotfiles${BANNER_RESET}" "$width"
    echo ""
    center_colored "${BANNER_YELLOW}O que este instalador faz:${BANNER_RESET}" "$width"
    center_colored "${BANNER_GREEN}✓${BANNER_RESET} Shells + temas │ CLI tools + runtimes │ Git multi-conta" "$width"
    center_colored "${BANNER_GREEN}✓${BANNER_RESET} Apps GUI por categoria │ backups automáticos" "$width"
    echo ""
    center_colored "${BANNER_CYAN}→${BANNER_RESET} Selecione o que instalar e confirme ao final" "$width"
  else
    center_colored "${BANNER_BOLD}Instalador de Dotfiles${BANNER_RESET}" "$width"
    echo ""
    center_colored "${BANNER_GREEN}✓${BANNER_RESET} Shells, CLI tools, runtimes" "$width"
    center_colored "${BANNER_GREEN}✓${BANNER_RESET} Apps GUI, backups" "$width"
  fi
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES DE NAVEGAÇÃO
# ══════════════════════════════════════════════════════════════════════════════
show_section_header() {
  local title="$1"
  local width
  width=$(get_term_width)
  local line_len=$((width > 70 ? 70 : width - 4))
  local line
  line=$(printf '═%.0s' $(seq 1 "$line_len"))

  echo ""
  echo -e "${BANNER_CYAN}╔${line}╗${BANNER_RESET}"
  echo -e "${BANNER_CYAN}║${BANNER_RESET}  ${BANNER_BOLD}${title}${BANNER_RESET}"
  echo -e "${BANNER_CYAN}╚${line}╝${BANNER_RESET}"
  echo ""
}

pause_before_next_section() {
  local message="${1:-Pressione Enter para continuar...}"
  echo ""
  read -r -p "💡 $message "
}
