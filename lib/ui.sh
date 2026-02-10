#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329

# ═══════════════════════════════════════════════════════════
# CONFIGURAÇÃO E DETECÇÃO
# ═══════════════════════════════════════════════════════════

declare -g UI_CYAN='\033[0;36m'
declare -g UI_GREEN='\033[0;32m'
declare -g UI_YELLOW='\033[1;33m'
declare -g UI_RED='\033[0;31m'
declare -g UI_BLUE='\033[0;34m'
declare -g UI_MAGENTA='\033[0;35m'
declare -g UI_WHITE='\033[1;37m'
declare -g UI_BOLD='\033[1m'
declare -g UI_DIM='\033[2m'
declare -g UI_RESET='\033[0m'

declare -g UI_CHECK="✓"
declare -g UI_UNCHECK="○"
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
    UI_CYAN=""
    UI_GREEN=""
    UI_YELLOW=""
    UI_RED=""
    UI_BLUE=""
    UI_MAGENTA=""
    UI_WHITE=""
    UI_BOLD=""
    UI_DIM=""
    UI_RESET=""
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
# SPINNERS E PROGRESSO
# ═══════════════════════════════════════════════════════════

declare -a SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
declare -g SPINNER_PID=""

start_spinner() {
  local message="${1:-Aguarde...}"

  [[ -n "$SPINNER_PID" ]] && return

  (
    local i=0
    while true; do
      printf "\r  ${UI_CYAN}${SPINNER_FRAMES[$i]}${UI_RESET} %s " "$message"
      i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
      sleep 0.1
    done
  ) &
  SPINNER_PID=$!
  disown "$SPINNER_PID" 2>/dev/null
}

stop_spinner() {
  local status="${1:-success}"
  local message="${2:-}"

  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null
    SPINNER_PID=""
  fi

  printf "\r\033[K"

  if [[ -n "$message" ]]; then
    case "$status" in
      success) printf "  ${UI_GREEN}✓${UI_RESET} %s\n" "$message" ;;
      error)   printf "  ${UI_RED}✗${UI_RESET} %s\n" "$message" ;;
      warning) printf "  ${UI_YELLOW}⚠${UI_RESET} %s\n" "$message" ;;
      info)    printf "  ${UI_BLUE}ℹ${UI_RESET} %s\n" "$message" ;;
    esac
  fi
}

show_progress_bar() {
  local current="$1"
  local total="$2"
  local label="${3:-}"
  local width=40

  local percent=$(( current * 100 / total ))
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))

  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done

  printf "\r  ${UI_CYAN}%s${UI_RESET} [${UI_GREEN}%s${UI_RESET}] %3d%% %s" \
    "$UI_ARROW" "$bar" "$percent" "$label"

  [[ $current -eq $total ]] && echo ""
}

# ═══════════════════════════════════════════════════════════
# STEP COUNTER (ETAPAS DE INSTALAÇÃO)
# ═══════════════════════════════════════════════════════════

