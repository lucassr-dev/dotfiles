#!/usr/bin/env bash
# Sistema de UI moderno para seleção interativa
# Suporta: fzf (primário), gum (alternativo), bash puro (fallback)
# shellcheck disable=SC2034,SC2329

# ═══════════════════════════════════════════════════════════
# CONFIGURAÇÃO E DETECÇÃO
# ═══════════════════════════════════════════════════════════

# Cores para UI
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

# Símbolos Unicode para checkboxes
declare -g UI_CHECK="✓"
declare -g UI_UNCHECK="○"
declare -g UI_ARROW="›"
declare -g UI_BOX_H="─"
declare -g UI_BOX_V="│"
declare -g UI_BOX_TL="╭"
declare -g UI_BOX_TR="╮"
declare -g UI_BOX_BL="╰"
declare -g UI_BOX_BR="╯"

# Detectar modo de UI disponível
detect_ui_mode() {
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

# Spinner frames (Braille)
declare -a SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
declare -g SPINNER_PID=""

start_spinner() {
  local message="${1:-Aguarde...}"

  # Não iniciar se já tem um rodando
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

  # Limpar linha
  printf "\r\033[K"

  # Mostrar resultado
  if [[ -n "$message" ]]; then
    case "$status" in
      success) printf "  ${UI_GREEN}✓${UI_RESET} %s\n" "$message" ;;
      error)   printf "  ${UI_RED}✗${UI_RESET} %s\n" "$message" ;;
      warning) printf "  ${UI_YELLOW}⚠${UI_RESET} %s\n" "$message" ;;
      info)    printf "  ${UI_BLUE}ℹ${UI_RESET} %s\n" "$message" ;;
    esac
  fi
}

# Barra de progresso
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
# SELEÇÃO MÚLTIPLA - FZF
# ═══════════════════════════════════════════════════════════

# Seleção múltipla usando fzf
# Retorna itens selecionados (primeira palavra de cada linha)
ui_select_multi_fzf() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local selected
  selected=$(printf '%s\n' "${options[@]}" | fzf \
    --multi \
    --ansi \
    --reverse \
    --height=60% \
    --border=rounded \
    --header="📦 $title" \
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

  # Extrair nomes (primeira palavra)
  local -a result=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && result+=("$(echo "$line" | awk '{print $1}')")
  done <<< "$selected"

  # Atribuir resultado
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

  # Extrair nomes
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
    # Limpar tela e mostrar header
    echo ""
    echo -e "${UI_CYAN}${UI_BOX_TL}${UI_BOX_H}${UI_BOX_H}${UI_BOX_H} ${UI_BOLD}$title${UI_RESET}${UI_CYAN} ${UI_BOX_H}${UI_BOX_H}${UI_BOX_H}${UI_BOX_TR}${UI_RESET}"
    echo ""

    # Layout em 2 colunas se muitos itens
    if [[ $total -gt 12 ]]; then
      local mid=$(( (total + 1) / 2 ))
      local col_width=38

      for (( i=0; i<mid; i++ )); do
        local left_idx=$((i + 1))
        local right_idx=$((mid + i + 1))
        local left_item="${options[i]}"
        local right_item=""

        # Verificar se está selecionado
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
      # Layout simples
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

    # Processar entrada
    case "$input" in
      "")
        # Enter sem input = confirmar seleção atual
        break
        ;;
      a|A|all|todos|t|T|\*)
        # Selecionar todos
        selected_indices=()
        for ((i=0; i<total; i++)); do
          selected_indices+=($i)
        done
        break
        ;;
      n|N|none|nenhum)
        # Limpar seleção
        selected_indices=()
        break
        ;;
      *)
        # Processar números
        local valid=1
        local -a new_indices=()
        IFS=',' read -r -a nums <<< "$input"

        for n in "${nums[@]}"; do
          n="${n//[[:space:]]/}"
          [[ -z "$n" ]] && continue

          if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 )) && (( n <= total )); then
            local idx=$((n - 1))
            # Toggle: adicionar se não está, remover se está
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

  # Construir resultado
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
  local out_var="$2"
  shift 2
  local options=("$@")

  local selected
  selected=$(printf '%s\n' "${options[@]}" | fzf \
    --ansi \
    --reverse \
    --height=40% \
    --border=rounded \
    --header="$title" \
    --prompt="Buscar: " \
    --pointer="▶" \
    --no-mouse \
    --color='header:cyan,pointer:green,prompt:yellow' \
  ) || true

  local result=""
  [[ -n "$selected" ]] && result=$(echo "$selected" | awk '{print $1}')

  printf -v "$out_var" '%s' "$result"
}

ui_select_single_gum() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local selected
  selected=$(gum choose \
    --header="$title" \
    --cursor.foreground="cyan" \
    "${options[@]}" \
  ) || true

  local result=""
  [[ -n "$selected" ]] && result=$(echo "$selected" | awk '{print $1}')

  printf -v "$out_var" '%s' "$result"
}

ui_select_single_bash() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local total=${#options[@]}
  local selection=""

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
    read -r -p "  Escolha (1-$total): " selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 )) && (( selection <= total )); then
      local selected_item="${options[selection-1]}"
      local result
      result=$(echo "$selected_item" | awk '{print $1}')
      printf -v "$out_var" '%s' "$result"
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

# Seleção múltipla (API principal)
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

# Seleção única (API principal)
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

ui_success() {
  echo -e "  ${UI_GREEN}✓${UI_RESET} $1"
}

ui_error() {
  echo -e "  ${UI_RED}✗${UI_RESET} $1"
}

ui_warning() {
  echo -e "  ${UI_YELLOW}⚠${UI_RESET} $1"
}

ui_info() {
  echo -e "  ${UI_BLUE}ℹ${UI_RESET} $1"
}

ui_step() {
  echo -e "  ${UI_CYAN}▶${UI_RESET} $1"
}

# Box de status
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

