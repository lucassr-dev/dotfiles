#!/usr/bin/env bash
# shellcheck disable=SC2034
# ═══════════════════════════════════════════════════════════
# Report — Dashboard pós-instalação (INSTALAÇÃO CONCLUÍDA)
# ═══════════════════════════════════════════════════════════
#
# Requer: lib/colors.sh, lib/utils.sh, lib/components.sh

get_version() {
  local cmd="$1"
  local probe_cmd="$cmd"
  case "$cmd" in
    python) probe_cmd="python3" ;;
    rust) probe_cmd="rustc" ;;
  esac
  command -v "$probe_cmd" >/dev/null 2>&1 || return 1
  case "$cmd" in
    git) git --version 2>/dev/null | awk '{print $3}' ;;
    zsh) zsh --version 2>/dev/null | awk '{print $2}' ;;
    fish) fish --version 2>/dev/null | awk '{print $3}' ;;
    tmux) tmux -V 2>/dev/null | awk '{print $2}' ;;
    nvim) nvim --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
    starship) starship --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
    mise) mise --version 2>/dev/null | head -n 1 | awk '{print $1}' ;;
    code) code --version 2>/dev/null | head -n 1 ;;
    docker) docker --version 2>/dev/null | sed -n 's/.*Docker version \([0-9.]*\).*/\1/p' ;;
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
    [[ $total_elapsed -lt 0 ]] && return 0
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

  local width=$((term_w > 100 ? 94 : term_w - 6))
  [[ $width -lt 50 ]] && width=50
  local left_pad=2
  local use_two_cols=0
  [[ $width -ge 74 ]] && use_two_cols=1
  local col_w=$(( (width - 6) / 2 ))
  local kv_label_w=13
  local rpt_divider_color="${UI_OVERLAY1:-$UI_BORDER}"
  local rpt_section_color="${UI_MAUVE:-$UI_ACCENT}"
  local rpt_label_color="${UI_LAVENDER:-$UI_ACCENT}"

  _rpt_div() {
    local title="$1"
    local title_vis fill fill_str
    title_vis=$(_visible_len "$title")
    fill=$(( width - title_vis - 4 ))
    [[ $fill -lt 0 ]] && fill=0
    printf -v fill_str '%*s' "$fill" ''
    printf "%*s%b\n" "$left_pad" "" "${rpt_divider_color}── ${rpt_section_color}${UI_BOLD}${title}${UI_RESET}${rpt_divider_color} ${fill_str// /─}${UI_RESET}"
  }

  _rpt_dual_div() {
    local left="$1" right="$2"
    local lv rv lf rf lfill rfill
    lv=$(_visible_len "$left"); rv=$(_visible_len "$right")
    lf=$(( col_w - lv - 1 )); rf=$(( col_w - rv - 1 ))
    [[ $lf -lt 0 ]] && lf=0; [[ $rf -lt 0 ]] && rf=0
    printf -v lfill '%*s' "$lf" ''; printf -v rfill '%*s' "$rf" ''
    printf "%*s%b\n" "$left_pad" "" "${rpt_divider_color}── ${rpt_section_color}${UI_BOLD}${left}${UI_RESET}${rpt_divider_color} ${lfill// /─}  ── ${rpt_section_color}${UI_BOLD}${right}${UI_RESET}${rpt_divider_color} ${rfill// /─}${UI_RESET}"
  }

  _rpt_hbar() {
    local bar
    printf -v bar '%*s' "$width" ''
    printf "%*s%b\n" "$left_pad" "" "${rpt_divider_color}${bar// /─}${UI_RESET}"
  }

  _rpt_kv() {
    local lbl_w="$1" label="$2" value="$3"
    local label_str="${label}:"
    local label_vis pad label_col
    label_vis=$(_visible_len "$label_str")
    pad=$(( lbl_w - label_vis ))
    [[ $pad -lt 0 ]] && pad=0
    printf -v label_col '%s%*s' "$label_str" "$pad" ''
    local value_w=$(( width - lbl_w - 4 ))
    [[ $value_w -lt 10 ]] && value_w=10
    local -a lines=()
    _wrap_text "$value" "$value_w" lines
    [[ ${#lines[@]} -eq 0 ]] && lines=("$value")
    printf "%*s  ${rpt_label_color}%s${UI_RESET}%b\n" "$left_pad" "" "$label_col" "${lines[0]}"
    local indent
    printf -v indent '%*s' "$((lbl_w + 2))" ''
    local i
    for (( i=1; i<${#lines[@]}; i++ )); do
      printf "%*s  %s%b\n" "$left_pad" "" "$indent" "${lines[i]}"
    done
  }

  _rpt_list_block() {
    local color="$1" empty_text="$2" arr_name="$3"
    local -n _items="$arr_name"
    if [[ ${#_items[@]} -eq 0 ]]; then
      printf "%*s  ${UI_DIM}%s${UI_RESET}\n" "$left_pad" "" "$empty_text"
      return
    fi
    local item
    for item in "${_items[@]}"; do
      printf "%*s  ${color}•${UI_RESET} ${UI_TEXT}%s${UI_RESET}\n" "$left_pad" "" "$item"
    done
  }

  _rpt_cell() {
    local color="$1" text="$2" cell_width="$3"
    local plain="• $text"
    local pad=$(( cell_width - $(_visible_len "$plain") ))
    [[ $pad -lt 0 ]] && pad=0
    printf "${color}•${UI_RESET} ${UI_TEXT}%s${UI_RESET}%*s" "$text" "$pad" ""
  }

  _rpt_dual_list_block() {
    local left_title="$1" left_color="$2" left_arr_name="$3" left_empty="$4"
    local right_title="$5" right_color="$6" right_arr_name="$7" right_empty="$8"
    local -n _left="$left_arr_name"
    local -n _right="$right_arr_name"

    if [[ $use_two_cols -ne 1 ]]; then
      _rpt_div "$left_title"
      _rpt_list_block "$left_color" "$left_empty" "$left_arr_name"
      echo ""
      _rpt_div "$right_title"
      _rpt_list_block "$right_color" "$right_empty" "$right_arr_name"
      return
    fi

    local -a left_items=("${_left[@]}")
    local -a right_items=("${_right[@]}")
    [[ ${#left_items[@]} -eq 0 ]] && left_items=("$left_empty")
    [[ ${#right_items[@]} -eq 0 ]] && right_items=("$right_empty")

    local max_rows=${#left_items[@]}
    [[ ${#right_items[@]} -gt $max_rows ]] && max_rows=${#right_items[@]}

    _rpt_dual_div "$left_title" "$right_title"
    local i
    for (( i=0; i<max_rows; i++ )); do
      printf "%*s  " "$left_pad" ""
      if [[ -n "${left_items[i]:-}" ]]; then
        _rpt_cell "$left_color" "${left_items[i]}" "$col_w"
      else
        printf "%*s" "$col_w" ""
      fi
      printf "  "
      if [[ -n "${right_items[i]:-}" ]]; then
        _rpt_cell "$right_color" "${right_items[i]}" "$col_w"
      else
        printf "%*s" "$col_w" ""
      fi
      echo ""
    done
  }

  clear_screen
  echo ""

  _rpt_hbar
  printf "%*s%b\n" "$left_pad" "" "  ${UI_GREEN}${UI_BOLD}INSTALAÇÃO CONCLUÍDA${UI_RESET}"
  printf "%*s%b\n" "$left_pad" "" "  ${UI_SUBTEXT1}Confira o status, o ambiente detectado e os próximos passos.${UI_RESET}"
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

  local so_color="$UI_TEAL"
  local so_name="Linux"
  if [[ "${TARGET_OS:-linux}" == "macos" ]]; then
    so_color="$UI_PEACH"
    so_name="macOS"
  elif [[ "${TARGET_OS:-linux}" == "windows" ]]; then
    so_color="$UI_BLUE"
    so_name="Windows"
  elif [[ "${TARGET_OS:-linux}" == "wsl2" ]]; then
    so_color="$UI_SKY"
    so_name="WSL2"
  fi

  _rpt_div "📌 STATUS GERAL"
  if [[ $total_errors -eq 0 ]]; then
    _rpt_kv "$kv_label_w" "Status" "${UI_GREEN}${UI_BOLD}Pronto para uso${UI_RESET}"
  else
    _rpt_kv "$kv_label_w" "Status" "${UI_RED}${UI_BOLD}Atenção necessária${UI_RESET} ${UI_SUBTEXT1}(${critical_count} crítica(s), ${optional_count} opcional(is))${UI_RESET}"
  fi
  _rpt_kv "$kv_label_w" "Instalados" "${UI_GREEN}${UI_BOLD}${total_installed}${UI_RESET}"
  _rpt_kv "$kv_label_w" "Configs" "${UI_BLUE}${UI_BOLD}${configs_count}${UI_RESET}"
  _rpt_kv "$kv_label_w" "Tempo total" "${UI_PEACH}${UI_BOLD}${elapsed:-N/A}${UI_RESET}"
  if [[ -n "${INSTALL_LOG:-}" ]]; then
    _rpt_kv "$kv_label_w" "Log" "$INSTALL_LOG"
  fi
  echo ""

  _rpt_div "💻 SISTEMA"
  _rpt_kv "$kv_label_w" "Host" "$hostname"
  _rpt_kv "$kv_label_w" "Usuário" "$username"
  _rpt_kv "$kv_label_w" "Sistema" "${so_color}${so_name}${UI_RESET}"
  _rpt_kv "$kv_label_w" "Shell" "${UI_GREEN}${current_shell}${UI_RESET}"
  [[ "$host_ip" != "N/A" ]] && _rpt_kv "$kv_label_w" "IP" "$host_ip"
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

  local runtimes=()
  _rpt_add_tool runtimes "Node" node "$col_w"
  _rpt_add_tool runtimes "Python" python "$col_w"
  _rpt_add_tool runtimes "PHP" php "$col_w"
  _rpt_add_tool runtimes "Rust" rust "$col_w"
  _rpt_add_tool runtimes "Go" go "$col_w"
  _rpt_add_tool runtimes "Bun" bun "$col_w"
  _rpt_add_tool runtimes "Deno" deno "$col_w"
  _rpt_dual_list_block "🔧 FERRAMENTAS" "$UI_GREEN" "tools" "(nenhuma)" "⚡ RUNTIMES" "$UI_PEACH" "runtimes" "(nenhum)"
  echo ""

  if [[ $total_errors -gt 0 ]]; then
    _rpt_div "⚠ ATENÇÃO"
    printf "%*s  ${UI_RED}${UI_BOLD}%s${UI_RESET} ${UI_SUBTEXT1}falha(s) detectada(s). O resumo detalhado aparece logo após este dashboard.${UI_RESET}\n" "$left_pad" "" "$total_errors"
    printf "%*s  ${rpt_label_color}Críticas:${UI_RESET} ${UI_TEXT}%s${UI_RESET}   ${rpt_label_color}Opcionais:${UI_RESET} ${UI_TEXT}%s${UI_RESET}\n" "$left_pad" "" "$critical_count" "$optional_count"
    echo ""
  fi

  local next_steps=()
  next_steps+=("Abra um novo terminal")
  [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]] && next_steps+=("Execute p10k configure")
  [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]] && next_steps+=("Selecione ${SELECTED_NERD_FONTS[0]}")
  [[ $total_errors -gt 0 ]] && next_steps+=("Revise as falhas")

  local commands=()
  commands+=("bash install.sh export")
  commands+=("bash install.sh sync")
  has_cmd lazygit && commands+=("lazygit")
  has_cmd zoxide && commands+=("z <dir>")
  has_cmd mise && commands+=("mise ls / mise use")
  has_cmd bat && commands+=("bat <file>")

  _rpt_dual_list_block "▶ PRÓXIMOS PASSOS" "$UI_YELLOW" "next_steps" "(nenhum)" "💡 COMANDOS ÚTEIS" "$UI_LINK" "commands" "(nenhum)"
  echo ""

  local backup_link="${BACKUP_DIR:-}"
  if [[ -n "$backup_link" ]] && [[ ! -d "$backup_link" ]]; then
    backup_link="(nenhum backup criado)"
  fi
  [[ -z "$backup_link" ]] && backup_link="(nenhum backup criado)"

  _rpt_div "🔗 LINKS E CAMINHOS"
  _rpt_kv "$kv_label_w" "Backup" "$backup_link"
  _rpt_kv "$kv_label_w" "Site" "https://lucassr.dev"
  _rpt_kv "$kv_label_w" "Repositório" "https://github.com/lucassr-dev/.config"
  echo ""
  _rpt_hbar
  echo ""
}
