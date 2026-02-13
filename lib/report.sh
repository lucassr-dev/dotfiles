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

_rpt_hline() {
  local w="$1" line=""
  printf -v line '%*s' "$w" ''
  printf '%s' "${line// /─}"
}

_rpt_box_line() {
  local inner_w="$1" content="$2" align="${3:-left}"
  local vis_len pad
  vis_len=$(_visible_len "$content")
  pad=$((inner_w - 2 - vis_len))
  [[ $pad -lt 0 ]] && pad=0

  if [[ "$align" == "center" ]]; then
    local lp=$((pad / 2)) rp=$((pad - pad / 2))
    printf "%b│%b %*s%b%*s %b│%b\n" "$UI_BORDER" "$UI_RESET" "$lp" "" "$content" "$rp" "" "$UI_BORDER" "$UI_RESET"
  else
    printf "%b│%b %b%*s %b│%b\n" "$UI_BORDER" "$UI_RESET" "$content" "$pad" "" "$UI_BORDER" "$UI_RESET"
  fi
}

_rpt_section_header() {
  local inner_w="$1" title="$2"
  local title_len=${#title}
  local pad=$((inner_w - title_len - 3))
  [[ $pad -lt 0 ]] && pad=0
  echo -e "${UI_BORDER}├─ ${UI_ACCENT}${UI_BOLD}${title}${UI_RESET}${UI_BORDER} $(_rpt_hline "$pad")┤${UI_RESET}"
}

_rpt_dual_header() {
  local col_w="$1" left="$2" right="$3"
  local lp=$((col_w - ${#left} - 3))
  local rp=$((col_w - ${#right} - 3))
  [[ $lp -lt 0 ]] && lp=0
  [[ $rp -lt 0 ]] && rp=0
  echo -e "${UI_BORDER}├─ ${UI_ACCENT}${UI_BOLD}${left}${UI_RESET}${UI_BORDER} $(_rpt_hline "$lp")┬─ ${UI_ACCENT}${UI_BOLD}${right}${UI_RESET}${UI_BORDER} $(_rpt_hline "$rp")┤${UI_RESET}"
}

_rpt_dual_divider() {
  local col_w="$1" left="$2" right="$3"
  local lp=$((col_w - ${#left} - 3))
  local rp=$((col_w - ${#right} - 3))
  [[ $lp -lt 0 ]] && lp=0
  [[ $rp -lt 0 ]] && rp=0
  echo -e "${UI_BORDER}├─ ${UI_ACCENT}${UI_BOLD}${left}${UI_RESET}${UI_BORDER} $(_rpt_hline "$lp")┼─ ${UI_ACCENT}${UI_BOLD}${right}${UI_RESET}${UI_BORDER} $(_rpt_hline "$rp")┤${UI_RESET}"
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
  host_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")

  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)

  local col_w=36
  [[ $term_w -lt 78 ]] && col_w=30
  [[ $term_w -lt 66 ]] && col_w=24
  local inner_w=$((col_w * 2 + 1))
  local cell_w=$((col_w - 2))
  local half_w=$(( (inner_w - 3) / 2 ))

  clear_screen
  echo ""

  # ── Header: Título + Stats ──
  echo -e "${UI_BORDER}╭$(_rpt_hline "$inner_w")╮${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_GREEN}${UI_BOLD}  INSTALAÇÃO CONCLUÍDA${UI_RESET}" "center"
  echo -e "${UI_BORDER}├$(_rpt_hline "$inner_w")┤${UI_RESET}"

  local pkg_count=${#INSTALLED_PACKAGES[@]}
  local misc_count=${#INSTALLED_MISC[@]}
  local total_installed=$((pkg_count + misc_count))
  local critical_count=${#CRITICAL_ERRORS[@]}
  local optional_count=${#OPTIONAL_ERRORS[@]}
  local total_errors=$((critical_count + optional_count))
  local configs_count=${#COPIED_PATHS[@]}
  local elapsed
  elapsed=$(_report_time_str)

  # Stats em grid 2x2 (cores condicionais)
  local stat_w=$((half_w - 2))
  local errors_color="$UI_GREEN"
  [[ $total_errors -gt 0 ]] && errors_color="$UI_RED"

  printf "%b│%b  %b✓ Instalados: %-${stat_w}s%b  %b⚠ Falhas: %-${stat_w}s%b %b│%b\n" \
    "$UI_BORDER" "$UI_RESET" \
    "$UI_GREEN" "$total_installed" "$UI_RESET" \
    "$errors_color" "$total_errors" "$UI_RESET" \
    "$UI_BORDER" "$UI_RESET"
  printf "%b│%b  %b📁 Configs: %-${stat_w}s%b  %b⏱  %-${stat_w}s%b %b│%b\n" \
    "$UI_BORDER" "$UI_RESET" \
    "$UI_BLUE" "$configs_count" "$UI_RESET" \
    "$UI_MUTED" "${elapsed:-N/A}" "$UI_RESET" \
    "$UI_BORDER" "$UI_RESET"

  # ── Sistema ──
  _rpt_section_header "$inner_w" "SISTEMA"
  _rpt_box_line "$inner_w" "${UI_MUTED}Host${UI_RESET}     ${UI_TEXT}${hostname}${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_MUTED}Usuário${UI_RESET}  ${UI_TEXT}${username}${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_MUTED}SO${UI_RESET}       ${UI_TEXT}${TARGET_OS:-linux}${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_MUTED}Shell${UI_RESET}    ${UI_TEXT}${current_shell}${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_MUTED}IP${UI_RESET}       ${UI_DIM}${host_ip}${UI_RESET}"

  # ── Ferramentas + Runtimes (duas colunas) ──
  local tools=()
  _rpt_add_tool tools "Git" git "$cell_w"
  _rpt_add_tool tools "Zsh" zsh "$cell_w"
  _rpt_add_tool tools "Fish" fish "$cell_w"
  _rpt_add_tool tools "Tmux" tmux "$cell_w"
  _rpt_add_tool tools "Neovim" nvim "$cell_w"
  _rpt_add_tool tools "Starship" starship "$cell_w"
  _rpt_add_tool tools "VS Code" code "$cell_w"
  _rpt_add_tool tools "Docker" docker "$cell_w"
  _rpt_add_tool tools "Mise" mise "$cell_w"
  _rpt_add_tool tools "Lazygit" lazygit "$cell_w"
  [[ ${#tools[@]} -eq 0 ]] && tools+=("(nenhuma)")

  local runtimes=()
  _rpt_add_tool runtimes "Node" node "$cell_w"
  _rpt_add_tool runtimes "Python" python "$cell_w"
  _rpt_add_tool runtimes "PHP" php "$cell_w"
  _rpt_add_tool runtimes "Rust" rust "$cell_w"
  _rpt_add_tool runtimes "Go" go "$cell_w"
  _rpt_add_tool runtimes "Bun" bun "$cell_w"
  _rpt_add_tool runtimes "Deno" deno "$cell_w"
  [[ ${#runtimes[@]} -eq 0 ]] && runtimes+=("(nenhum)")

  local max_rows=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max_rows ]] && max_rows=${#runtimes[@]}

  _rpt_dual_header "$col_w" "FERRAMENTAS" "RUNTIMES"
  for (( i=0; i<max_rows; i++ )); do
    printf "%b│%b %b%-*s%b %b│%b %b%-*s%b %b│%b\n" \
      "$UI_BORDER" "$UI_RESET" \
      "$UI_GREEN" "$cell_w" "${tools[i]:-}" "$UI_RESET" \
      "$UI_BORDER" "$UI_RESET" \
      "$UI_MAUVE" "$cell_w" "${runtimes[i]:-}" "$UI_RESET" \
      "$UI_BORDER" "$UI_RESET"
  done

  # ── Próximos Passos + Comandos ──
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

  _rpt_dual_divider "$col_w" "PRÓXIMO PASSO" "COMANDOS ÚTEIS"
  for (( i=0; i<max_steps; i++ )); do
    printf "%b│%b %b%-*s%b %b│%b %b%-*s%b %b│%b\n" \
      "$UI_BORDER" "$UI_RESET" \
      "$UI_YELLOW" "$cell_w" "${next_steps[i]:-}" "$UI_RESET" \
      "$UI_BORDER" "$UI_RESET" \
      "$UI_MUTED" "$cell_w" "${commands[i]:-}" "$UI_RESET" \
      "$UI_BORDER" "$UI_RESET"
  done
  echo -e "${UI_BORDER}╰$(_rpt_hline "$col_w")┴$(_rpt_hline "$col_w")╯${UI_RESET}"

  # ── Footer: Backup + Links ──
  local backup_link="${BACKUP_DIR:-}"
  if [[ -n "$backup_link" ]] && [[ ! -d "$backup_link" ]]; then
    backup_link="(nenhum backup criado)"
  fi
  [[ -z "$backup_link" ]] && backup_link="(nenhum backup criado)"

  echo ""
  echo -e "${UI_BORDER}╭$(_rpt_hline "$inner_w")╮${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_ACCENT}${UI_BOLD}LINKS${UI_RESET}" "center"
  echo -e "${UI_BORDER}├$(_rpt_hline "$inner_w")┤${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_MUTED}Backup${UI_RESET}       ${UI_DIM}${backup_link}${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_MUTED}Site${UI_RESET}         ${UI_LINK}https://lucassr.dev${UI_RESET}"
  _rpt_box_line "$inner_w" "${UI_MUTED}Repositório${UI_RESET}  ${UI_LINK}https://github.com/lucassr-dev/.config${UI_RESET}"
  echo -e "${UI_BORDER}╰$(_rpt_hline "$inner_w")╯${UI_RESET}"
  echo ""
}
