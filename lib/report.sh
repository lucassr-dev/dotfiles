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

_rpt_strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

_rpt_visible_len() {
  local text="$1"
  local clean
  clean=$(printf '%s' "$text" | _rpt_strip_ansi)
  local display_w
  display_w=$(printf '%s' "$clean" | wc -L 2>/dev/null) || display_w=${#clean}
  echo "$display_w"
}

_truncate() {
  local max="$1"
  local text="$2"
  local vis
  vis=$(_rpt_visible_len "$text")
  if [[ $vis -le $max ]]; then
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
  local vis_w
  vis_w=$(_rpt_visible_len "$title")
  local pad=$((col_w - 3 - vis_w))
  [[ $pad -lt 0 ]] && pad=0
  _hline "$pad"
}

_rpt_print_box_line() {
  local inner_w="$1"
  local content="$2"
  local align="${3:-left}"
  local border_color="$4"
  local visible
  visible=$(_rpt_visible_len "$content")
  local pad=$((inner_w - 2 - visible))
  if [[ $pad -lt 0 ]]; then
    local clean
    clean=$(printf '%s' "$content" | _rpt_strip_ansi)
    content=$(_truncate "$((inner_w - 2))" "$clean")
    visible=$(_rpt_visible_len "$content")
    pad=$((inner_w - 2 - visible))
    [[ $pad -lt 0 ]] && pad=0
  fi

  if [[ "$align" == "center" ]]; then
    local left_pad=$((pad / 2))
    local right_pad=$((pad - left_pad))
    printf "%b│%b %*s%b%*s %b│%b\n" "$border_color" "$NC" "$left_pad" "" "$content" "$right_pad" "" "$border_color" "$NC"
  else
    printf "%b│%b %b%*s %b│%b\n" "$border_color" "$NC" "$content" "$pad" "" "$border_color" "$NC"
  fi
}

print_post_install_report() {
  local username="${USER:-$(whoami)}"
  local hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo 'localhost')}"
  local current_shell="${SHELL##*/}"
  local host_ip
  host_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")

  local GREEN=$'\033[38;2;166;227;161m'
  local YELLOW=$'\033[38;2;249;226;175m'
  local BLUE=$'\033[38;2;137;180;250m'
  local CYAN=$'\033[38;2;137;220;235m'
  local MAGENTA=$'\033[38;2;203;166;247m'
  local WHITE=$'\033[38;2;205;214;244m'
  local BOLD=$'\033[1m'
  local DIM=$'\033[2m'
  local NC=$'\033[0m'

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

  echo -e "${CYAN}╭$(_hline "$inner_w")╮${NC}"
  local title="INSTALAÇÃO CONCLUÍDA"
  _rpt_print_box_line "$inner_w" "${YELLOW}${BOLD}${title}${NC}" "center" "$CYAN"
  echo -e "${CYAN}├─ ${BOLD}SISTEMA${NC}${CYAN} $(_rpt_title_pad "$inner_w" "SISTEMA")┤${NC}"
  printf "${CYAN}│${NC} ${WHITE}Host:${NC} ${GREEN}%-$((half_w - 6))s${NC} ${WHITE}Usuário:${NC} ${GREEN}%-$((half_w - 9))s${NC} ${CYAN}│${NC}\n" "$(_truncate $((half_w - 6)) "$hostname")" "$(_truncate $((half_w - 9)) "$username")"
  printf "${CYAN}│${NC} ${WHITE}SO:${NC}   ${GREEN}%-$((half_w - 6))s${NC} ${WHITE}Shell:${NC}   ${GREEN}%-$((half_w - 9))s${NC} ${CYAN}│${NC}\n" "${TARGET_OS:-linux}" "$current_shell"

  local pkg_count=${#INSTALLED_PACKAGES[@]}
  local misc_count=${#INSTALLED_MISC[@]}
  local total_installed=$((pkg_count + misc_count))
  local critical_count=${#CRITICAL_ERRORS[@]}
  local optional_count=${#OPTIONAL_ERRORS[@]}
  local total_errors=$((critical_count + optional_count))
  local configs_count=${#COPIED_PATHS[@]}

  printf "${CYAN}│${NC} ${GREEN}✅ %-$((half_w - 3))s${NC} ${YELLOW}⚠ %-$((half_w - 3))s${NC} ${CYAN}│${NC}\n" "Instalados: ${total_installed}" "Falhas: ${total_errors}"
  printf "${CYAN}│${NC} ${BLUE}📁 %-$((half_w - 3))s${NC} ${DIM}⏱  %-$((half_w - 3))s${NC} ${CYAN}│${NC}\n" "Configs: ${configs_count}" "$(_report_time_str)"
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

  echo -e "${CYAN}╭─ ${BOLD}FERRAMENTAS${NC}${CYAN} $(_rpt_title_pad "$col_w" "FERRAMENTAS")┬─ ${BOLD}RUNTIMES${NC}${CYAN} $(_rpt_title_pad "$col_w" "RUNTIMES")╮${NC}"
  for (( i=0; i<max_tools; i++ )); do
    printf "${CYAN}│${NC} ${GREEN}%-*s${NC} ${CYAN}│${NC} ${MAGENTA}%-*s${NC} ${CYAN}│${NC}\n" "$cell_w" "${tools[i]:-}" "$cell_w" "${runtimes[i]:-}"
  done
  echo -e "${CYAN}├─ ${BOLD}PRÓXIMO PASSO${NC}${CYAN} $(_rpt_title_pad "$col_w" "PRÓXIMO PASSO")┼─ ${BOLD}COMANDOS${NC}${CYAN} $(_rpt_title_pad "$col_w" "COMANDOS")┤${NC}"
  for (( i=0; i<max_steps; i++ )); do
    printf "${CYAN}│${NC} ${YELLOW}%-*s${NC} ${CYAN}│${NC} ${DIM}%-*s${NC} ${CYAN}│${NC}\n" "$cell_w" "${next_steps[i]:-}" "$cell_w" "${commands[i]:-}"
  done
  echo -e "${CYAN}╰$(_hline "$col_w")┴$(_hline "$col_w")╯${NC}"

  local backup_link="${BACKUP_DIR:-}"
  if [[ -n "$backup_link" ]] && [[ ! -d "$backup_link" ]]; then
    backup_link="(nenhum backup criado)"
  fi
  [[ -z "$backup_link" ]] && backup_link="(nenhum backup criado)"
  local site_link="https://lucassr.dev"
  local repo_link="https://github.com/lucassr-dev/.config"
  local footer_inner="$inner_w"
  local footer_value_w=$((footer_inner - 12))
  [[ $footer_value_w -lt 16 ]] && footer_value_w=16

  echo ""
  echo -e "${CYAN}╭$(_hline "$footer_inner")╮${NC}"
  _rpt_print_box_line "$footer_inner" "${BOLD}LOG E LINKS${NC}" "center" "$CYAN"
  echo -e "${CYAN}├$(_hline "$footer_inner")┤${NC}"
  _rpt_print_box_line "$footer_inner" "💾 ${WHITE}Backup:${NC} ${DIM}$(_truncate "$footer_value_w" "$backup_link")${NC}" "left" "$CYAN"
  _rpt_print_box_line "$footer_inner" "🌐 ${WHITE}Site:${NC} ${BLUE}$(_truncate "$footer_value_w" "$site_link")${NC}" "left" "$CYAN"
  _rpt_print_box_line "$footer_inner" "📦 ${WHITE}Repositório:${NC} ${BLUE}$(_truncate "$footer_value_w" "$repo_link")${NC}" "left" "$CYAN"
  echo -e "${CYAN}╰$(_hline "$footer_inner")╯${NC}"
  echo ""
}

_report_time_str() {
  if [[ -n "${INSTALL_START_TIME:-}" ]] && [[ "${INSTALL_START_TIME:-0}" -gt 0 ]]; then
    local total_elapsed=$((SECONDS - INSTALL_START_TIME))
    _format_elapsed "$total_elapsed"
  fi
}
