#!/usr/bin/env bash
# shellcheck disable=SC2034

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

_hline() {
  local width="$1"
  local char="${2:--}"
  printf '%*s' "$width" '' | tr ' ' "$char"
}

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

_fmt_tool() {
  local name="$1"
  local version="$2"
  local max_w="${3:-30}"
  local text="$name"
  [[ -n "$version" ]] && text+=" $version"
  _truncate "$max_w" "$text"
}

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

print_post_install_report() {
  local username="${USER:-$(whoami)}"
  local hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo 'localhost')}"

  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local MAGENTA='\033[0;35m'
  local WHITE='\033[1;37m'
  local BOLD='\033[1m'
  local DIM='\033[2m'
  local NC='\033[0m'

  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)

  local col_w=36
  [[ $term_w -lt 78 ]] && col_w=30
  [[ $term_w -lt 66 ]] && col_w=24

  local total_w=$((col_w * 2 + 3))
  local inner_w=$((total_w - 2))
  local cell_w=$((col_w - 2))

  local full_line col_line header_line
  full_line=$(_hline "$inner_w" "-")
  col_line=$(_hline "$col_w" "-")
  header_line=$(_hline "$inner_w" "=")

  [[ -t 1 ]] && clear

  echo ""

  echo -e "${GREEN}+${header_line}+${NC}"
  local title="INSTALACAO CONCLUIDA!"
  local title_pad=$(( (inner_w - ${#title}) / 2 ))
  printf "${GREEN}|${NC}%*s${YELLOW}${BOLD}%s${NC}%*s${GREEN}|${NC}\n" "$title_pad" "" "$title" "$((inner_w - title_pad - ${#title}))" ""
  echo -e "${GREEN}+${header_line}+${NC}"
  echo ""

  local info_w=$((inner_w - 2))

  echo -e "${DIM}+${full_line}+${NC}"
  printf "${DIM}|${NC} ${CYAN}%-10s${NC}%-*s ${DIM}|${NC}\n" "Usuario:" "$((info_w - 10))" "$(_truncate $((info_w - 10)) "$username")"
  printf "${DIM}|${NC} ${CYAN}%-10s${NC}%-*s ${DIM}|${NC}\n" "Host:" "$((info_w - 10))" "$(_truncate $((info_w - 10)) "$hostname")"
  printf "${DIM}|${NC} ${CYAN}%-10s${NC}%-*s ${DIM}|${NC}\n" "SO:" "$((info_w - 10))" "${TARGET_OS:-linux}"
  if [[ -d "$BACKUP_DIR" ]]; then
    printf "${DIM}|${NC} ${CYAN}%-10s${NC}%-*s ${DIM}|${NC}\n" "Backup:" "$((info_w - 10))" "$(_truncate $((info_w - 10)) "$BACKUP_DIR")"
  fi
  echo -e "${DIM}+${full_line}+${NC}"
  echo ""

  local tools=()
  _add_tool_if_version tools "Git" git "$cell_w"
  _add_tool_if_version tools "Zsh" zsh "$cell_w"
  _add_tool_if_version tools "Fish" fish "$cell_w"
  _add_tool_if_version tools "Tmux" tmux "$cell_w"
  _add_tool_if_version tools "Neovim" nvim "$cell_w"
  _add_tool_if_version tools "Starship" starship "$cell_w"
  _add_tool_if_version tools "VS Code" code "$cell_w"
  _add_tool_if_version tools "Docker" docker "$cell_w"
  _add_tool_if_version tools "Mise" mise "$cell_w"
  _add_tool_if_version tools "Lazygit" lazygit "$cell_w"
  [[ ${#tools[@]} -eq 0 ]] && tools+=("(nenhuma)")

  local runtimes=()
  _add_tool_if_version runtimes "Node" node "$cell_w"
  _add_tool_if_version runtimes "Python" python "$cell_w"
  _add_tool_if_version runtimes "PHP" php "$cell_w"
  _add_tool_if_version runtimes "Rust" rust "$cell_w"
  _add_tool_if_version runtimes "Go" go "$cell_w"
  _add_tool_if_version runtimes "Bun" bun "$cell_w"
  _add_tool_if_version runtimes "Deno" deno "$cell_w"
  [[ ${#runtimes[@]} -eq 0 ]] && runtimes+=("(nenhum)")

  echo -e "${CYAN}+${col_line}+${col_line}+${NC}"
  printf "${CYAN}|${NC} ${WHITE}${BOLD}%-*s${NC} ${CYAN}|${NC} ${WHITE}${BOLD}%-*s${NC} ${CYAN}|${NC}\n" "$cell_w" "FERRAMENTAS" "$cell_w" "RUNTIMES"
  echo -e "${CYAN}+${col_line}+${col_line}+${NC}"

  local max=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max ]] && max=${#runtimes[@]}
  for (( i=0; i<max; i++ )); do
    local left="${tools[i]:-}"
    local right="${runtimes[i]:-}"
    printf "${CYAN}|${NC} ${GREEN}%-*s${NC} ${CYAN}|${NC} ${MAGENTA}%-*s${NC} ${CYAN}|${NC}\n" "$cell_w" "$left" "$cell_w" "$right"
  done

  echo -e "${CYAN}+${col_line}+${col_line}+${NC}"

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
  printf "${GREEN}|${NC} ${WHITE}${BOLD}%-*s${NC} ${GREEN}|${NC} ${WHITE}${BOLD}%-*s${NC} ${GREEN}|${NC}\n" "$cell_w" "PROXIMO PASSO" "$cell_w" "COMANDOS UTEIS"
  echo -e "${GREEN}+${col_line}+${col_line}+${NC}"

  local steps_max=${#next_steps[@]}
  [[ ${#commands[@]} -gt $steps_max ]] && steps_max=${#commands[@]}
  for (( i=0; i<steps_max; i++ )); do
    local left="${next_steps[i]:-}"
    local right="${commands[i]:-}"
    printf "${GREEN}|${NC} ${YELLOW}%-*s${NC} ${GREEN}|${NC} ${DIM}%-*s${NC} ${GREEN}|${NC}\n" "$cell_w" "$left" "$cell_w" "$right"
  done

  echo -e "${GREEN}+${col_line}+${col_line}+${NC}"

  if has_cmd mise; then
    echo ""
    local mise_title="Mise"
    local mise_line_w=$((inner_w - ${#mise_title} - 4))
    echo -e "${DIM}+-- ${WHITE}${mise_title}${DIM} $(_hline "$mise_line_w" "-")+${NC}"
    printf "${DIM}|${NC}  %-24s %-*s ${DIM}|${NC}\n" "mise ls" "$((info_w - 26))" "Listar instalados"
    printf "${DIM}|${NC}  %-24s %-*s ${DIM}|${NC}\n" "mise use -g node@lts" "$((info_w - 26))" "Node LTS global"
    printf "${DIM}|${NC}  %-24s %-*s ${DIM}|${NC}\n" "mise use python@latest" "$((info_w - 26))" "Python no projeto"
    printf "${DIM}|${NC}  %-24s %-*s ${DIM}|${NC}\n" "mise install" "$((info_w - 26))" "Instalar do .mise.toml"
    echo -e "${DIM}+${full_line}+${NC}"
  fi

  echo ""
  echo -e "  ${BLUE}lucassr.dev${NC} ${DIM}|${NC} ${GREEN}github.com/lucassr-dev/.config${NC}"
  echo ""
}
