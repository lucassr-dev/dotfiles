#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329

# ═══════════════════════════════════════════════════════════
# Verificação de UI moderna
# ═══════════════════════════════════════════════════════════

_gui_has_modern_ui() {
  declare -F ui_select_multiple >/dev/null 2>&1
}

_app_is_auto_installable() {
  local app="$1"

  if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
    return 0
  fi

  case "${TARGET_OS:-}" in
    linux|wsl2)
      case "$app" in
        ghostty|kitty|alacritty|gnome-terminal|pgadmin|mongodb)
          return 0
          ;;
      esac
      ;;
    macos)
      case "$app" in
        iterm2|ghostty|kitty|alacritty|intellij-idea|pycharm|webstorm|phpstorm|goland|rubymine|clion|rider|datagrip|android-studio|rectangle|alfred|bartender|cleanmymac|istat-menus)
          return 0
          ;;
      esac
      ;;
  esac

  return 1
}

_mark_manual_entries() {
  local -n _items_ref="$1"
  local i entry app
  for i in "${!_items_ref[@]}"; do
    entry="${_items_ref[$i]}"
    app="${entry%% *}"
    if ! _app_is_auto_installable "$app"; then
      _items_ref[$i]="${entry} [manual]"
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Função de seleção com suporte híbrido (moderno + fallback)
# ═══════════════════════════════════════════════════════════

select_apps() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  if _gui_has_modern_ui; then
    ui_select_multiple "$title" "$out_var" "${options[@]}"
    return
  fi

  # ═══════════════════════════════════════════════════════════
  # Fallback: Bash puro com checkboxes visuais
  # ═══════════════════════════════════════════════════════════
  local input=""
  local selected=()

  while true; do
    msg ""
    msg "════════════════════════════════════════════════════════════"
    msg "  $title"
    msg "════════════════════════════════════════════════════════════"
    msg ""
    msg "Use números separados por vírgula, 'a' para todos ou Enter para nenhum."
    msg ""

    local idx=1
    local total=${#options[@]}

    if [[ $total -gt 15 ]]; then
      local mid=$(( (total + 1) / 2 ))
      local col_width=35

      for (( i=0; i<mid; i++ )); do
        local left_idx=$((i + 1))
        local right_idx=$((mid + i + 1))
        local left_item="${options[i]}"
        local right_item=""

        if [[ $right_idx -le $total ]]; then
          right_item="${options[mid + i]}"
        fi

        if [[ -n "$right_item" ]]; then
          printf "  %-2d) %-${col_width}s  %-2d) %s\n" "$left_idx" "$left_item" "$right_idx" "$right_item"
        else
          printf "  %-2d) %s\n" "$left_idx" "$left_item"
        fi
      done
    else
      for opt in "${options[@]}"; do
        msg "  $idx) $opt"
        idx=$((idx + 1))
      done
    fi

    msg ""
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

  declare -n array_ref="$out_var"
  array_ref=("${selected[@]}")
  unset -n array_ref
}

ask_gui_apps() {
  if [[ "$INTERACTIVE_GUI_APPS" != "true" ]]; then
    SELECTED_IDES=("${IDES[@]}")
    SELECTED_BROWSERS=("${BROWSERS[@]}")
    SELECTED_DEV_TOOLS=("${DEV_TOOLS[@]}")
    SELECTED_DATABASES=("${DATABASE_APPS[@]}")
    SELECTED_PRODUCTIVITY=("${PRODUCTIVITY_APPS[@]}")
    SELECTED_COMMUNICATION=("${COMMUNICATION_APPS[@]}")
    SELECTED_MEDIA=("${MEDIA_APPS[@]}")
    SELECTED_UTILITIES=("${UTILITIES_APPS[@]}")
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

    clear_screen
    show_section_header "🖥️  APLICATIVOS GUI"

  msg "Selecione os aplicativos gráficos que você deseja instalar."
  msg ""

  # ═══════════════════════════════════════════════════════════
  # IDEs e Editores com descrições
  # ═══════════════════════════════════════════════════════════
  local ides_with_desc=()
  for ide in "${IDES[@]}"; do
    case "$ide" in
      vscode)         ides_with_desc+=("vscode          - Visual Studio Code (popular, extensível)") ;;
      zed)            ides_with_desc+=("zed             - Editor ultrarrápido em Rust") ;;
      cursor)         ides_with_desc+=("cursor          - VS Code + AI nativo (fork)") ;;
      neovim)         ides_with_desc+=("neovim          - Vim moderno, altamente configurável") ;;
      helix)          ides_with_desc+=("helix           - Editor modal moderno (inspirado no Kakoune)") ;;
      intellij-idea)  ides_with_desc+=("intellij-idea   - IDE JetBrains para Java/Kotlin") ;;
      pycharm)        ides_with_desc+=("pycharm         - IDE JetBrains para Python") ;;
      webstorm)       ides_with_desc+=("webstorm        - IDE JetBrains para JavaScript/TypeScript") ;;
      phpstorm)       ides_with_desc+=("phpstorm        - IDE JetBrains para PHP") ;;
      goland)         ides_with_desc+=("goland          - IDE JetBrains para Go") ;;
      rubymine)       ides_with_desc+=("rubymine        - IDE JetBrains para Ruby") ;;
      clion)          ides_with_desc+=("clion           - IDE JetBrains para C/C++") ;;
      rider)          ides_with_desc+=("rider           - IDE JetBrains para .NET/C#") ;;
      datagrip)       ides_with_desc+=("datagrip        - IDE JetBrains para bancos de dados") ;;
      sublime-text)   ides_with_desc+=("sublime-text    - Editor rápido e leve") ;;
      android-studio) ides_with_desc+=("android-studio  - IDE oficial para desenvolvimento Android") ;;
      *)              ides_with_desc+=("$ide") ;;
    esac
  done
  _mark_manual_entries ides_with_desc
  select_apps "⌨️  IDEs E EDITORES" SELECTED_IDES "${ides_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Navegadores com descrições
  # ═══════════════════════════════════════════════════════════
  local browsers_with_desc=()
  for browser in "${BROWSERS[@]}"; do
    case "$browser" in
      firefox) browsers_with_desc+=("firefox - Mozilla Firefox (privacidade)") ;;
      chrome)  browsers_with_desc+=("chrome  - Google Chrome (popular)") ;;
      brave)   browsers_with_desc+=("brave   - Brave (bloqueio de ads nativo)") ;;
      arc)     browsers_with_desc+=("arc     - Arc Browser (inovador, macOS-first)") ;;
      zen)     browsers_with_desc+=("zen     - Zen Browser (Firefox fork, foco)") ;;
      *)       browsers_with_desc+=("$browser") ;;
    esac
  done
  _mark_manual_entries browsers_with_desc
  select_apps "🌐 NAVEGADORES" SELECTED_BROWSERS "${browsers_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Ferramentas de Desenvolvimento com descrições
  # ═══════════════════════════════════════════════════════════
  local dev_with_desc=()
  for tool in "${DEV_TOOLS[@]}"; do
    case "$tool" in
      docker)  dev_with_desc+=("docker  - Containers e virtualização") ;;
      postman) dev_with_desc+=("postman - Cliente REST API") ;;
      dbeaver) dev_with_desc+=("dbeaver - Cliente universal de bancos de dados") ;;
      vscode)  dev_with_desc+=("vscode  - Visual Studio Code") ;;
      *)       dev_with_desc+=("$tool") ;;
    esac
  done
  _mark_manual_entries dev_with_desc
  select_apps "💻 FERRAMENTAS DE DESENVOLVIMENTO" SELECTED_DEV_TOOLS "${dev_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Bancos de Dados com descrições
  # ═══════════════════════════════════════════════════════════
  local db_with_desc=()
  for db in "${DATABASE_APPS[@]}"; do
    case "$db" in
      postgresql) db_with_desc+=("postgresql - Banco relacional robusto e popular") ;;
      redis)      db_with_desc+=("redis      - Cache e key-value store em memória") ;;
      mysql)      db_with_desc+=("mysql      - Banco relacional clássico") ;;
      mongodb)    db_with_desc+=("mongodb    - Banco NoSQL orientado a documentos") ;;
      *)          db_with_desc+=("$db") ;;
    esac
  done
  _mark_manual_entries db_with_desc
  select_apps "🗄️  BANCOS DE DADOS" SELECTED_DATABASES "${db_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Produtividade com descrições
  # ═══════════════════════════════════════════════════════════
  local prod_with_desc=()
  for app in "${PRODUCTIVITY_APPS[@]}"; do
    case "$app" in
      slack)    prod_with_desc+=("slack    - Comunicação para times") ;;
      notion)   prod_with_desc+=("notion   - Notas e wikis colaborativas") ;;
      obsidian) prod_with_desc+=("obsidian - Notas com links bidirecionais") ;;
      *)        prod_with_desc+=("$app") ;;
    esac
  done
  _mark_manual_entries prod_with_desc
  select_apps "📝 PRODUTIVIDADE" SELECTED_PRODUCTIVITY "${prod_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Comunicação com descrições
  # ═══════════════════════════════════════════════════════════
  local comm_with_desc=()
  for app in "${COMMUNICATION_APPS[@]}"; do
    case "$app" in
      discord)  comm_with_desc+=("discord  - Chat e voz para comunidades") ;;
      telegram) comm_with_desc+=("telegram - Mensagens rápidas e seguras") ;;
      zoom)     comm_with_desc+=("zoom     - Videoconferência") ;;
      teams)    comm_with_desc+=("teams    - Microsoft Teams") ;;
      *)        comm_with_desc+=("$app") ;;
    esac
  done
  _mark_manual_entries comm_with_desc
  select_apps "💬 COMUNICAÇÃO" SELECTED_COMMUNICATION "${comm_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Mídia com descrições
  # ═══════════════════════════════════════════════════════════
  local media_with_desc=()
  for app in "${MEDIA_APPS[@]}"; do
    case "$app" in
      vlc)     media_with_desc+=("vlc     - Player de mídia universal") ;;
      spotify) media_with_desc+=("spotify - Streaming de música") ;;
      mpv)     media_with_desc+=("mpv     - Player minimalista e poderoso") ;;
      *)       media_with_desc+=("$app") ;;
    esac
  done
  _mark_manual_entries media_with_desc
  select_apps "🎵 MÍDIA" SELECTED_MEDIA "${media_with_desc[@]}"

  # ═══════════════════════════════════════════════════════════
  # Utilitários com descrições
  # ═══════════════════════════════════════════════════════════
  local util_with_desc=()
  for app in "${UTILITIES_APPS[@]}"; do
    case "$app" in
      powertoys)    util_with_desc+=("powertoys    - Ferramentas Microsoft para Windows") ;;
      sharex)       util_with_desc+=("sharex       - Captura de tela avançada (Windows)") ;;
      rectangle)    util_with_desc+=("rectangle    - Gerenciador de janelas para macOS") ;;
      alfred)       util_with_desc+=("alfred       - Launcher avançado para macOS") ;;
      bartender)    util_with_desc+=("bartender    - Organizador de menu bar (macOS)") ;;
      cleanmymac)   util_with_desc+=("cleanmymac   - Limpeza de sistema (macOS)") ;;
      istat-menus)  util_with_desc+=("istat-menus  - Monitor de sistema na menu bar (macOS)") ;;
      bitwarden)    util_with_desc+=("bitwarden    - Gerenciador de senhas open-source") ;;
      1password)    util_with_desc+=("1password    - Gerenciador de senhas premium") ;;
      keepassxc)    util_with_desc+=("keepassxc    - Gerenciador de senhas offline") ;;
      flameshot)    util_with_desc+=("flameshot    - Screenshot tool (Linux)") ;;
      syncthing)    util_with_desc+=("syncthing    - Sincronização P2P de arquivos") ;;
      veracrypt)    util_with_desc+=("veracrypt    - Criptografia de disco") ;;
      balenaetcher) util_with_desc+=("balenaetcher - Flash de imagens USB") ;;
      *)            util_with_desc+=("$app") ;;
    esac
  done
  _mark_manual_entries util_with_desc
  select_apps "🛠️  UTILITÁRIOS" SELECTED_UTILITIES "${util_with_desc[@]}"


    msg ""
    _show_gui_selection_summary

    local gui_total=0
    gui_total=$((${#SELECTED_IDES[@]} + ${#SELECTED_BROWSERS[@]} + ${#SELECTED_DEV_TOOLS[@]} + \
                 ${#SELECTED_DATABASES[@]} + ${#SELECTED_PRODUCTIVITY[@]} + \
                 ${#SELECTED_COMMUNICATION[@]} + ${#SELECTED_MEDIA[@]} + ${#SELECTED_UTILITIES[@]}))

    local gui_summary="$gui_total apps selecionados"
    [[ $gui_total -eq 0 ]] && gui_summary="(nenhum)"

    if confirm_selection "🖥️  Apps GUI" "$gui_summary"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Funções auxiliares
# ═══════════════════════════════════════════════════════════

_show_gui_selection_summary() {
  local has_any=0

  if [[ ${#SELECTED_IDES[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_IDES[@]}"); items="${items%, }"
    echo -e "  ⌨️  ${UI_BOLD}${UI_YELLOW}IDEs:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_BROWSERS[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_BROWSERS[@]}"); items="${items%, }"
    echo -e "  🌐 ${UI_BOLD}${UI_YELLOW}Navegadores:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_DEV_TOOLS[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_DEV_TOOLS[@]}"); items="${items%, }"
    echo -e "  💻 ${UI_BOLD}${UI_YELLOW}Ferr. Dev:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_DATABASES[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_DATABASES[@]}"); items="${items%, }"
    echo -e "  🗄️  ${UI_BOLD}${UI_YELLOW}Bancos:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_PRODUCTIVITY[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_PRODUCTIVITY[@]}"); items="${items%, }"
    echo -e "  📝 ${UI_BOLD}${UI_YELLOW}Produtividade:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_COMMUNICATION[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_COMMUNICATION[@]}"); items="${items%, }"
    echo -e "  💬 ${UI_BOLD}${UI_YELLOW}Comunicação:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_MEDIA[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_MEDIA[@]}"); items="${items%, }"
    echo -e "  🎵 ${UI_BOLD}${UI_YELLOW}Mídia:${UI_RESET} $items"
  fi

  if [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]]; then
    has_any=1
    local items; items=$(printf "%s, " "${SELECTED_UTILITIES[@]}"); items="${items%, }"
    echo -e "  🛠️  ${UI_BOLD}${UI_YELLOW}Utilitários:${UI_RESET} $items"
  fi

  if [[ $has_any -eq 0 ]]; then
    msg "  ℹ️  Nenhum app GUI selecionado"
  fi
}
