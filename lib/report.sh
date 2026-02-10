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
  local i line=""
  for ((i=0; i<width; i++)); do line+="─"; done
  printf '%s' "$line"
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

_rpt_title_pad() {
  local col_w="$1" title="$2"
  local clean
  clean=$(printf '%s' "$title" | sed -E 's/\x1b\[[0-9;]*m//g')
  local vis_w
  vis_w=$(printf '%s' "$clean" | wc -L 2>/dev/null) || vis_w=${#clean}
  local pad=$((col_w - 3 - vis_w))
  [[ $pad -lt 0 ]] && pad=0
  _hline "$pad"
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
  local half_w=$(( (inner_w - 3) / 2 ))

  clear_screen
  echo ""

  echo -e "${GREEN}╭$(_hline "$inner_w")╮${NC}"
  local title="✨ INSTALAÇÃO CONCLUÍDA! ✨"
  local title_len=${#title}
  local title_pad=$(( (inner_w - title_len) / 2 ))
  printf "${GREEN}│${NC}%*s${YELLOW}${BOLD}%s${NC}%*s${GREEN}│${NC}\n" "$title_pad" "" "$title" "$((inner_w - title_pad - title_len))" ""
  echo -e "${GREEN}├─ ${BOLD}🖥️  SISTEMA${NC}${GREEN} $(_rpt_title_pad "$inner_w" "🖥️  SISTEMA")┤${NC}"
  printf "${GREEN}│${NC} ${WHITE}Host:${NC} ${GREEN}%-$((half_w - 6))s${NC} ${WHITE}Usuário:${NC} ${GREEN}%-$((half_w - 9))s${NC} ${GREEN}│${NC}\n" "$(_truncate $((half_w - 6)) "$hostname")" "$(_truncate $((half_w - 9)) "$username")"
  printf "${GREEN}│${NC} ${WHITE}SO:${NC}   ${GREEN}%-$((half_w - 6))s${NC} ${WHITE}Shell:${NC}   ${GREEN}%-$((half_w - 9))s${NC} ${GREEN}│${NC}\n" "${TARGET_OS:-linux}" "$current_shell"

  local pkg_count=${#INSTALLED_PACKAGES[@]}
  local misc_count=${#INSTALLED_MISC[@]}
  local total_installed=$((pkg_count + misc_count))
  local critical_count=${#CRITICAL_ERRORS[@]}
  local optional_count=${#OPTIONAL_ERRORS[@]}
  local total_errors=$((critical_count + optional_count))
  local configs_count=${#COPIED_PATHS[@]}

  printf "${GREEN}│${NC} ${GREEN}✅ %-$((half_w - 3))s${NC} ${YELLOW}⚠ %-$((half_w - 3))s${NC} ${GREEN}│${NC}\n" "Instalados: ${total_installed}" "Falhas: ${total_errors}"
  printf "${GREEN}│${NC} ${BLUE}📁 %-$((half_w - 3))s${NC} ${DIM}⏱  %-$((half_w - 3))s${NC} ${GREEN}│${NC}\n" "Configs: ${configs_count}" "$(_report_time_str)"
  echo -e "${GREEN}╰$(_hline "$inner_w")╯${NC}"

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

  local next_steps=()
  next_steps+=("exec \$SHELL")
  [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]] && next_steps+=("p10k configure")
  [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]] && next_steps+=("Fonte: ${SELECTED_NERD_FONTS[0]}")

  local commands=()
  commands+=("install.sh export")
  commands+=("install.sh sync")
  has_cmd lazygit && commands+=("lazygit")
  has_cmd zoxide && commands+=("z <dir>")

  local max_tools=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max_tools ]] && max_tools=${#runtimes[@]}
  local max_steps=${#next_steps[@]}
  [[ ${#commands[@]} -gt $max_steps ]] && max_steps=${#commands[@]}

  echo -e "${CYAN}╭─ ${BOLD}🛠️  FERRAMENTAS${NC}${CYAN} $(_rpt_title_pad "$col_w" "🛠️  FERRAMENTAS")┬─ ${BOLD}🚀 RUNTIMES${NC}${CYAN} $(_rpt_title_pad "$col_w" "🚀 RUNTIMES")╮${NC}"
  for (( i=0; i<max_tools; i++ )); do
    printf "${CYAN}│${NC} ${GREEN}%-*s${NC} ${CYAN}│${NC} ${MAGENTA}%-*s${NC} ${CYAN}│${NC}\n" "$cell_w" "${tools[i]:-}" "$cell_w" "${runtimes[i]:-}"
  done
  echo -e "${CYAN}├─ ${BOLD}⚡ PRÓXIMO PASSO${NC}${CYAN} $(_rpt_title_pad "$col_w" "⚡ PRÓXIMO PASSO")┼─ ${BOLD}💡 COMANDOS${NC}${CYAN} $(_rpt_title_pad "$col_w" "💡 COMANDOS")┤${NC}"
  for (( i=0; i<max_steps; i++ )); do
    printf "${CYAN}│${NC} ${YELLOW}%-*s${NC} ${CYAN}│${NC} ${DIM}%-*s${NC} ${CYAN}│${NC}\n" "$cell_w" "${next_steps[i]:-}" "$cell_w" "${commands[i]:-}"
  done
  echo -e "${CYAN}╰$(_hline "$col_w")┴$(_hline "$col_w")╯${NC}"

  local footer_parts=()
  if [[ -n "${INSTALL_LOG:-}" ]] && [[ -f "${INSTALL_LOG:-}" ]]; then
    footer_parts+=("📄 ${INSTALL_LOG}")
  fi
  footer_parts+=("🌐 lucassr.dev")
  footer_parts+=("📦 github.com/lucassr-dev/.config")
  echo ""
  echo -e "  ${DIM}$(IFS=' │ '; echo "${footer_parts[*]}")${NC}"
  echo ""
}

_report_time_str() {
  if [[ -n "${INSTALL_START_TIME:-}" ]] && [[ "${INSTALL_START_TIME:-0}" -gt 0 ]]; then
    local total_elapsed=$((SECONDS - INSTALL_START_TIME))
    _format_elapsed "$total_elapsed"
  fi
}
