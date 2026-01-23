#!/usr/bin/env bash
# shellcheck disable=SC2034

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES AUXILIARES
# ══════════════════════════════════════════════════════════════════════════════

get_version() {
  local cmd="$1"
  case "$cmd" in
    git) git --version 2>&1 | awk '{print $3}' ;;
    zsh) zsh --version 2>&1 | awk '{print $2}' ;;
    fish) fish --version 2>&1 | awk '{print $3}' ;;
    tmux) tmux -V 2>&1 | awk '{print $2}' ;;
    nvim) nvim --version 2>&1 | head -n 1 | awk '{print $2}' ;;
    starship) starship --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
    mise) mise --version 2>/dev/null | head -n 1 | awk '{print $1}' ;;
    code) code --version 2>&1 | head -n 1 ;;
    docker) docker --version 2>&1 | sed -n 's/.*Docker version \([0-9.]*\).*/\1/p' ;;
    lazygit) lazygit --version 2>/dev/null | grep -o "version='[^']*'" | sed "s/version='//;s/'//" | cut -d'+' -f1 ;;
    node) node --version 2>/dev/null | tr -d 'v' ;;
    python) python3 --version 2>/dev/null | awk '{print $2}' ;;
    php) php --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
    rust) rustc --version 2>/dev/null | awk '{print $2}' ;;
    go) go version 2>/dev/null | awk '{print $3}' | sed 's/go//' ;;
    bun) bun --version 2>/dev/null ;;
    deno) deno --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
  esac
}

