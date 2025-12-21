#!/usr/bin/env bash
# Banner de boas-vindas para o dotfiles installer

clear_screen() {
  if [[ -t 1 ]]; then
    printf '\033[2J\033[H\033[3J'
  fi
}

show_banner() {
  local term_width
  term_width=$(tput cols 2>/dev/null || echo 80)

  clear_screen

  # Usar banner ASCII responsivo
  show_ascii_banner_responsive

  # Mensagem de boas-vindas responsiva
  show_welcome_message "$term_width"
}

show_welcome_message() {
  local term_width="$1"
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local MAGENTA='\033[0;35m'
  local RESET='\033[0m'
  local BOLD='\033[1m'

  if [[ $term_width -ge 80 ]]; then
    echo -e "${BOLD}Bem-vindo ao Instalador de Dotfiles${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}O que este instalador faz:${RESET}"
    echo -e "  ${GREEN}✓${RESET} Shells + temas | CLI tools + runtimes | Git multi-conta"
    echo -e "  ${GREEN}✓${RESET} Apps GUI por categoria | backups automáticos"
    echo ""
    echo -e "${MAGENTA}${BOLD}Características:${RESET}"
    echo -e "  ${BLUE}•${RESET} Cross-platform, interativo e seguro"
    echo ""
    echo -e "${YELLOW}${BOLD}Próximos passos:${RESET}"
    echo -e "  ${CYAN}→${RESET} Selecione o que instalar e confirme ao final"
  else
    echo -e "${BOLD}Instalador de Dotfiles${RESET}"
    echo ""
    echo -e "${GREEN}✓${RESET} Shells, temas, CLI tools e runtimes"
    echo -e "${GREEN}✓${RESET} Apps GUI e backups automáticos"
    echo -e "${CYAN}→${RESET} Selecione o que instalar"
  fi
  echo ""
}

show_ascii_banner_responsive() {
  local term_width
  term_width=$(tput cols 2>/dev/null || echo 80)

  if [[ $term_width -ge 62 ]]; then
    show_ascii_banner_full
  elif [[ $term_width -ge 50 ]]; then
    show_ascii_banner_compact
  else
    show_ascii_banner_minimal
  fi
}

show_ascii_banner_full() {
  local CYAN='\033[0;36m'
  local MAGENTA='\033[0;35m'
  local GREEN='\033[0;32m'
  local BLUE='\033[0;34m'
  local BOLD='\033[1m'
  local RESET='\033[0m'

  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ╔════════════════════════════════════════════════════════╗"
  echo "  ║                                                        ║"
  echo "  ║                    My Dotfiles                         ║"
  echo "  ║                    lucassr-dev                         ║"
  echo "  ║                                                        ║"
  echo "  ╚════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo ""
  echo -e "  ${BLUE}🌐${RESET} ${BOLD}Site:${RESET} https://lucassr.dev"
  echo -e "  ${GREEN}📦${RESET} ${BOLD}Repositório:${RESET} https://github.com/lucassrdev/configs"
  echo ""
}

show_ascii_banner_compact() {
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local BLUE='\033[0;34m'
  local BOLD='\033[1m'
  local RESET='\033[0m'

  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║                                          ║"
  echo "  ║            My Dotfiles                   ║"
  echo "  ║            lucassr-dev                   ║"
  echo "  ║                                          ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo ""
  echo -e "  ${BLUE}🌐${RESET} https://lucassr.dev"
  echo -e "  ${GREEN}📦${RESET} https://github.com/lucassrdev/configs"
  echo ""
}

show_ascii_banner_minimal() {
  local CYAN='\033[0;36m'
  local BLUE='\033[0;34m'
  local BOLD='\033[1m'
  local RESET='\033[0m'

  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ╔═══════════════════════════════╗"
  echo "  ║                               ║"
  echo "  ║      My Dotfiles              ║"
  echo "  ║      lucassr-dev              ║"
  echo "  ║                               ║"
  echo -e "  ╚═══════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${BLUE}🌐${RESET} https://lucassr.dev"
  echo ""
}

show_ascii_banner() {
  show_ascii_banner_responsive
}

# Função para limpar tela e mostrar nova seção (navegação limpa)
clear_and_show_section() {
  local title="$1"
  local skip_clear="${2:-false}"

  # Limpar tela (exceto se for a primeira vez ou se skip_clear=true)
  if [[ "$skip_clear" != "true" ]]; then
    clear_screen
  fi

  show_section_header "$title"
}

show_section_header() {
  local title="$1"
  local CYAN='\033[0;36m'
  local RESET='\033[0m'
  local BOLD='\033[1m'

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${RESET}  ${BOLD}${title}${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# Função para pausar e aguardar usuário antes de próxima seção
pause_before_next_section() {
  local message="${1:-Pressione Enter para continuar...}"
  echo ""
  read -r -p "💡 $message "
}
