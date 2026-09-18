#!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════════════════════
# CORES
# ══════════════════════════════════════════════════════════════════════════════

declare -g BANNER_CYAN="${UI_CYAN:-$'\033[0;36m'}"
declare -g BANNER_GREEN="${UI_GREEN:-$'\033[0;32m'}"
declare -g BANNER_YELLOW="${UI_YELLOW:-$'\033[1;33m'}"
declare -g BANNER_BLUE="${UI_BLUE:-$'\033[0;34m'}"
declare -g BANNER_WHITE="${UI_WHITE:-$'\033[1;37m'}"
declare -g BANNER_BOLD="${UI_BOLD:-$'\033[1m'}"
declare -g BANNER_DIM="${UI_DIM:-$'\033[2m'}"
declare -g BANNER_RESET="${UI_RESET:-$'\033[0m'}"

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES UTILITÁRIAS
# ══════════════════════════════════════════════════════════════════════════════
# clear_screen mora em lib/core.sh: e chamada por 9 modulos, nao so por este.

get_term_width() {
  ui_term_cols
}

center_text() {
  local text="$1"
  local width="${2:-$(get_term_width)}"
  local text_len=${#text}
  local padding=$(( (width - text_len) / 2 ))
  [[ $padding -gt 0 ]] && printf "%${padding}s" ""
  echo "$text"
}

center_colored() {
  local text="$1"
  local width="${2:-$(get_term_width)}"
  local clean_text
  clean_text=$(echo -e "$text" | sed -E 's/\x1b\[[0-9;]*m//g')
  local text_len=${#clean_text}
  local padding=$(( (width - text_len) / 2 ))
  [[ $padding -gt 0 ]] && printf "%${padding}s" ""
  echo -e "$text"
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
  # A arte em blocos tem 88 COLUNAS de exibicao — medido com `wc -L`, nao com
  # o comprimento da string: cada "█" ocupa 3 bytes e 1 coluna, entao contar
  # caracteres da um numero quase tres vezes maior e faz a arte parecer caber.
  #
  # A variante "media" e a grande com dois espacos a menos no fim: tem as mesmas
  # 88 colunas. Ate Set/2026 ela era escolhida a partir de 65 colunas, e entre 65
  # e 87 a arte vazava para a linha seguinte, quebrando o desenho.
  if [[ $width -ge 100 ]]; then
    show_banner_large "$width"
  elif [[ $width -ge 88 ]]; then
    show_banner_medium "$width"
  else
    show_banner_small "$width"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# BANNER GRANDE (≥100 cols) - LUCASSR-DEV
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
# BANNER MEDIO (88-99 cols) - LUCASSR-DEV
# ══════════════════════════════════════════════════════════════════════════════
show_banner_medium() {
  local width="$1"

  echo -e "${BANNER_CYAN}${BANNER_BOLD}"
  center_text "██╗     ██╗   ██╗ ██████╗ █████╗ ███████╗███████╗██████╗       ██████╗ ███████╗██╗   ██╗" "$width"
  center_text "██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗      ██╔══██╗██╔════╝██║   ██║" "$width"
  center_text "██║     ██║   ██║██║     ███████║███████╗███████╗██████╔╝█████╗██║  ██║█████╗  ██║   ██║" "$width"
  center_text "██║     ██║   ██║██║     ██╔══██║╚════██║╚════██║██╔══██╗╚════╝██║  ██║██╔══╝  ╚██╗ ██╔╝" "$width"
  center_text "███████╗╚██████╔╝╚██████╗██║  ██║███████║███████║██║  ██║      ██████╔╝███████╗ ╚████╔╝" "$width"
  center_text "╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝      ╚═════╝ ╚══════╝  ╚═══╝" "$width"
  echo -e "${BANNER_RESET}"
  echo ""
  center_colored "${BANNER_BLUE}🌐${BANNER_RESET} https://lucassr.dev  ${BANNER_GREEN}📦${BANNER_RESET} https://github.com/lucassr-dev/.config" "$width"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# BANNER PEQUENO (<88 cols) - cabe em qualquer terminal, tem 17 colunas
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
  # Cabecalho de secao unificado: titulo em negrito+mauve seguido de uma
  # regra que preenche ate a largura -- mesma gramatica visual dos
  # divisores de review_selections (_rv_div) e do relatorio (_rpt_div),
  # so que em destaque de pagina em vez de subsecao. Substituiu a caixa
  # dupla (╔═╗) anterior: menos ruido vertical, mesma hierarquia em toda
  # tela que chama esta funcao.
  local title="$1"
  local width
  width=$(get_term_width)
  local box_w=$((width > 76 ? 76 : width - 4))
  [[ $box_w -lt 36 ]] && box_w=36

  local title_text="$title"
  local title_visual_w
  title_visual_w=$(_visible_len "$title_text")
  local max_title_w=$((box_w - 6))
  if [[ $title_visual_w -gt $max_title_w ]]; then
    # ANSI-safe truncation: strip codes, truncate visible text (title e plano)
    local clean_title
    clean_title=$(printf '%s' "$title_text" | _strip_ansi)
    title_text="${clean_title:0:$((max_title_w - 1))}…"
    title_visual_w=$(_visible_len "$title_text")
  fi

  local fill=$((box_w - title_visual_w - 4))
  [[ $fill -lt 1 ]] && fill=1
  local fill_str
  fill_str=$(printf '─%.0s' $(seq 1 "$fill"))

  echo ""
  echo -e "  ${UI_OVERLAY1}── ${UI_MAUVE}${UI_BOLD}${title_text}${UI_RESET} ${UI_OVERLAY1}${fill_str}${UI_RESET}"
  echo ""
}

pause_before_next_section() {
  local message="${1:-Pressione Enter para continuar...}"
  local center="${2:-false}"
  echo ""
  if [[ "$center" == "true" ]]; then
    local width
    width=$(get_term_width)
    local text_len=$((${#message} + 4))
    local padding=$(( (width - text_len) / 2 ))
    [[ $padding -gt 0 ]] && printf "%${padding}s" ""
  fi
  read -r -p "💡 $message "
}
