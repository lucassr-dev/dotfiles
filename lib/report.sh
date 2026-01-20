#!/usr/bin/env bash
# Relatório pós-instalação - Layout moderno com rounded corners
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
    docker) docker --version 2>&1 | awk '{print $3}' | tr -d ',' ;;
    node) node --version 2>/dev/null | tr -d 'v' ;;
    python) python3 --version 2>/dev/null | awk '{print $2}' ;;
    php) php --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
    rust) rustc --version 2>/dev/null | awk '{print $2}' ;;
    go) go version 2>/dev/null | awk '{print $3}' | sed 's/go//' ;;
    bun) bun --version 2>/dev/null ;;
    deno) deno --version 2>/dev/null | head -n 1 | awk '{print $2}' ;;
  esac
}

_draw_line() {
  local width="$1"
  local left="$2"
  local right="$3"
  local fill="${4:-─}"
  local line=""
  for ((i=0; i<width-2; i++)); do line+="$fill"; done
  echo -e "${left}${line}${right}"
}

_truncate_text() {
  local max="$1"
  local text="$2"
  if [[ ${#text} -le $max ]]; then
    printf '%s' "$text"
    return
  fi
  if [[ $max -le 3 ]]; then
    printf '%s' "${text:0:$max}"
    return
  fi
  printf '%s' "${text:0:$((max - 3))}..."
}

_fmt_tool() {
  local icon="$1"
  local name="$2"
  local version="$3"
  local max_w="${4:-18}"
  local text="$icon $name"
  [[ -n "$version" ]] && text+=" $version"
  _truncate_text "$max_w" "$text"
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
  local WHITE='\033[1;37m'
  local DIM='\033[2m'
  local NC='\033[0m'

  # Largura responsiva (max 80)
  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local w=$((term_w > 80 ? 80 : term_w - 2))
  [[ $w -lt 50 ]] && w=50

  [[ -t 1 ]] && clear

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # HEADER - Sucesso
  # ═══════════════════════════════════════════════════════════════════════════
  echo -e "${GREEN}$(_draw_line $w "╭" "╮")${NC}"
  local title="✨ INSTALAÇÃO CONCLUÍDA! ✨"
  local pad=$(( (w - 2 - ${#title}) / 2 ))
  printf "${GREEN}│${NC}%${pad}s${YELLOW}%s${NC}%$((w - 2 - pad - ${#title}))s${GREEN}│${NC}\n" "" "$title" ""
  echo -e "${GREEN}$(_draw_line $w "╰" "╯")${NC}"
  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # INFO DO AMBIENTE
  # ═══════════════════════════════════════════════════════════════════════════
  local info_inner_w=$((w - 4))
  local info_lines=()
  info_lines+=("👤 Usuario: ${username}")
  info_lines+=("🖥️  Host: ${hostname}")
  info_lines+=("🐧 SO: ${TARGET_OS:-linux}")
  if [[ -d "$BACKUP_DIR" ]]; then
    info_lines+=("📦 Backup: ${BACKUP_DIR}")
  fi

  echo -e "${DIM}$(_draw_line $w "╭" "╮")${NC}"
  for line in "${info_lines[@]}"; do
    local text
    text=$(_truncate_text "$info_inner_w" "$line")
    printf "${DIM}│${NC} %-*s ${DIM}│${NC}\n" "$info_inner_w" "$text"
  done
  echo -e "${DIM}$(_draw_line $w "╰" "╯")${NC}"
  echo ""

  local col_total=$((w - 7))
  local col_w_left=$((col_total * 6 / 10))
  local col_w_right=$((col_total - col_w_left))
  local left_line right_line
  left_line=$(printf '─%.0s' $(seq 1 $((col_w_left + 2))))
  right_line=$(printf '─%.0s' $(seq 1 $((col_w_right + 2))))

  # ═══════════════════════════════════════════════════════════════════════════
  # FERRAMENTAS | RUNTIMES
  # ═══════════════════════════════════════════════════════════════════════════
  local tools=()
  has_cmd git && tools+=("$(_fmt_tool "📚" "Git" "$(get_version git)" $col_w_left)")
  has_cmd zsh && tools+=("$(_fmt_tool "🐚" "Zsh" "$(get_version zsh)" $col_w_left)")
  has_cmd fish && tools+=("$(_fmt_tool "🐟" "Fish" "$(get_version fish)" $col_w_left)")
  has_cmd tmux && tools+=("$(_fmt_tool "📺" "Tmux" "$(get_version tmux)" $col_w_left)")
  has_cmd nvim && tools+=("$(_fmt_tool "📝" "Neovim" "$(get_version nvim)" $col_w_left)")
  has_cmd starship && tools+=("$(_fmt_tool "🚀" "Starship" "$(get_version starship)" $col_w_left)")
  has_cmd code && tools+=("$(_fmt_tool "💻" "VS Code" "$(get_version code)" $col_w_left)")
  has_cmd docker && tools+=("$(_fmt_tool "🐳" "Docker" "$(get_version docker)" $col_w_left)")
  has_cmd mise && tools+=("$(_fmt_tool "📦" "Mise" "$(get_version mise)" $col_w_left)")
  has_cmd lazygit && tools+=("$(_fmt_tool "🔀" "Lazygit" "" $col_w_left)")
  [[ ${#tools[@]} -eq 0 ]] && tools+=("$(_truncate_text "$col_w_left" "(nenhuma)")")

  local runtimes=()
  has_cmd node && runtimes+=("$(_fmt_tool "🟢" "Node" "$(get_version node)" $col_w_right)")
  has_cmd python3 && runtimes+=("$(_fmt_tool "🐍" "Python" "$(get_version python)" $col_w_right)")
  has_cmd php && runtimes+=("$(_fmt_tool "🐘" "PHP" "$(get_version php)" $col_w_right)")
  has_cmd rustc && runtimes+=("$(_fmt_tool "🦀" "Rust" "$(get_version rust)" $col_w_right)")
  has_cmd go && runtimes+=("$(_fmt_tool "🔷" "Go" "$(get_version go)" $col_w_right)")
  has_cmd bun && runtimes+=("$(_fmt_tool "🧅" "Bun" "$(get_version bun)" $col_w_right)")
  has_cmd deno && runtimes+=("$(_fmt_tool "🦕" "Deno" "$(get_version deno)" $col_w_right)")
  [[ ${#runtimes[@]} -eq 0 ]] && runtimes+=("$(_truncate_text "$col_w_right" "(nenhum)")")

  echo -e "${CYAN}╭${left_line}┬${right_line}╮${NC}"
  local tools_title="🛠️ FERRAMENTAS"
  local rt_title="🚀 RUNTIMES"
  local tools_pad=$((col_w_left - ${#tools_title}))
  local rt_pad=$((col_w_right - ${#rt_title}))
  [[ $tools_pad -lt 0 ]] && tools_pad=0
  [[ $rt_pad -lt 0 ]] && rt_pad=0
  printf "${CYAN}│${NC} ${WHITE}%s${NC}%*s ${CYAN}│${NC} ${WHITE}%s${NC}%*s ${CYAN}│${NC}\n" "$tools_title" "$tools_pad" "" "$rt_title" "$rt_pad" ""
  echo -e "${CYAN}├${left_line}┼${right_line}┤${NC}"

  local max=${#tools[@]}
  [[ ${#runtimes[@]} -gt $max ]] && max=${#runtimes[@]}
  for (( i=0; i<max; i++ )); do
    local left="${tools[i]:-}"
    local right="${runtimes[i]:-}"
    printf "${CYAN}│${NC} %-${col_w_left}s ${CYAN}│${NC} %-${col_w_right}s ${CYAN}│${NC}\n" "$left" "$right"
  done

  echo -e "${CYAN}╰${left_line}┴${right_line}╯${NC}"

  # ═══════════════════════════════════════════════════════════════════════════
  # PRÓXIMO PASSO | COMANDOS ÚTEIS
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""
  local next_steps=()
  next_steps+=("$(_truncate_text "$col_w_left" "Reinicie: exec \$SHELL")")
  if [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]]; then
    next_steps+=("$(_truncate_text "$col_w_left" "Tema: p10k configure")")
  fi
  if [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]]; then
    local font="${SELECTED_NERD_FONTS[0]}"
    next_steps+=("$(_truncate_text "$col_w_left" "Fonte: ${font}")")
  fi
  [[ ${#next_steps[@]} -eq 0 ]] && next_steps+=("$(_truncate_text "$col_w_left" "(nenhum)")")

  local commands=()
  commands+=("$(_truncate_text "$col_w_right" "bash install.sh export - salvar")")
  commands+=("$(_truncate_text "$col_w_right" "bash install.sh sync - atualizar")")
  has_cmd lazygit && commands+=("$(_truncate_text "$col_w_right" "lazygit - TUI Git")")
  has_cmd zoxide && commands+=("$(_truncate_text "$col_w_right" "z <pasta> - navegar")")
  [[ ${#commands[@]} -eq 0 ]] && commands+=("$(_truncate_text "$col_w_right" "(nenhum)")")

  echo -e "${GREEN}╭${left_line}┬${right_line}╮${NC}"
  local next_title="⚡ PRÓXIMO PASSO"
  local cmd_title="💡 COMANDOS UTEIS"
  local next_pad=$((col_w_left - ${#next_title}))
  local cmd_pad=$((col_w_right - ${#cmd_title}))
  [[ $next_pad -lt 0 ]] && next_pad=0
  [[ $cmd_pad -lt 0 ]] && cmd_pad=0
  printf "${GREEN}│${NC} ${WHITE}%s${NC}%*s ${GREEN}│${NC} ${DIM}%s${NC}%*s ${GREEN}│${NC}\n" "$next_title" "$next_pad" "" "$cmd_title" "$cmd_pad" ""
  echo -e "${GREEN}├${left_line}┼${right_line}┤${NC}"

  local steps_max=${#next_steps[@]}
  [[ ${#commands[@]} -gt $steps_max ]] && steps_max=${#commands[@]}
  for (( i=0; i<steps_max; i++ )); do
    local left="${next_steps[i]:-}"
    local right="${commands[i]:-}"
    printf "${GREEN}│${NC} ${WHITE}%-${col_w_left}s${NC} ${GREEN}│${NC} ${DIM}%-${col_w_right}s${NC} ${GREEN}│${NC}\n" "$left" "$right"
  done

  echo -e "${GREEN}╰${left_line}┴${right_line}╯${NC}"

  # ═══════════════════════════════════════════════════════════════════════════
  # MISE (compacto - 5 comandos essenciais)
  # ═══════════════════════════════════════════════════════════════════════════
  if has_cmd mise; then
    echo ""
    echo -e "${DIM}╭─ 📦 Mise (gerenciador de runtimes) ─────────────────────────╮${NC}"
    echo -e "${DIM}│${NC}  ${WHITE}mise ls${NC}               ${DIM}→${NC} Listar runtimes instalados        ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${WHITE}mise use -g node@22${NC}   ${DIM}→${NC} Instalar Node 22 global           ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${WHITE}mise use python@3.12${NC}  ${DIM}→${NC} Python 3.12 no projeto atual      ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${WHITE}mise install${NC}          ${DIM}→${NC} Instalar versões do .mise.toml    ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${WHITE}mise --help${NC}           ${DIM}→${NC} Ver todos os comandos             ${DIM}│${NC}"
    echo -e "${DIM}╰──────────────────────────────────────────────────────────────╯${NC}"
  fi

  # ═══════════════════════════════════════════════════════════════════════════
  # FOOTER
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""
  echo -e "  ${BLUE}🌐${NC} ${DIM}lucassr.dev${NC}   ${GREEN}📦${NC} ${DIM}github.com/lucassr-dev/.config${NC}"
  echo ""
}
