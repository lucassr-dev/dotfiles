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

# Gera linha horizontal
_hline() {
  local width="$1"
  local char="${2:--}"
  printf '%*s' "$width" '' | tr ' ' "$char"
}

# Trunca texto para caber em largura máxima
_truncate() {
  local max="$1"
  local text="$2"
  if [[ ${#text} -le $max ]]; then
    printf '%s' "$text"
  elif [[ $max -le 3 ]]; then
    printf '%s' "${text:0:$max}"
  else
    printf '%s' "${text:0:$((max-3))}..."
  fi
}

# Formata ferramenta com versão
_fmt_tool() {
  local name="$1"
  local version="$2"
  local max_w="${3:-30}"
  local text="$name"
  [[ -n "$version" ]] && text+=" $version"
  _truncate "$max_w" "$text"
}

# Helper: adiciona ferramenta à lista somente se versão foi obtida
_add_tool_if_version() {
  local -n arr="$1"
  local name="$2"
  local cmd="$3"
  local width="$4"
  local version
  version=$(get_version "$cmd")
  if [[ -n "$version" ]]; then
    arr+=("$(_fmt_tool "$name" "$version" "$width")")
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# RELATÓRIO PÓS-INSTALAÇÃO
# ══════════════════════════════════════════════════════════════════════════════

print_post_install_report() {
  local username="${USER:-$(whoami)}"
  local hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo 'localhost')}"

  # Cores
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local MAGENTA='\033[0;35m'
  local WHITE='\033[1;37m'
  local BOLD='\033[1m'
  local DIM='\033[2m'
  local NC='\033[0m'

  # Largura do terminal
  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local w=$((term_w > 78 ? 78 : term_w - 2))
  [[ $w -lt 50 ]] && w=50

  [[ -t 1 ]] && clear

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # HEADER
  # ═══════════════════════════════════════════════════════════════════════════
  local hline
  hline=$(_hline $((w - 2)) "=")
  echo -e "${GREEN}+${hline}+${NC}"
  local title="INSTALACAO CONCLUIDA!"
  local title_pad=$(( (w - 2 - ${#title}) / 2 ))
  printf "${GREEN}|${NC}%*s${YELLOW}${BOLD}%s${NC}%*s${GREEN}|${NC}\n" "$title_pad" "" "$title" "$((w - 2 - title_pad - ${#title}))" ""
  echo -e "${GREEN}+${hline}+${NC}"
  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # INFO DO AMBIENTE
  # ═══════════════════════════════════════════════════════════════════════════
  local inner_w=$((w - 4))
  local line
  line=$(_hline $((w - 2)) "-")

  echo -e "${DIM}+${line}+${NC}"
  printf "${DIM}|${NC} ${CYAN}Usuario:${NC} %-*s ${DIM}|${NC}\n" "$((inner_w - 9))" "$username"
  printf "${DIM}|${NC} ${CYAN}Host:${NC}    %-*s ${DIM}|${NC}\n" "$((inner_w - 9))" "$hostname"
  printf "${DIM}|${NC} ${CYAN}SO:${NC}      %-*s ${DIM}|${NC}\n" "$((inner_w - 9))" "${TARGET_OS:-linux}"
  if [[ -d "$BACKUP_DIR" ]]; then
    printf "${DIM}|${NC} ${CYAN}Backup:${NC}  %-*s ${DIM}|${NC}\n" "$((inner_w - 9))" "$BACKUP_DIR"
  fi
  echo -e "${DIM}+${line}+${NC}"
  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # COLUNAS: FERRAMENTAS | RUNTIMES
  # ═══════════════════════════════════════════════════════════════════════════
  local col_total=$((w - 5))
  local col_w=$((col_total / 2))
  local col_line
  col_line=$(_hline "$col_w" "-")

  # Coletar dados
  local tools=()
  _add_tool_if_version tools "Git" git "$col_w"
  _add_tool_if_version tools "Zsh" zsh "$col_w"
  _add_tool_if_version tools "Fish" fish "$col_w"
  _add_tool_if_version tools "Tmux" tmux "$col_w"
  _add_tool_if_version tools "Neovim" nvim "$col_w"
  _add_tool_if_version tools "Starship" starship "$col_w"
  _add_tool_if_version tools "VS Code" code "$col_w"
  _add_tool_if_version tools "Docker" docker "$col_w"
  _add_tool_if_version tools "Mise" mise "$col_w"
  _add_tool_if_version tools "Lazygit" lazygit "$col_w"
  [[ ${#tools[@]} -eq 0 ]] && tools+=("(nenhuma)")

  local runtimes=()
  _add_tool_if_version runtimes "Node" node "$col_w"
  _add_tool_if_version runtimes "Python" python "$col_w"
  _add_tool_if_version runtimes "PHP" php "$col_w"
  _add_tool_if_version runtimes "Rust" rust "$col_w"
  _add_tool_if_version runtimes "Go" go "$col_w"
  _add_tool_if_version runtimes "Bun" bun "$col_w"
  _add_tool_if_version runtimes "Deno" deno "$col_w"
  [[ ${#runtimes[@]} -eq 0 ]] && runtimes+=("(nenhum)")

  # Desenhar tabela
  echo -e "${CYAN}+${col_line}+${col_line}+${NC}"
  printf "${CYAN}|${NC} ${WHITE}${BOLD}%-*s${NC}${CYAN}|${NC} ${WHITE}${BOLD}%-*s${NC}${CYAN}|${NC}\n" "$((col_w - 1))" "FERRAMENTAS" "$((col_w - 1))" "RUNTIMES"
  echo -e "${CYAN}+${col_line}+${col_line}+${NC}"

  local max=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max ]] && max=${#runtimes[@]}
  for (( i=0; i<max; i++ )); do
    local left="${tools[i]:-}"
    local right="${runtimes[i]:-}"
    printf "${CYAN}|${NC} ${GREEN}%-*s${NC}${CYAN}|${NC} ${MAGENTA}%-*s${NC}${CYAN}|${NC}\n" "$((col_w - 1))" "$left" "$((col_w - 1))" "$right"
  done

  echo -e "${CYAN}+${col_line}+${col_line}+${NC}"

  # ═══════════════════════════════════════════════════════════════════════════
  # COLUNAS: PROXIMO PASSO | COMANDOS UTEIS
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""

  local next_steps=()
  next_steps+=("exec \$SHELL")
  if [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]]; then
    next_steps+=("p10k configure")
  fi
  if [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]]; then
    next_steps+=("Fonte: ${SELECTED_NERD_FONTS[0]}")
  fi

  local commands=()
  commands+=("install.sh export")
  commands+=("install.sh sync")
  has_cmd lazygit && commands+=("lazygit")
  has_cmd zoxide && commands+=("z <dir>")

  echo -e "${GREEN}+${col_line}+${col_line}+${NC}"
  printf "${GREEN}|${NC} ${WHITE}${BOLD}%-*s${NC}${GREEN}|${NC} ${WHITE}${BOLD}%-*s${NC}${GREEN}|${NC}\n" "$((col_w - 1))" "PROXIMO PASSO" "$((col_w - 1))" "COMANDOS UTEIS"
  echo -e "${GREEN}+${col_line}+${col_line}+${NC}"

  local steps_max=${#next_steps[@]}
  [[ ${#commands[@]} -gt $steps_max ]] && steps_max=${#commands[@]}
  for (( i=0; i<steps_max; i++ )); do
    local left="${next_steps[i]:-}"
    local right="${commands[i]:-}"
    printf "${GREEN}|${NC} ${YELLOW}%-*s${NC}${GREEN}|${NC} ${DIM}%-*s${NC}${GREEN}|${NC}\n" "$((col_w - 1))" "$left" "$((col_w - 1))" "$right"
  done

  echo -e "${GREEN}+${col_line}+${col_line}+${NC}"

  # ═══════════════════════════════════════════════════════════════════════════
  # MISE (se instalado)
  # ═══════════════════════════════════════════════════════════════════════════
  if has_cmd mise; then
    echo ""
    echo -e "${DIM}+-- ${WHITE}Mise${DIM} $(_hline $((w - 10)) "-")+${NC}"
    printf "${DIM}|${NC}  %-24s ${DIM}%-*s${NC} ${DIM}|${NC}\n" "mise ls" "$((inner_w - 27))" "Listar instalados"
    printf "${DIM}|${NC}  %-24s ${DIM}%-*s${NC} ${DIM}|${NC}\n" "mise use -g node@lts" "$((inner_w - 27))" "Node LTS global"
    printf "${DIM}|${NC}  %-24s ${DIM}%-*s${NC} ${DIM}|${NC}\n" "mise use python@latest" "$((inner_w - 27))" "Python no projeto"
    printf "${DIM}|${NC}  %-24s ${DIM}%-*s${NC} ${DIM}|${NC}\n" "mise install" "$((inner_w - 27))" "Instalar do .mise.toml"
    echo -e "${DIM}+${line}+${NC}"
  fi

  # ═══════════════════════════════════════════════════════════════════════════
  # FOOTER
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""
  echo -e "  ${BLUE}lucassr.dev${NC} ${DIM}|${NC} ${GREEN}github.com/lucassr-dev/.config${NC}"
  echo ""
}
