#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329

# ═══════════════════════════════════════════════════════════
# CONFIGURAÇÃO E DETECÇÃO
# ═══════════════════════════════════════════════════════════

# Cores carregadas de lib/colors.sh (paleta Catppuccin Mocha completa)
# Legacy alias para compatibilidade
declare -g UI_MAGENTA="${UI_MAUVE:-$'\033[38;2;203;166;247m'}"

declare -g UI_CHECK="✓"
declare -g UI_UNCHECK="·"
declare -g UI_ARROW="›"
declare -g UI_BOX_H="─"
declare -g UI_BOX_V="│"
declare -g UI_BOX_TL="╭"
declare -g UI_BOX_TR="╮"
declare -g UI_BOX_BL="╰"
declare -g UI_BOX_BR="╯"

HAS_COLOR=1
HAS_UNICODE=1
IS_TTY=1
IS_CI=0

detect_terminal_capabilities() {
  IS_TTY=0
  [[ -t 1 ]] && IS_TTY=1

  IS_CI=0
  if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]] || [[ -n "${JENKINS_URL:-}" ]] || [[ -n "${TRAVIS:-}" ]]; then
    IS_CI=1
  fi

  HAS_COLOR=1
  if [[ -n "${NO_COLOR:-}" ]]; then
    HAS_COLOR=0
  elif [[ "$IS_TTY" -eq 0 ]]; then
    HAS_COLOR=0
  elif [[ "${TERM:-}" == "dumb" ]]; then
    HAS_COLOR=0
  else
    local num_colors=0
    num_colors=$(tput colors 2>/dev/null || echo 0)
    [[ "$num_colors" -lt 8 ]] && HAS_COLOR=0
  fi

  HAS_UNICODE=1
  local lang_val="${LANG:-}${LC_ALL:-}${LC_CTYPE:-}"
  case "$lang_val" in
    *UTF-8*|*utf-8*|*utf8*|*UTF8*) ;;
    *)
      if [[ "${TERM:-}" == "dumb" ]] || [[ "${TERM:-}" == "linux" ]]; then
        HAS_UNICODE=0
      fi
      ;;
  esac

  if [[ "$HAS_COLOR" -eq 0 ]]; then
    # colors.sh already handles NO_COLOR, but also handle terminal detection
    _setup_color_mode 2>/dev/null || true
    UI_MAGENTA=""
  fi

  if [[ "$HAS_UNICODE" -eq 0 ]]; then
    UI_CHECK="+"
    UI_UNCHECK="-"
    UI_ARROW=">"
    UI_BOX_H="-"
    UI_BOX_V="|"
    UI_BOX_TL="+"
    UI_BOX_TR="+"
    UI_BOX_BL="+"
    UI_BOX_BR="+"
    SPINNER_FRAMES=("-" "\\" "|" "/")
  fi
}