# Calcula a largura visual de uma string (emojis = 2, ASCII = 1)
_display_width() {
  local str="$1"
  local width=0
  local char
  while IFS= read -r -n1 char; do
    if [[ -z "$char" ]]; then
      continue
    fi
    # Detecta caracteres multibyte (emojis, unicode)
    local byte_len=${#char}
    if [[ $byte_len -gt 1 ]]; then
      # Emoji ou caractere unicode largo = 2 espaços visuais
      ((width += 2))
    else
      ((width += 1))
    fi
  done <<< "$str"
  echo "$width"
}

# Gera linha horizontal com caracteres de borda
_hline() {
  local width="$1"
  printf '%*s' "$width" '' | tr ' ' '─'
}

# Trunca texto para caber em largura máxima (considerando largura visual)
_truncate_text() {
  local max="$1"
  local text="$2"
  local display_w
  display_w=$(_display_width "$text")
  if [[ $display_w -le $max ]]; then
    printf '%s' "$text"
    return
  fi
  # Trunca caractere por caractere até caber
  local result=""
  local current_w=0
  local char
  while IFS= read -r -n1 char && [[ $current_w -lt $((max - 3)) ]]; do
    [[ -z "$char" ]] && continue
    local byte_len=${#char}
    if [[ $byte_len -gt 1 ]]; then
      ((current_w += 2))
    else
      ((current_w += 1))
    fi
    if [[ $current_w -le $((max - 3)) ]]; then
      result+="$char"
    fi
  done <<< "$text"
  printf '%s...' "$result"
}

# Formata ferramenta: "icon name version" truncado para largura máxima
_fmt_tool() {
  local icon="$1"
  local name="$2"
  local version="$3"
  local max_w="${4:-18}"
  local text="$icon $name"
  [[ -n "$version" ]] && text+=" $version"
  _truncate_text "$max_w" "$text"
}

# Helper: adiciona ferramenta à lista somente se versão foi obtida
_add_tool_if_version() {
  local -n arr="$1"
  local icon="$2"
  local name="$3"
  local cmd="$4"
  local width="$5"
  local version
  version=$(get_version "$cmd")
  if [[ -n "$version" ]]; then
    arr+=("$(_fmt_tool "$icon" "$name" "$version" "$width")")
  fi
}

# Imprime célula com padding correto baseado em largura visual
_print_cell() {
  local content="$1"
  local target_width="$2"
  local display_w
  display_w=$(_display_width "$content")
  local padding=$((target_width - display_w))
  [[ $padding -lt 0 ]] && padding=0
  printf '%s%*s' "$content" "$padding" ''
}

# ══════════════════════════════════════════════════════════════════════════════
# RELATÓRIO PÓS-INSTALAÇÃO
# ══════════════════════════════════════════════════════════════════════════════

print_post_install_report() {
  local username="${USER:-$(whoami)}"
  local hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo 'localhost')}"

  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local WHITE='\033[1;37m'
  local DIM='\033[2m'
  local NC='\033[0m'

  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local w=$((term_w > 80 ? 80 : term_w - 2))
  [[ $w -lt 50 ]] && w=50

  [[ -t 1 ]] && clear

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # HEADER - Sucesso
  # ═══════════════════════════════════════════════════════════════════════════
  local header_line
  header_line=$(_hline $((w - 2)))
  echo -e "${GREEN}╭${header_line}╮${NC}"
  local title="INSTALACAO CONCLUIDA!"
  local title_pad=$(( (w - 2 - ${#title}) / 2 ))
  printf "${GREEN}│${NC}%*s${YELLOW}%s${NC}%*s${GREEN}│${NC}\n" "$title_pad" "" "$title" "$((w - 2 - title_pad - ${#title}))" ""
  echo -e "${GREEN}╰${header_line}╯${NC}"
  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # INFO DO AMBIENTE
  # ═══════════════════════════════════════════════════════════════════════════
  local inner_w=$((w - 4))
  echo -e "${DIM}╭${header_line}╮${NC}"
  printf "${DIM}│${NC} %-*s ${DIM}│${NC}\n" "$inner_w" "Usuario: ${username}"
  printf "${DIM}│${NC} %-*s ${DIM}│${NC}\n" "$inner_w" "Host: ${hostname}"
  printf "${DIM}│${NC} %-*s ${DIM}│${NC}\n" "$inner_w" "SO: ${TARGET_OS:-linux}"
  if [[ -d "$BACKUP_DIR" ]]; then
    printf "${DIM}│${NC} %-*s ${DIM}│${NC}\n" "$inner_w" "Backup: ${BACKUP_DIR}"
  fi
  echo -e "${DIM}╰${header_line}╯${NC}"
  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # COLUNAS: FERRAMENTAS | RUNTIMES
  # ═══════════════════════════════════════════════════════════════════════════
  local gap=1
  local col_total=$((w - 6))
  local col_w=$((col_total / 2))
  local left_line right_line
  left_line=$(_hline $((col_w + 1)))
  right_line=$(_hline $((col_w + 1)))

  # Coletar dados
  local tools=()
  _add_tool_if_version tools ">" "Git" git "$col_w"
  _add_tool_if_version tools ">" "Zsh" zsh "$col_w"
  _add_tool_if_version tools ">" "Fish" fish "$col_w"
  _add_tool_if_version tools ">" "Tmux" tmux "$col_w"
  _add_tool_if_version tools ">" "Neovim" nvim "$col_w"
  _add_tool_if_version tools ">" "Starship" starship "$col_w"
  _add_tool_if_version tools ">" "VS Code" code "$col_w"
  _add_tool_if_version tools ">" "Docker" docker "$col_w"
  _add_tool_if_version tools ">" "Mise" mise "$col_w"
  _add_tool_if_version tools ">" "Lazygit" lazygit "$col_w"
  [[ ${#tools[@]} -eq 0 ]] && tools+=("(nenhuma)")

  local runtimes=()
  _add_tool_if_version runtimes ">" "Node" node "$col_w"
  _add_tool_if_version runtimes ">" "Python" python "$col_w"
  _add_tool_if_version runtimes ">" "PHP" php "$col_w"
  _add_tool_if_version runtimes ">" "Rust" rust "$col_w"
  _add_tool_if_version runtimes ">" "Go" go "$col_w"
  _add_tool_if_version runtimes ">" "Bun" bun "$col_w"
  _add_tool_if_version runtimes ">" "Deno" deno "$col_w"
  [[ ${#runtimes[@]} -eq 0 ]] && runtimes+=("(nenhum)")

  # Desenhar tabela
  echo -e "${CYAN}╭${left_line}┬${right_line}╮${NC}"
  printf "${CYAN}│${NC} ${WHITE}%-*s${NC}${CYAN}│${NC} ${WHITE}%-*s${NC}${CYAN}│${NC}\n" "$col_w" "FERRAMENTAS" "$col_w" "RUNTIMES"
  echo -e "${CYAN}├${left_line}┼${right_line}┤${NC}"

  local max=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max ]] && max=${#runtimes[@]}
  for (( i=0; i<max; i++ )); do
    local left="${tools[i]:-}"
    local right="${runtimes[i]:-}"
    printf "${CYAN}│${NC} %-*s${CYAN}│${NC} %-*s${CYAN}│${NC}\n" "$col_w" "$left" "$col_w" "$right"
  done

  echo -e "${CYAN}╰${left_line}┴${right_line}╯${NC}"

  # ═══════════════════════════════════════════════════════════════════════════
  # COLUNAS: PROXIMO PASSO | COMANDOS UTEIS
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""

  local next_steps=()
  next_steps+=("Reinicie: exec \$SHELL")
  if [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]]; then
    next_steps+=("Tema: p10k configure")
  fi
  if [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]]; then
    next_steps+=("Fonte: ${SELECTED_NERD_FONTS[0]}")
  fi

  local commands=()
  commands+=("install.sh export - salvar")
  commands+=("install.sh sync - atualizar")
  has_cmd lazygit && commands+=("lazygit - TUI Git")
  has_cmd zoxide && commands+=("z <pasta> - navegar")

  echo -e "${GREEN}╭${left_line}┬${right_line}╮${NC}"
  printf "${GREEN}│${NC} ${WHITE}%-*s${NC}${GREEN}│${NC} ${WHITE}%-*s${NC}${GREEN}│${NC}\n" "$col_w" "PROXIMO PASSO" "$col_w" "COMANDOS UTEIS"
  echo -e "${GREEN}├${left_line}┼${right_line}┤${NC}"

  local steps_max=${#next_steps[@]}
  [[ ${#commands[@]} -gt $steps_max ]] && steps_max=${#commands[@]}
  for (( i=0; i<steps_max; i++ )); do
    local left="${next_steps[i]:-}"
    local right="${commands[i]:-}"
    printf "${GREEN}│${NC} %-*s${GREEN}│${NC} ${DIM}%-*s${NC}${GREEN}│${NC}\n" "$col_w" "$left" "$col_w" "$right"
  done

  echo -e "${GREEN}╰${left_line}┴${right_line}╯${NC}"

  # ═══════════════════════════════════════════════════════════════════════════
  # MISE (se instalado)
  # ═══════════════════════════════════════════════════════════════════════════
  if has_cmd mise; then
    echo ""
    echo -e "${DIM}╭─ Mise (gerenciador de runtimes) $(_hline $((w - 36)))╮${NC}"
    printf "${DIM}│${NC}  %-22s ${DIM}->  %-*s${NC}${DIM}│${NC}\n" "mise ls" "$((inner_w - 28))" "Listar instalados"
    printf "${DIM}│${NC}  %-22s ${DIM}->  %-*s${NC}${DIM}│${NC}\n" "mise use -g node@lts" "$((inner_w - 28))" "Node LTS global"
    printf "${DIM}│${NC}  %-22s ${DIM}->  %-*s${NC}${DIM}│${NC}\n" "mise use python@latest" "$((inner_w - 28))" "Python no projeto"
    printf "${DIM}│${NC}  %-22s ${DIM}->  %-*s${NC}${DIM}│${NC}\n" "mise install" "$((inner_w - 28))" "Instalar do .mise.toml"
    echo -e "${DIM}╰${header_line}╯${NC}"
  fi

  # ═══════════════════════════════════════════════════════════════════════════
  # FOOTER
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""
  echo -e "  ${DIM}lucassr.dev | github.com/lucassr-dev/.config${NC}"
  echo ""
}
