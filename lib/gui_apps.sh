#!/usr/bin/env bash
# Seleção de apps GUI

select_apps() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local input=""
  local selected=()

  while true; do
    msg ""
    msg "════════════════════════════════════════════════════════════"
    msg "  🖥️  SELEÇÃO DE APLICATIVOS GUI"
    msg "════════════════════════════════════════════════════════════"
    msg ""
    msg "Use números separados por vírgula, 'a' para todos ou Enter para nenhum."
    msg ""
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  $title"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local idx=1
    for opt in "${options[@]}"; do
      msg "  $idx) $opt"
      idx=$((idx + 1))
    done
    msg "  a) Todos"
    msg "  (Enter para nenhum)"
    read -r -p "  Selecione números separados por vírgula ou 'a': " input

    if [[ -z "$input" ]]; then
      selected=()
      break
    fi

    case "$input" in
      a|A|x|X|all|ALL|todos|T|t|\*)
        selected=("${options[@]}")
        break
        ;;
    esac

    local valid=1
    local nums=()
    IFS=',' read -r -a nums <<< "$input"
    for n in "${nums[@]}"; do
      n="${n//[[:space:]]/}"
      [[ -z "$n" ]] && continue
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 )) && (( n <= ${#options[@]} )); then
        local opt="${options[n-1]}"
        local skip=0
        for s in "${selected[@]}"; do
          [[ "$s" == "$opt" ]] && skip=1
        done
        (( skip )) || selected+=("$opt")
      else
        valid=0
        break
      fi
    done

    (( valid )) && break
    msg "  ⚠️ Entrada inválida. Use números da lista separados por vírgula, 'a' para todos ou Enter para nenhum."
  done

  eval "$out_var=(\"\${selected[@]}\")"

  if declare -F clear_screen >/dev/null; then
    clear_screen
  else
    clear
  fi
}

ask_gui_apps() {
  SELECTED_IDES=()
  SELECTED_BROWSERS=()
  SELECTED_DEV_TOOLS=()
  SELECTED_DATABASES=()
  SELECTED_PRODUCTIVITY=()
  SELECTED_COMMUNICATION=()
  SELECTED_MEDIA=()
  SELECTED_UTILITIES=()

  # Filtrar arrays por OS quando necessário
  local ides_all=("${IDES[@]}")
  local browsers_all=("${BROWSERS[@]}")
  local dev_all=("${DEV_TOOLS[@]}")
  local db_all=("${DATABASE_APPS[@]}")
  local productivity_all=("${PRODUCTIVITY_APPS[@]}")
  local communication_all=("${COMMUNICATION_APPS[@]}")
  local media_all=("${MEDIA_APPS[@]}")
  local utilities_all=("${UTILITIES_APPS[@]}")

  if [[ "$INTERACTIVE_GUI_APPS" != "true" ]]; then
    SELECTED_IDES=("${ides_all[@]}")
    SELECTED_BROWSERS=("${browsers_all[@]}")
    SELECTED_DEV_TOOLS=("${dev_all[@]}")
    SELECTED_DATABASES=("${db_all[@]}")
    SELECTED_PRODUCTIVITY=("${productivity_all[@]}")
    SELECTED_COMMUNICATION=("${communication_all[@]}")
    SELECTED_MEDIA=("${media_all[@]}")
    SELECTED_UTILITIES=("${utilities_all[@]}")
    return 0
  fi

  while true; do
    SELECTED_IDES=()
    SELECTED_BROWSERS=()
    SELECTED_DEV_TOOLS=()
    SELECTED_DATABASES=()
    SELECTED_PRODUCTIVITY=()
    SELECTED_COMMUNICATION=()
    SELECTED_MEDIA=()
    SELECTED_UTILITIES=()

    select_apps "⌨️  IDEs E EDITORES" SELECTED_IDES "${ides_all[@]}"
    select_apps "🌐 NAVEGADORES" SELECTED_BROWSERS "${browsers_all[@]}"
    select_apps "💻 FERRAMENTAS DE DESENVOLVIMENTO" SELECTED_DEV_TOOLS "${dev_all[@]}"
    select_apps "🗄️  BANCOS DE DADOS" SELECTED_DATABASES "${db_all[@]}"
    select_apps "📝 PRODUTIVIDADE" SELECTED_PRODUCTIVITY "${productivity_all[@]}"
    select_apps "💬 COMUNICAÇÃO" SELECTED_COMMUNICATION "${communication_all[@]}"
    select_apps "🎵 MÍDIA" SELECTED_MEDIA "${media_all[@]}"
    select_apps "🛠️  UTILITÁRIOS" SELECTED_UTILITIES "${utilities_all[@]}"

    if [[ "$TARGET_OS" == "macos" ]]; then
      msg ""
      msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      msg "  🍺 BREWFILE (APENAS macOS)"
      msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      msg "  O Brewfile contém apps adicionais (Arc, iTerm2, Raycast, Rectangle, etc.)"
      if ask_yes_no "  Instalar apps do Brewfile?"; then
        INSTALL_BREWFILE=true
      else
        INSTALL_BREWFILE=false
      fi
    fi

    break
  done
}

should_install_app() {
  local app="$1"
  local category="$2"

  case "$category" in
    ides)
      for selected in "${SELECTED_IDES[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    browsers)
      for selected in "${SELECTED_BROWSERS[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    dev-tools)
      for selected in "${SELECTED_DEV_TOOLS[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    databases)
      for selected in "${SELECTED_DATABASES[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    productivity)
      for selected in "${SELECTED_PRODUCTIVITY[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    communication)
      for selected in "${SELECTED_COMMUNICATION[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    media)
      for selected in "${SELECTED_MEDIA[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
    utilities)
      for selected in "${SELECTED_UTILITIES[@]}"; do
        [[ "$selected" == "$app" ]] && return 0
      done
      ;;
  esac
  return 1
}