INSTALL_STEP=0
INSTALL_TOTAL_STEPS=0
INSTALL_START_TIME=0

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
  local elapsed=$((SECONDS - INSTALL_START_TIME))
  local time_str=""
  if [[ $elapsed -gt 0 ]]; then
    time_str=" ($(_format_elapsed "$elapsed"))"
  fi

  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local box_w=$((term_w > 60 ? 56 : term_w - 4))
  local header="[${INSTALL_STEP}/${INSTALL_TOTAL_STEPS}] ${label}"
  local header_len=${#header}
  local time_len=${#time_str}
  local fill=$((box_w - header_len - time_len - 4))
  [[ $fill -lt 1 ]] && fill=1
  local h_fill=""
  for ((i=0; i<fill; i++)); do h_fill+="$UI_BOX_H"; done

  msg ""
  msg "${UI_CYAN}${UI_BOX_TL}${UI_BOX_H} ${UI_BOLD}${UI_WHITE}${header}${UI_RESET}${UI_DIM}${time_str}${UI_RESET} ${UI_CYAN}${h_fill}${UI_BOX_TR}${UI_RESET}"
  if [[ -n "$detail" ]]; then
    msg "${UI_CYAN}${UI_BOX_V}${UI_RESET}  ${UI_DIM}${detail}${UI_RESET}"
  fi
}

step_end() {
  local status="${1:-success}"
  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local box_w=$((term_w > 60 ? 56 : term_w - 4))
  local status_text fill_len h_fill
  case "$status" in
    success) status_text="${UI_GREEN}${UI_CHECK} Concluido${UI_RESET}" ;;
    warning) status_text="${UI_YELLOW}⚠ Com avisos${UI_RESET}" ;;
    error)   status_text="${UI_RED}✗ Com erros${UI_RESET}" ;;
  esac
  fill_len=$((box_w - 16))
  [[ $fill_len -lt 1 ]] && fill_len=1
  h_fill=""
  for ((i=0; i<fill_len; i++)); do h_fill+="$UI_BOX_H"; done
  msg "${UI_CYAN}${UI_BOX_BL}${UI_BOX_H} ${status_text} ${UI_CYAN}${h_fill}${UI_BOX_BR}${UI_RESET}"
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

  while true; do
    echo ""
    echo -e "${UI_CYAN}${UI_BOX_TL}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H} ${UI_BOLD}$title${UI_RESET}${UI_CYAN} ${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_TR}${UI_RESET}"
    echo ""

    if [[ $total -gt 12 ]]; then
      local mid=$(( (total + 1) / 2 ))
      local col_width=38

      for (( i=0; i<mid; i++ )); do
        local left_idx=$((i + 1))
        local right_idx=$((mid + i + 1))
        local left_item="${options[i]}"
        local right_item=""

        local left_check="$UI_UNCHECK"
        local right_check="$UI_UNCHECK"

        for s in "${selected_indices[@]}"; do
          [[ $s -eq $i ]] && left_check="${UI_GREEN}${UI_CHECK}${UI_RESET}"
          [[ $s -eq $((mid + i)) ]] && right_check="${UI_GREEN}${UI_CHECK}${UI_RESET}"
        done

        if [[ $right_idx -le $total ]]; then
          right_item="${options[mid + i]}"
          printf "  ${UI_DIM}%2d${UI_RESET} [%b] %-${col_width}s  ${UI_DIM}%2d${UI_RESET} [%b] %s\n" \
            "$left_idx" "$left_check" "$left_item" "$right_idx" "$right_check" "$right_item"
        else
          printf "  ${UI_DIM}%2d${UI_RESET} [%b] %s\n" "$left_idx" "$left_check" "$left_item"
        fi
      done
    else
      for (( i=0; i<total; i++ )); do
        local idx=$((i + 1))
        local item="${options[i]}"
        local check="$UI_UNCHECK"

        for s in "${selected_indices[@]}"; do
          [[ $s -eq $i ]] && check="${UI_GREEN}${UI_CHECK}${UI_RESET}"
        done

        printf "  ${UI_DIM}%2d${UI_RESET} [%b] %s\n" "$idx" "$check" "$item"
      done
    fi

    echo ""
    echo -e "  ${UI_CYAN}a${UI_RESET}) Todos   ${UI_CYAN}n${UI_RESET}) Nenhum   ${UI_CYAN}Enter${UI_RESET}) Confirmar"
    echo ""
    read -r -p "  Selecione (números separados por vírgula): " input

    case "$input" in
      "")
        break
        ;;
      a|A|all|todos|t|T|\*)
        selected_indices=()
        for ((i=0; i<total; i++)); do
          selected_indices+=($i)
        done
        break
        ;;
      n|N|none|nenhum)
        selected_indices=()
        break
        ;;
      *)
        local valid=1
        local -a new_indices=()
        IFS=',' read -r -a nums <<< "$input"

        for n in "${nums[@]}"; do
          n="${n//[[:space:]]/}"
          [[ -z "$n" ]] && continue

          if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 )) && (( n <= total )); then
            local idx=$((n - 1))
            local found=0
            local -a temp=()
            for s in "${selected_indices[@]}"; do
              if [[ $s -eq $idx ]]; then
                found=1
              else
                temp+=($s)
              fi
            done

            if [[ $found -eq 0 ]]; then
              selected_indices+=($idx)
            else
              selected_indices=("${temp[@]}")
            fi
          else
            valid=0
            break
          fi
        done

        if [[ $valid -eq 0 ]]; then
          echo -e "  ${UI_YELLOW}⚠ Entrada inválida. Use números de 1-$total${UI_RESET}"
          sleep 1
        fi
        ;;
    esac
  done

  local -a result=()
  for idx in "${selected_indices[@]}"; do
    local item="${options[idx]}"
    result+=("$(echo "$item" | awk '{print $1}')")
  done

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
    echo -e "${UI_CYAN}${UI_BOX_TL}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H} ${UI_BOLD}$title${UI_RESET}${UI_CYAN} ${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_TR}${UI_RESET}"
    echo ""

    local idx=1
    for opt in "${options[@]}"; do
      echo -e "  ${UI_CYAN}$idx${UI_RESET}) $opt"
      idx=$((idx + 1))
    done

    echo ""
    read -r -p "  Escolha (1-$total): " _bash_selection

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
  read -r -p "  $question $prompt " answer
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

# ═══════════════════════════════════════════════════════════
# NOTIFICAÇÕES E STATUS
# ═══════════════════════════════════════════════════════════

ui_success() { echo -e "  ${UI_GREEN}✓${UI_RESET} $1"; }
ui_error() { echo -e "  ${UI_RED}✗${UI_RESET} $1"; }
ui_warning() { echo -e "  ${UI_YELLOW}⚠${UI_RESET} $1"; }
ui_info() { echo -e "  ${UI_BLUE}ℹ${UI_RESET} $1"; }
ui_step() { echo -e "  ${UI_CYAN}▶${UI_RESET} $1"; }

ui_status_box() {
  local status="$1"
  local title="$2"
  local message="$3"

  local color
  local icon
  case "$status" in
    success) color="$UI_GREEN"; icon="✓" ;;
    error)   color="$UI_RED"; icon="✗" ;;
    warning) color="$UI_YELLOW"; icon="⚠" ;;
    info)    color="$UI_BLUE"; icon="ℹ" ;;
    *)       color="$UI_CYAN"; icon="▶" ;;
  esac

  echo ""
  echo -e "${color}${UI_BOX_TL}${UI_BOX_H}${UI_BOX_H} ${icon} ${title} ${UI_BOX_H}${UI_BOX_H}${UI_BOX_TR}${UI_RESET}"
  echo -e "${color}${UI_BOX_V}${UI_RESET}  $message"
  echo -e "${color}${UI_BOX_BL}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_BR}${UI_RESET}"
}