detect_ui_mode() {
  [[ -n "${UI_MODE:-}" ]] && return 0

  if [[ -n "${FORCE_UI_MODE:-}" ]]; then
    UI_MODE="$FORCE_UI_MODE"
    return
  fi

  if has_cmd fzf; then
    UI_MODE="fzf"
  elif has_cmd gum; then
    UI_MODE="gum"
  else
    UI_MODE="bash"
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP COUNTER (ETAPAS DE INSTALAÇÃO)
# ═══════════════════════════════════════════════════════════

INSTALL_STEP=0
INSTALL_TOTAL_STEPS=0
INSTALL_START_TIME=0
STEP_BEGIN_TIME=0

_format_elapsed() {
  local elapsed="$1"
  local mins=$((elapsed / 60))
  local secs=$((elapsed % 60))
  if [[ $mins -gt 0 ]]; then
    printf '%dm %ds' "$mins" "$secs"
  else
    printf '%ds' "$secs"
  fi
}

step_init() {
  local total="$1"
  INSTALL_TOTAL_STEPS=$total
  INSTALL_STEP=0
  INSTALL_START_TIME=$SECONDS
}

step_begin() {
  local label="$1"
  local detail="${2:-}"
  ((INSTALL_STEP++))
  STEP_BEGIN_TIME=$SECONDS

  local box_w
  box_w=$(ui_width "$UI_WIDTH_MAX_BOX")

  local pct=$((INSTALL_STEP * 100 / INSTALL_TOTAL_STEPS))
  local pct_str="${pct}%"

  # step_counter [3/12] e o numero que se escaneia (bold+peach); label e o
  # cabecalho da secao (bold+mauve). header (sem cor) so serve pra medir
  # largura visivel do preenchimento -- igual ao valor colorido, mesmos bytes.
  local step_counter="[${INSTALL_STEP}/${INSTALL_TOTAL_STEPS}]"
  local header="${step_counter} ${label}"
  local header_len=${#header}
  local pct_len=${#pct_str}

  # 8 = os caracteres fixos da linha que nao sao texto nem preenchimento:
  # ╭ ─ e os cinco espacos separadores, mais ─ ╮ no fim. Com 6 o topo saia
  # duas colunas mais largo que a base, em toda largura de terminal.
  #
  # Travar o preenchimento em 1 nao segura a linha: se o rotulo nao couber,
  # ele proprio precisa encolher. Sem isto um terminal de 40 colunas recebia
  # um topo de 41 e a moldura quebrava logo na primeira etapa.
  local max_header=$((box_w - pct_len - 9))
  (( max_header < 8 )) && max_header=8
  if (( header_len > max_header )); then
    local max_label=$((max_header - ${#step_counter} - 1))
    if (( max_label < 2 )); then
      label=""
    else
      label="${label:0:$((max_label - 1))}…"
    fi
    header="${step_counter} ${label}"
    header_len=${#header}
  fi

  local fill=$((box_w - header_len - pct_len - 8))
  [[ $fill -lt 1 ]] && fill=1
  local h_fill=""
  for ((i=0; i<fill; i++)); do h_fill+="$UI_BOX_H"; done

  msg ""
  msg "${UI_CYAN}${UI_BOX_TL}${UI_BOX_H} ${UI_PEACH}${UI_BOLD}${step_counter}${UI_RESET} ${UI_MAUVE}${UI_BOLD}${label}${UI_RESET} ${UI_CYAN}${h_fill} ${UI_DIM}${pct_str}${UI_RESET} ${UI_CYAN}${UI_BOX_H}${UI_BOX_TR}${UI_RESET}"
  if [[ -n "$detail" ]]; then
    # A moldura tem que fechar tambem aqui. Sem o "│" da direita a caixa fica
    # aberta no meio, e era a unica linha do bloco de progresso que nao
    # fechava — o que dava a impressao de desenho quebrado logo na primeira
    # etapa da instalacao.
    local detail_vis pad_detail
    detail_vis=$(_visible_len "$detail")
    pad_detail=$((box_w - detail_vis - 4))
    (( pad_detail < 0 )) && pad_detail=0
    msg "$(printf '%b%s%b  %b%s%b%*s%b%s%b' \
      "$UI_CYAN" "$UI_BOX_V" "$UI_RESET" \
      "$UI_OVERLAY1" "$detail" "$UI_RESET" \
      "$pad_detail" '' \
      "$UI_CYAN" "$UI_BOX_V" "$UI_RESET")"
  fi
}

step_end() {
  local status="${1:-success}"
  local box_w
  box_w=$(ui_width "$UI_WIDTH_MAX_BOX")

  local status_text status_vis
  case "$status" in
    success) status_text="${UI_GREEN}${UI_CHECK} Concluido${UI_RESET}"; status_vis=11 ;;
    warning) status_text="${UI_YELLOW}⚠ Com avisos${UI_RESET}"; status_vis=12 ;;
    error)   status_text="${UI_RED}✗ Com erros${UI_RESET}"; status_vis=11 ;;
  esac

  local time_str="" time_vis=0
  if [[ "${STEP_BEGIN_TIME:-0}" -gt 0 ]]; then
    local step_elapsed=$((SECONDS - STEP_BEGIN_TIME))
    if [[ $step_elapsed -gt 0 ]]; then
      time_str="$(_format_elapsed "$step_elapsed")"
      time_vis=$((${#time_str} + 4))
    fi
  fi

  # Os dois ramos abaixo tem contagem de caracteres fixos diferente, e so o
  # ramo sem tempo estava certo. Como o tempo so aparece quando a etapa leva
  # mais de um segundo, o ramo errado passava despercebido em teste rapido.
  local fixos=5
  [[ -n "$time_str" ]] && fixos=4

  # Terminal estreito: o tempo decorrido e o primeiro a sair. Sem isso a base
  # estouraria a largura para caber um dado acessorio.
  if [[ -n "$time_str" ]] && (( box_w - status_vis - time_vis - fixos < 1 )); then
    time_str=""
    time_vis=0
    fixos=5
  fi

  local fill_len=$((box_w - status_vis - time_vis - fixos))
  [[ $fill_len -lt 1 ]] && fill_len=1
  local h_fill=""
  for ((i=0; i<fill_len; i++)); do h_fill+="$UI_BOX_H"; done

  if [[ -n "$time_str" ]]; then
    msg "${UI_CYAN}${UI_BOX_BL}${UI_BOX_H} ${status_text} ${UI_CYAN}${h_fill} ${UI_PEACH}${UI_BOLD}${time_str}${UI_RESET} ${UI_CYAN}${UI_BOX_H}${UI_BOX_BR}${UI_RESET}"
  else
    msg "${UI_CYAN}${UI_BOX_BL}${UI_BOX_H} ${status_text} ${UI_CYAN}${h_fill}${UI_BOX_BR}${UI_RESET}"
  fi
}

# ═══════════════════════════════════════════════════════════
# SELEÇÃO MÚLTIPLA - FZF
# ═══════════════════════════════════════════════════════════

ui_select_multi_fzf() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local num_items=${#options[@]}
  local height=$((num_items + 6))
  [[ $height -lt 10 ]] && height=10
  [[ $height -gt 22 ]] && height=22

  local header
  header=$(printf '%s\n%s' "📦 $title" "Tab: selecionar │ Ctrl+A: todos │ ESC: nenhum │ Enter: confirmar")

  local selected
  selected=$(printf '%s\n' "${options[@]}" | fzf \
    --multi \
    --ansi \
    --reverse \
    --height="$height" \
    --border=rounded \
    --header="$header" \
    --prompt="Buscar: " \
    --pointer="▶" \
    --marker="✓" \
    --no-mouse \
    --bind='ctrl-a:toggle-all' \
    --bind='tab:toggle+down' \
    --bind='shift-tab:toggle+up' \
    --preview-window=hidden \
    --color='header:cyan,pointer:green,marker:green,prompt:yellow' \
  ) || true

  local -a result=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && result+=("$(echo "$line" | awk '{print $1}')")
  done <<< "$selected"

  # shellcheck disable=SC2178
  # shellcheck disable=SC2178
  # shellcheck disable=SC2178
  declare -n ref="$out_var"
  ref=("${result[@]}")
  unset -n ref
}

# ═══════════════════════════════════════════════════════════
# SELEÇÃO MÚLTIPLA - GUM
# ═══════════════════════════════════════════════════════════

ui_select_multi_gum() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local selected
  selected=$(gum choose \
    --no-limit \
    --header="$title" \
    --cursor.foreground="cyan" \
    --selected.foreground="green" \
    "${options[@]}" \
  ) || true

  local -a result=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && result+=("$(echo "$line" | awk '{print $1}')")
  done <<< "$selected"

  # shellcheck disable=SC2178
  declare -n ref="$out_var"
  ref=("${result[@]}")
  unset -n ref
}

# ═══════════════════════════════════════════════════════════
# SELEÇÃO MÚLTIPLA - BASH PURO (com checkboxes visuais)
# ═══════════════════════════════════════════════════════════

ui_select_multi_bash() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local total=${#options[@]}
  local -a selected_indices=()
  local input=""
  local sel_count=0

  _is_selected() {
    local needle="$1"
    local s
    for s in "${selected_indices[@]}"; do
      [[ $s -eq $needle ]] && return 0
    done
    return 1
  }

  _toggle_index() {
    local idx="$1"
    if _is_selected "$idx"; then
      local -a tmp=()
      local s
      for s in "${selected_indices[@]}"; do
        [[ $s -ne $idx ]] && tmp+=("$s")
      done
      selected_indices=("${tmp[@]}")
    else
      selected_indices+=("$idx")
    fi
  }

  while true; do
    printf '\033[H\033[2J'
    sel_count=${#selected_indices[@]}

    echo ""
    echo -e "  ${UI_MAUVE}${UI_BOLD}${title}${UI_RESET}"
    echo -e "  ${UI_PEACH}${UI_BOLD}${sel_count}${UI_RESET}${UI_OVERLAY1}/${total} selecionados${UI_RESET}"
    echo ""

    # Uma coluna so, com quebra na largura real do terminal. O grid de 2
    # colunas que existia aqui usava col_width=38 fixo, sem olhar pra
    # tput cols -- uma lista de 32 ferramentas (CLI_TOOLS) virava uma linha
    # de ate 147 colunas em QUALQUER largura de terminal. "nome - descricao"
    # e longo demais pra caber em 2 colunas de forma segura; alinha e
    # quebra, como o resto do app faz (msg_wrap, _rv_lv), em vez de escorrer.
    local term_w
    term_w=$(ui_term_cols)
    local idx_w=2
    [[ $total -ge 100 ]] && idx_w=3
    local prefix_w=$((idx_w + 7))
    local content_w=$((term_w - prefix_w - 1))
    [[ $content_w -lt 20 ]] && content_w=20
    local cont_indent
    printf -v cont_indent '%*s' "$prefix_w" ''

    for (( i=0; i<total; i++ )); do
      local idx=$((i + 1))
      local item="${options[i]}"
      local check="$UI_UNCHECK"
      local color="$UI_OVERLAY1"
      if _is_selected "$i"; then
        check="${UI_GREEN}${UI_CHECK}${UI_RESET}"
        color="$UI_TEXT"
      fi
      local -a item_lines=()
      _wrap_text "$item" "$content_w" item_lines
      [[ ${#item_lines[@]} -eq 0 ]] && item_lines=("$item")
      printf "  ${UI_OVERLAY1}%${idx_w}d${UI_RESET} [%b] ${color}%s${UI_RESET}\n" "$idx" "$check" "${item_lines[0]}"
      local li
      for (( li=1; li<${#item_lines[@]}; li++ )); do
        printf "%s${color}%s${UI_RESET}\n" "$cont_indent" "${item_lines[li]}"
      done
    done

    echo ""
    echo -e "  ${UI_TEXT}Num${UI_RESET} ${UI_OVERLAY1}toggle${UI_RESET}  ${UI_TEXT}a${UI_RESET} ${UI_OVERLAY1}todos${UI_RESET}  ${UI_TEXT}n${UI_RESET} ${UI_OVERLAY1}nenhum${UI_RESET}  ${UI_GREEN}${UI_BOLD}Enter${UI_RESET} ${UI_OVERLAY1}confirmar${UI_RESET}"
    echo ""
    read -r -p "  → " input

    case "$input" in
      "")
        break
        ;;
      a|A|all|todos|t|T|\*)
        selected_indices=()
        for ((i=0; i<total; i++)); do
          selected_indices+=("$i")
        done
        ;;
      n|N|none|nenhum)
        selected_indices=()
        ;;
      *)
        IFS=',' read -r -a nums <<< "$input"
        local valid=1
        for n in "${nums[@]}"; do
          n="${n//[[:space:]]/}"
          [[ -z "$n" ]] && continue
          if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 )) && (( n <= total )); then
            _toggle_index "$((n - 1))"
          else
            valid=0
          fi
        done
        if [[ $valid -eq 0 ]]; then
          echo -e "  ${UI_YELLOW}⚠ Use números de 1-$total${UI_RESET}"
          sleep 0.8
        fi
        ;;
    esac
  done

  local -a result=()
  for idx in "${selected_indices[@]}"; do
    local item="${options[idx]}"
    result+=("$(echo "$item" | awk '{print $1}')")
  done

  # shellcheck disable=SC2178
  declare -n ref="$out_var"
  ref=("${result[@]}")
  unset -n ref
}

# ═══════════════════════════════════════════════════════════
# SELEÇÃO ÚNICA
# ═══════════════════════════════════════════════════════════

ui_select_single_fzf() {
  local title="$1"
  local _out_var="$2"
  shift 2
  local options=("$@")

  local num_items=${#options[@]}
  local height=$((num_items + 5))
  [[ $height -lt 9 ]] && height=9
  [[ $height -gt 17 ]] && height=17

  local header
  header=$(printf '%s\n%s' "$title" "↑↓: navegar │ ESC: cancelar │ Enter: confirmar")

  local _fzf_selected
  _fzf_selected=$(printf '%s\n' "${options[@]}" | fzf \
    --ansi \
    --reverse \
    --height="$height" \
    --border=rounded \
    --header="$header" \
    --prompt="Buscar: " \
    --pointer="▶" \
    --no-mouse \
    --color='header:cyan,pointer:green,prompt:yellow' \
  ) || true

  local _fzf_result=""
  [[ -n "$_fzf_selected" ]] && _fzf_result=$(echo "$_fzf_selected" | awk '{print $1}')

  printf -v "$_out_var" '%s' "$_fzf_result"
}

ui_select_single_gum() {
  local title="$1"
  local _out_var="$2"
  shift 2
  local options=("$@")

  local _gum_selected
  _gum_selected=$(gum choose \
    --header="$title" \
    --cursor.foreground="cyan" \
    "${options[@]}" \
  ) || true

  local _gum_result=""
  [[ -n "$_gum_selected" ]] && _gum_result=$(echo "$_gum_selected" | awk '{print $1}')

  printf -v "$_out_var" '%s' "$_gum_result"
}

ui_select_single_bash() {
  local title="$1"
  local _out_var="$2"
  shift 2
  local options=("$@")

  local total=${#options[@]}
  local _bash_selection=""

  while true; do
    echo ""
    echo -e "  ${UI_MAUVE}${UI_BOLD}${title}${UI_RESET}"
    echo ""

    local idx=1
    for opt in "${options[@]}"; do
      echo -e "  ${UI_PEACH}${UI_BOLD}${idx}${UI_RESET}${UI_OVERLAY1})${UI_RESET} ${UI_TEXT}$opt${UI_RESET}"
      idx=$((idx + 1))
    done

    echo ""
    if ! read -r -p "  Escolha (1-$total): " _bash_selection; then
      # stdin fechado (não-interativo) -- sem isso, EOF vira loop infinito (não
      # bloqueante, `read`/`/dev/null` retorna na hora): usa a 1a opção como default.
      warn "Entrada não interativa detectada. Usando opção 1 como padrão."
      _bash_selection=1
    fi

    if [[ "$_bash_selection" =~ ^[0-9]+$ ]] && (( _bash_selection >= 1 )) && (( _bash_selection <= total )); then
      local _bash_selected_item="${options[_bash_selection-1]}"
      local _bash_result
      _bash_result=$(echo "$_bash_selected_item" | awk '{print $1}')
      printf -v "$_out_var" '%s' "$_bash_result"
      return 0
    fi

    echo -e "  ${UI_YELLOW}⚠ Opção inválida${UI_RESET}"
    sleep 0.5
  done
}

# ═══════════════════════════════════════════════════════════
# CONFIRMAÇÃO (Y/N)
# ═══════════════════════════════════════════════════════════

ui_confirm() {
  local question="$1"
  local default="${2:-y}"

  local prompt
  if [[ "$default" == "y" ]]; then
    prompt="[${UI_GREEN}S${UI_RESET}/n]"
  else
    prompt="[s/${UI_GREEN}N${UI_RESET}]"
  fi

  if has_cmd gum && [[ "$UI_MODE" == "gum" ]]; then
    gum confirm "$question" && return 0 || return 1
  fi

  local answer
  printf "  %s %b " "$question" "$prompt"
  read -r answer
  answer="${answer:-$default}"

  case "$answer" in
    [SsYy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# API PRINCIPAL - Detecta modo automaticamente
# ═══════════════════════════════════════════════════════════

ui_select_multiple() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  detect_ui_mode

  case "$UI_MODE" in
    fzf) ui_select_multi_fzf "$title" "$out_var" "${options[@]}" ;;
    gum) ui_select_multi_gum "$title" "$out_var" "${options[@]}" ;;
    *)   ui_select_multi_bash "$title" "$out_var" "${options[@]}" ;;
  esac
}

ui_select_single() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  detect_ui_mode

  case "$UI_MODE" in
    fzf) ui_select_single_fzf "$title" "$out_var" "${options[@]}" ;;
    gum) ui_select_single_gum "$title" "$out_var" "${options[@]}" ;;
    *)   ui_select_single_bash "$title" "$out_var" "${options[@]}" ;;
  esac
}
