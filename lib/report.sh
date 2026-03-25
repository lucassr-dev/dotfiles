#!/usr/bin/env bash
# shellcheck disable=SC2034
# ═══════════════════════════════════════════════════════════
# Report — Dashboard pós-instalação (INSTALAÇÃO CONCLUÍDA)
# ═══════════════════════════════════════════════════════════
#
# Requer: lib/colors.sh, lib/utils.sh, lib/components.sh

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

_rpt_add_tool() {
  local -n _arr="$1"
  local name="$2" cmd="$3" width="$4"
  local version
  version=$(get_version "$cmd")
  if [[ -n "$version" ]]; then
    local text="$name $version"
    [[ ${#text} -gt $width ]] && text="${text:0:$((width-3))}..."
    _arr+=("$text")
  fi
}

_report_time_str() {
  if [[ -n "${INSTALL_START_TIME:-}" ]] && [[ "${INSTALL_START_TIME:-0}" -gt 0 ]]; then
    local total_elapsed=$((SECONDS - INSTALL_START_TIME))
    _format_elapsed "$total_elapsed"
  fi
}

print_post_install_report() {
  local username="${USER:-$(whoami)}"
  local hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo 'localhost')}"
  local current_shell="${SHELL##*/}"
  local host_ip
  if [[ "${TARGET_OS:-linux}" == "macos" ]]; then
    host_ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "N/A")
  else
    host_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
  fi

  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)

  local width=$((term_w > 76 ? 76 : term_w - 4))
  [[ $width -lt 40 ]] && width=40
  local col_w=$(( (width - 6) / 2 ))

  _rpt_div() {
    local title="$1"
    local title_vis fill fill_str
    title_vis=$(_visible_len "$title")
    fill=$(( width - title_vis - 4 ))
    [[ $fill -lt 0 ]] && fill=0
    printf -v fill_str '%*s' "$fill" ''
    echo -e "${UI_BORDER}── ${UI_ACCENT}${UI_BOLD}${title}${UI_RESET}${UI_BORDER} ${fill_str// /─}${UI_RESET}"
  }

  _rpt_dual_div() {
    local left="$1" right="$2"
    local lv rv lf rf lfill rfill
    lv=$(_visible_len "$left"); rv=$(_visible_len "$right")
    lf=$(( col_w - lv - 1 )); rf=$(( col_w - rv - 1 ))
    [[ $lf -lt 0 ]] && lf=0; [[ $rf -lt 0 ]] && rf=0
    printf -v lfill '%*s' "$lf" ''; printf -v rfill '%*s' "$rf" ''
    echo -e "${UI_BORDER}── ${UI_ACCENT}${UI_BOLD}${left}${UI_RESET}${UI_BORDER} ${lfill// /─}  ── ${UI_ACCENT}${UI_BOLD}${right}${UI_RESET}${UI_BORDER} ${rfill// /─}${UI_RESET}"
  }

  _rpt_hbar() {
    local bar
    printf -v bar '%*s' "$width" ''
    echo -e "${UI_BORDER}${bar// /─}${UI_RESET}"
  }

  clear_screen
  echo ""

  _rpt_hbar
  echo -e "  ${UI_GREEN}${UI_BOLD}◆  INSTALAÇÃO CONCLUÍDA  ◆${UI_RESET}"
  _rpt_hbar
  echo ""

  local pkg_count=${#INSTALLED_PACKAGES[@]}
  local misc_count=${#INSTALLED_MISC[@]}
  local total_installed=$((pkg_count + misc_count))
  local critical_count=${#CRITICAL_ERRORS[@]}
  local optional_count=${#OPTIONAL_ERRORS[@]}
  local total_errors=$((critical_count + optional_count))
  local configs_count=${#COPIED_PATHS[@]}
  local elapsed
  elapsed=$(_report_time_str)

  local errors_color="$UI_GREEN"
  [[ $total_errors -gt 0 ]] && errors_color="$UI_RED"

  printf "  ${UI_GREEN}✓${UI_RESET}  ${UI_PEACH}${UI_BOLD}%s${UI_RESET}  ${UI_MUTED}instalados${UI_RESET}     " "$total_installed"
  printf "${errors_color}✗${UI_RESET}  ${errors_color}${UI_BOLD}%s${UI_RESET}  ${UI_MUTED}falhas${UI_RESET}\n" "$total_errors"
  printf "  ${UI_BLUE}📁${UI_RESET}  ${UI_BLUE}${UI_BOLD}%s${UI_RESET}  ${UI_MUTED}configs${UI_RESET}          " "$configs_count"
  printf "${UI_MUTED}⏱  %s${UI_RESET}\n" "${elapsed:-N/A}"
  echo ""

  local so_color="$UI_TEAL"
  [[ "${TARGET_OS:-linux}" == "macos" ]]   && so_color="$UI_PEACH"
  [[ "${TARGET_OS:-linux}" == "windows" ]] && so_color="$UI_BLUE"

  _rpt_div "💻 SISTEMA"
  printf "  ${UI_MUTED}Host    ${UI_RESET}  ${UI_TEXT}%-22s${UI_RESET}${UI_MUTED}Usuário ${UI_RESET}  ${UI_PEACH}%s${UI_RESET}\n" "$hostname" "$username"
  printf "  ${UI_MUTED}SO      ${UI_RESET}  ${so_color}%-22s${UI_RESET}${UI_MUTED}Shell   ${UI_RESET}  ${UI_GREEN}%s${UI_RESET}\n" "${TARGET_OS:-linux}" "$current_shell"
  printf "  ${UI_MUTED}IP      ${UI_RESET}  ${UI_DIM}%s${UI_RESET}\n" "$host_ip"
  echo ""

  local tools=()
  _rpt_add_tool tools "Git" git "$col_w"
  _rpt_add_tool tools "Zsh" zsh "$col_w"
  _rpt_add_tool tools "Fish" fish "$col_w"
  _rpt_add_tool tools "Tmux" tmux "$col_w"
  _rpt_add_tool tools "Neovim" nvim "$col_w"
  _rpt_add_tool tools "Starship" starship "$col_w"
  _rpt_add_tool tools "VS Code" code "$col_w"
  _rpt_add_tool tools "Docker" docker "$col_w"
  _rpt_add_tool tools "Mise" mise "$col_w"
  _rpt_add_tool tools "Lazygit" lazygit "$col_w"
  [[ ${#tools[@]} -eq 0 ]] && tools+=("(nenhuma)")

  local runtimes=()
  _rpt_add_tool runtimes "Node" node "$col_w"
  _rpt_add_tool runtimes "Python" python "$col_w"
  _rpt_add_tool runtimes "PHP" php "$col_w"
  _rpt_add_tool runtimes "Rust" rust "$col_w"
  _rpt_add_tool runtimes "Go" go "$col_w"
  _rpt_add_tool runtimes "Bun" bun "$col_w"
  _rpt_add_tool runtimes "Deno" deno "$col_w"
  [[ ${#runtimes[@]} -eq 0 ]] && runtimes+=("(nenhum)")

  local max_rows=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max_rows ]] && max_rows=${#runtimes[@]}

  _rpt_dual_div "🔧 FERRAMENTAS" "⚡ RUNTIMES"
  for (( i=0; i<max_rows; i++ )); do
    printf "  ${UI_GREEN}%-*s${UI_RESET}    ${UI_MAUVE}%s${UI_RESET}\n" "$col_w" "${tools[i]:-}" "${runtimes[i]:-}"
  done
  echo ""

  local next_steps=()
  next_steps+=("exec \$SHELL")
  [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]] && next_steps+=("p10k configure")
  [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]] && next_steps+=("Fonte: ${SELECTED_NERD_FONTS[0]}")

  local commands=()
  commands+=("install.sh export")
  commands+=("install.sh sync")
  has_cmd lazygit && commands+=("lazygit")
  has_cmd zoxide && commands+=("z <dir>")
  has_cmd mise && commands+=("mise ls / mise use")
  has_cmd bat && commands+=("bat <file>")

  local max_steps=${#next_steps[@]}
  [[ ${#commands[@]} -gt $max_steps ]] && max_steps=${#commands[@]}

  _rpt_dual_div "▶ PRÓXIMO PASSO" "💡 COMANDOS ÚTEIS"
  for (( i=0; i<max_steps; i++ )); do
    printf "  ${UI_YELLOW}%-*s${UI_RESET}    ${UI_MUTED}%s${UI_RESET}\n" "$col_w" "${next_steps[i]:-}" "${commands[i]:-}"
  done
  echo ""

  local backup_link="${BACKUP_DIR:-}"
  if [[ -n "$backup_link" ]] && [[ ! -d "$backup_link" ]]; then
    backup_link="(nenhum backup criado)"
  fi
  [[ -z "$backup_link" ]] && backup_link="(nenhum backup criado)"

  _rpt_div "🔗 LINKS"
  printf "  ${UI_MUTED}Backup       ${UI_RESET}  ${UI_DIM}%s${UI_RESET}\n" "$backup_link"
  printf "  ${UI_MUTED}Site         ${UI_RESET}  ${UI_LINK}%s${UI_RESET}\n" "https://lucassr.dev"
  printf "  ${UI_MUTED}Repositório  ${UI_RESET}  ${UI_LINK}%s${UI_RESET}\n" "https://github.com/lucassr-dev/.config"
  echo ""
  _rpt_hbar
  echo ""
}
