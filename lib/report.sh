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
  printf '%*s' "$width" '' | tr ' ' '─'
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
  local current_shell="${SHELL##*/}"
  local host_ip
  host_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")

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

  [[ -t 1 ]] && clear

  echo ""

  echo -e "${GREEN}╭$(_hline "$inner_w")╮${NC}"
  local title="✨ INSTALAÇÃO CONCLUÍDA! ✨"
  local title_len=${#title}
  local title_pad=$(( (inner_w - title_len) / 2 ))
  printf "${GREEN}│${NC}%*s${YELLOW}${BOLD}%s${NC}%*s${GREEN}│${NC}\n" "$title_pad" "" "$title" "$((inner_w - title_pad - title_len))" ""
  echo -e "${GREEN}╰$(_hline "$inner_w")╯${NC}"

  echo ""
  local half_w=$(( (inner_w - 3) / 2 ))
  echo -e "${CYAN}╭─ ${BOLD}🖥️  SISTEMA${NC}${CYAN} $(_hline $((inner_w - 13)))╮${NC}"
  printf "${CYAN}│${NC} ${WHITE}Host:${NC} ${GREEN}%-$((half_w - 6))s${NC} ${WHITE}Usuário:${NC} ${GREEN}%-$((half_w - 9))s${NC} ${CYAN}│${NC}\n" "$(_truncate $((half_w - 6)) "$hostname")" "$(_truncate $((half_w - 9)) "$username")"
  printf "${CYAN}│${NC} ${WHITE}SO:${NC}   ${GREEN}%-$((half_w - 6))s${NC} ${WHITE}Shell:${NC}   ${GREEN}%-$((half_w - 9))s${NC} ${CYAN}│${NC}\n" "${TARGET_OS:-linux}" "$current_shell"
  printf "${CYAN}│${NC} ${WHITE}IP:${NC}   ${DIM}%-$((inner_w - 7))s${NC} ${CYAN}│${NC}\n" "$host_ip"
  if [[ -d "$BACKUP_DIR" ]]; then
    printf "${CYAN}│${NC} ${WHITE}Backup:${NC} ${DIM}%-$((inner_w - 10))s${NC} ${CYAN}│${NC}\n" "$(_truncate $((inner_w - 10)) "$BACKUP_DIR")"
  fi
  echo -e "${CYAN}╰$(_hline "$inner_w")╯${NC}"

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

  local left_title="🛠️  FERRAMENTAS"
  local right_title="🚀 RUNTIMES"
  local left_pad=$((col_w - ${#left_title} - 2))
  local right_pad=$((col_w - ${#right_title} - 2))
  [[ $left_pad -lt 0 ]] && left_pad=0
  [[ $right_pad -lt 0 ]] && right_pad=0

  echo -e "${CYAN}╭─ ${BOLD}${left_title}${NC}${CYAN} $(_hline "$left_pad")┬─ ${BOLD}${right_title}${NC}${CYAN} $(_hline "$right_pad")╮${NC}"

  local max=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max ]] && max=${#runtimes[@]}
  for (( i=0; i<max; i++ )); do
    local left="${tools[i]:-}"
    local right="${runtimes[i]:-}"
    printf "${CYAN}│${NC} ${GREEN}%-*s${NC} ${CYAN}│${NC} ${MAGENTA}%-*s${NC} ${CYAN}│${NC}\n" "$cell_w" "$left" "$cell_w" "$right"
  done

  echo -e "${CYAN}╰$(_hline "$col_w")┴$(_hline "$col_w")╯${NC}"

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

  local left_title2="⚡ PRÓXIMO PASSO"
  local right_title2="💡 COMANDOS ÚTEIS"
  local left_pad2=$((col_w - ${#left_title2} - 2))
  local right_pad2=$((col_w - ${#right_title2} - 2))
  [[ $left_pad2 -lt 0 ]] && left_pad2=0
  [[ $right_pad2 -lt 0 ]] && right_pad2=0

  echo -e "${GREEN}╭─ ${BOLD}${left_title2}${NC}${GREEN} $(_hline "$left_pad2")┬─ ${BOLD}${right_title2}${NC}${GREEN} $(_hline "$right_pad2")╮${NC}"

  local steps_max=${#next_steps[@]}
  [[ ${#commands[@]} -gt $steps_max ]] && steps_max=${#commands[@]}
  for (( i=0; i<steps_max; i++ )); do
    local left="${next_steps[i]:-}"
    local right="${commands[i]:-}"
    printf "${GREEN}│${NC} ${YELLOW}%-*s${NC} ${GREEN}│${NC} ${DIM}%-*s${NC} ${GREEN}│${NC}\n" "$cell_w" "$left" "$cell_w" "$right"
  done

  echo -e "${GREEN}╰$(_hline "$col_w")┴$(_hline "$col_w")╯${NC}"

  if has_cmd mise; then
    echo ""
    local mise_title="📦 Mise"
    local mise_pad=$((inner_w - ${#mise_title} - 3))
    echo -e "${DIM}╭─ ${WHITE}${mise_title}${DIM} $(_hline "$mise_pad")╮${NC}"
    local cmd_w=24
    local desc_w=$((inner_w - cmd_w - 4))
    printf "${DIM}│${NC}  ${WHITE}%-${cmd_w}s${NC}${DIM}%-${desc_w}s${NC} ${DIM}│${NC}\n" "mise ls" "Listar instalados"
    printf "${DIM}│${NC}  ${WHITE}%-${cmd_w}s${NC}${DIM}%-${desc_w}s${NC} ${DIM}│${NC}\n" "mise use -g node@lts" "Node LTS global"
    printf "${DIM}│${NC}  ${WHITE}%-${cmd_w}s${NC}${DIM}%-${desc_w}s${NC} ${DIM}│${NC}\n" "mise use python@latest" "Python no projeto"
    printf "${DIM}│${NC}  ${WHITE}%-${cmd_w}s${NC}${DIM}%-${desc_w}s${NC} ${DIM}│${NC}\n" "mise install" "Instalar do .mise.toml"
    echo -e "${DIM}╰$(_hline "$inner_w")╯${NC}"
  fi

  echo ""
  echo -e "  ${BLUE}🌐 lucassr.dev${NC} ${DIM}│${NC} ${GREEN}📦 github.com/lucassr-dev/.config${NC}"
  echo ""
}
