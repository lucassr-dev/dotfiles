#!/usr/bin/env bash
# Funções de seleção interativa para categorias de apps/ferramentas
# Usa o sistema de UI moderno (fzf/gum/bash) de lib/ui.sh
# shellcheck disable=SC2034,SC2329,SC1091

# Arrays globais para armazenar seleções
declare -a SELECTED_CLI_TOOLS=()
declare -a SELECTED_IA_TOOLS=()
declare -a SELECTED_TERMINALS=()

# ═══════════════════════════════════════════════════════════
# Funções de compatibilidade (fallback se ui.sh não carregou)
# ═══════════════════════════════════════════════════════════

# Verifica se o sistema de UI moderno está disponível
_has_modern_ui() {
  declare -F ui_select_multiple >/dev/null 2>&1
}

# Fallback para menu_header se não tiver ui.sh
menu_header() {
  local title="$1"
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  $title"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# Fallback para seleção única
menu_select_single() {
  local title="$1"
  local prompt="$2"
  local out_var="$3"
  shift 3
  local options=("$@")

  # Usar UI moderna se disponível
  if _has_modern_ui; then
    local result=""
    ui_select_single "$title" result "${options[@]}"
    # Mapear resultado para índice
    for i in "${!options[@]}"; do
      local opt_name
      opt_name=$(echo "${options[i]}" | awk '{print $1}')
      if [[ "$opt_name" == "$result" ]]; then
        printf -v "$out_var" '%s' "$((i + 1))"
        return 0
      fi
    done
    printf -v "$out_var" '%s' "1"
    return 0
  fi

  # Fallback bash puro
  local selection=""
  while true; do
    menu_header "$title"
    local idx=1
    for opt in "${options[@]}"; do
      msg "  $idx) $opt"
      idx=$((idx + 1))
    done
    msg ""
    read -r -p "  $prompt (1-${#options[@]}): " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 )) && (( selection <= ${#options[@]} )); then
      printf -v "$out_var" '%s' "$selection"
      return 0
    fi
    msg "  ⚠️  Opção inválida. Digite 1-${#options[@]}."
  done
}

# Fallback para seleção múltipla
select_multiple_items() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  # Usar UI moderna se disponível
  if _has_modern_ui; then
    ui_select_multiple "$title" "$out_var" "${options[@]}"
    return
  fi

  # Fallback bash puro (código original)
  local input=""
  local selected=()

  while true; do
    menu_header "$title"

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
      local idx=1
      for opt in "${options[@]}"; do
        msg "  $idx) $opt"
        idx=$((idx + 1))
      done
    fi

    echo ""
    msg "  a) Todos"
    msg "  (Enter para nenhum)"
    echo ""
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
    msg "  ⚠️  Entrada inválida. Use números da lista separados por vírgula, 'a' para todos ou Enter para nenhum."
  done

  # Usar nameref para atribuir array de volta (Bash 4.3+)
  declare -n array_ref="$out_var"
  array_ref=("${selected[@]}")
  unset -n array_ref
}

confirm_selection() {
  local title="$1"
  shift
  local items=("$@")

  msg ""
  print_selection_summary "$title" "${items[@]}"
  echo ""
  echo -e "  ${UI_CYAN}Enter${UI_RESET} para continuar  │  ${UI_YELLOW}B${UI_RESET} para voltar e alterar"
  echo ""

  local choice
  read -r -p "  → " choice

  case "${choice,,}" in
    b|back|voltar|v) return 1 ;;
    *) return 0 ;;
  esac
}

ask_cli_tools() {
  local tools_with_desc=()
  for tool in "${CLI_TOOLS[@]}"; do
    case "$tool" in
      fzf)        tools_with_desc+=("fzf        - Busca fuzzy interativa (arquivos, histórico, comandos)") ;;
      zoxide)     tools_with_desc+=("zoxide     - 'cd' inteligente que aprende seus diretórios favoritos") ;;
      eza)        tools_with_desc+=("eza        - Substituto moderno do 'ls' com cores e ícones") ;;
      bat)        tools_with_desc+=("bat        - 'cat' com syntax highlighting e integração com Git") ;;
      ripgrep)    tools_with_desc+=("ripgrep    - Busca de texto ultrarrápida (substitui grep)") ;;
      fd)         tools_with_desc+=("fd         - Busca de arquivos moderna (substitui find)") ;;
      delta)      tools_with_desc+=("delta      - Visualizador de diffs do Git com syntax highlighting") ;;
      lazygit)    tools_with_desc+=("lazygit    - Interface TUI para Git (gerenciar commits, branches)") ;;
      gh)         tools_with_desc+=("gh         - CLI oficial do GitHub (PRs, issues, repos)") ;;
      jq)         tools_with_desc+=("jq         - Processador JSON para linha de comando") ;;
      direnv)     tools_with_desc+=("direnv     - Carrega variáveis de ambiente por diretório") ;;
      btop)       tools_with_desc+=("btop       - Monitor de recursos (CPU, RAM, disco, rede)") ;;
      tmux)       tools_with_desc+=("tmux       - Multiplexador de terminal (sessões, janelas, painéis)") ;;
      atuin)      tools_with_desc+=("atuin      - Histórico de shell sincronizado e com busca avançada") ;;
      tealdeer)   tools_with_desc+=("tealdeer   - tldr em Rust - man pages simplificadas e práticas") ;;
      yazi)       tools_with_desc+=("yazi       - File manager moderno em Rust (substitui ranger)") ;;
      procs)      tools_with_desc+=("procs      - ps moderno com cores e informações detalhadas") ;;
      dust)       tools_with_desc+=("dust       - du visual e intuitivo (uso de disco)") ;;
      sd)         tools_with_desc+=("sd         - sed intuitivo e moderno (find & replace)") ;;
      tokei)      tools_with_desc+=("tokei      - Contador de linhas de código por linguagem") ;;
      hyperfine)  tools_with_desc+=("hyperfine  - Benchmarking CLI (medir tempo de comandos)") ;;
      *)          tools_with_desc+=("$tool") ;;
    esac
  done

  while true; do
    SELECTED_CLI_TOOLS=()
    clear_screen
    show_section_header "🛠️  CLI TOOLS - Ferramentas de Linha de Comando"

    msg "Ferramentas modernas para melhorar sua experiência na linha de comando."
    if _has_modern_ui && has_cmd fzf; then
      msg "💡 Use Tab para selecionar, Ctrl+A para todos, Enter para confirmar"
    fi
    msg ""

    local selected_desc=()
    select_multiple_items "🛠️  Selecione as CLI Tools" selected_desc "${tools_with_desc[@]}"

    for item in "${selected_desc[@]}"; do
      local tool_name
      tool_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_CLI_TOOLS+=("$tool_name")
    done

    if confirm_selection "🛠️  CLI Tools" "${SELECTED_CLI_TOOLS[@]}"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de IA Tools
# ═══════════════════════════════════════════════════════════

ask_ia_tools() {
  local tools_with_desc=()
  for tool in "${IA_TOOLS[@]}"; do
    case "$tool" in
      spec-kit)    tools_with_desc+=("spec-kit    - Spec-driven development com IA") ;;
      serena)      tools_with_desc+=("serena      - Assistente de código baseado em IA") ;;
      codex)       tools_with_desc+=("codex       - Geração de código com OpenAI Codex") ;;
      claude-code) tools_with_desc+=("claude-code - CLI oficial do Claude AI (Anthropic)") ;;
      aider)       tools_with_desc+=("aider       - AI pair programming (25K+ GitHub stars)") ;;
      continue)    tools_with_desc+=("continue    - Open-source AI assistant para IDEs") ;;
      goose)       tools_with_desc+=("goose       - AI agent framework (Block/Square)") ;;
      *)           tools_with_desc+=("$tool") ;;
    esac
  done

  while true; do
    SELECTED_IA_TOOLS=()
    clear_screen
    show_section_header "🤖 IA TOOLS - Ferramentas de Desenvolvimento com IA"

    msg "Ferramentas que usam IA para auxiliar no desenvolvimento."
    msg ""
    msg "⚠️  Algumas ferramentas podem exigir configuração adicional"
    msg "   (API keys, login, instalação manual)."
    if _has_modern_ui && has_cmd fzf; then
      msg ""
      msg "💡 Use Tab para selecionar, Ctrl+A para todos, Enter para confirmar"
    fi
    msg ""

    local selected_desc=()
    select_multiple_items "🤖 Selecione as IA Tools" selected_desc "${tools_with_desc[@]}"

    for item in "${selected_desc[@]}"; do
      local tool_name
      tool_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_IA_TOOLS+=("$tool_name")
    done

    if confirm_selection "🤖 IA Tools" "${SELECTED_IA_TOOLS[@]}"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de Terminais
# ═══════════════════════════════════════════════════════════

ask_terminals() {
  local ghostty_desc="Terminal rápido e moderno em Zig"
  local kitty_desc="Terminal rico em recursos com GPU acceleration"
  local alacritty_desc="Terminal ultrarrápido focado em performance"
  local wezterm_desc="Terminal Rust + Lua scripting (cross-platform)"
  local iterm_desc="Terminal avançado para macOS"
  local gnome_desc="Terminal padrão do GNOME"
  local windows_desc="Terminal moderno da Microsoft"

  local available_terminals=()
  for term in "${TERMINALS[@]}"; do
    case "$term" in
      iterm2)
        [[ "$TARGET_OS" == "macos" ]] && available_terminals+=("iTerm2     - $iterm_desc (recomendado macOS)")
        ;;
      windows-terminal)
        [[ "$TARGET_OS" == "windows" ]] && available_terminals+=("WindowsTerminal - $windows_desc (recomendado)")
        ;;
      gnome-terminal)
        [[ "$TARGET_OS" == "linux" || "$TARGET_OS" == "wsl2" ]] && available_terminals+=("gnome-terminal - $gnome_desc")
        ;;
      ghostty)
        [[ "$TARGET_OS" != "windows" ]] && available_terminals+=("Ghostty    - $ghostty_desc")
        ;;
      kitty)
        available_terminals+=("Kitty      - $kitty_desc")
        ;;
      alacritty)
        available_terminals+=("Alacritty  - $alacritty_desc")
        ;;
      wezterm)
        available_terminals+=("WezTerm    - $wezterm_desc")
        ;;
    esac
  done

  if [[ ${#available_terminals[@]} -eq 0 ]]; then
    msg "  ℹ️  Nenhum terminal adicional disponível para $TARGET_OS"
    return
  fi

  while true; do
    SELECTED_TERMINALS=()
    clear_screen
    show_section_header "💻 TERMINAIS - Emuladores de Terminal"

    msg "Escolha qual(is) emulador(es) de terminal você deseja instalar."
    if _has_modern_ui && has_cmd fzf; then
      msg "💡 Use Tab para selecionar, Enter para confirmar"
    fi
    msg ""

    local selected_desc=()
    select_multiple_items "💻 Selecione os terminais" selected_desc "${available_terminals[@]}"

    for item in "${selected_desc[@]}"; do
      case "$item" in
        "iTerm2"*)           SELECTED_TERMINALS+=("iterm2") ;;
        "WindowsTerminal"*)  SELECTED_TERMINALS+=("windows-terminal") ;;
        "gnome-terminal"*)   SELECTED_TERMINALS+=("gnome-terminal") ;;
        "Ghostty"*)          SELECTED_TERMINALS+=("ghostty") ;;
        "Kitty"*)            SELECTED_TERMINALS+=("kitty") ;;
        "Alacritty"*)        SELECTED_TERMINALS+=("alacritty") ;;
        "WezTerm"*)          SELECTED_TERMINALS+=("wezterm") ;;
      esac
    done

    if confirm_selection "💻 Terminais" "${SELECTED_TERMINALS[@]}"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de Shells
# ═══════════════════════════════════════════════════════════

ask_shells() {
  local shell_options=(
    "Zsh     - Shell poderoso e customizável (Recomendado)"
    "Fish    - Sintaxe moderna e autosugestões nativas"
    "Nushell - Shell moderno com dados estruturados (Rust)"
  )

  while true; do
    INSTALL_ZSH=0
    INSTALL_FISH=0
    INSTALL_NUSHELL=0
    clear_screen
    show_section_header "🐚 SHELLS - Escolha seus Interpretadores de Comandos"

    local selected_shells=()
    select_multiple_items "🐚 Selecione os shells para instalar" selected_shells "${shell_options[@]}"

    for item in "${selected_shells[@]}"; do
      local shell_id
      shell_id=$(echo "$item" | awk '{print $1}')
      case "$shell_id" in
        "Zsh")     INSTALL_ZSH=1 ;;
        "Fish")    INSTALL_FISH=1 ;;
        "Nushell") INSTALL_NUSHELL=1 ;;
      esac
    done

    local shells_selected=()
    [[ $INSTALL_ZSH -eq 1 ]] && shells_selected+=("Zsh")
    [[ $INSTALL_FISH -eq 1 ]] && shells_selected+=("Fish")
    [[ $INSTALL_NUSHELL -eq 1 ]] && shells_selected+=("Nushell")

    if [[ ${#shells_selected[@]} -eq 0 ]]; then
      shells_selected=("(nenhum - mantendo shell atual)")
    fi

    if confirm_selection "🐚 Shells" "${shells_selected[@]}"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Tela de dependências base
# ═══════════════════════════════════════════════════════════

ask_base_dependencies() {
  show_section_header "📦 DEPENDÊNCIAS BASE"

  msg "As seguintes dependências são essenciais e serão instaladas:"
  msg ""

  case "$TARGET_OS" in
    linux|wsl2)
      msg "  • build-essential  - Compiladores C/C++ e ferramentas de build"
      msg "  • pkg-config       - Sistema de configuração de bibliotecas"
      msg "  • ca-certificates  - Certificados SSL/TLS"
      msg "  • git              - Sistema de controle de versão"
      msg "  • curl             - Ferramenta para transferência de dados"
      msg "  • wget             - Download de arquivos"
      msg "  • gnupg            - Criptografia e assinaturas digitais"
      msg "  • unzip/zip        - Compressão e descompressão de arquivos"
      msg "  • fontconfig       - Gerenciamento de fontes"
      msg "  • imagemagick      - Redimensionar prévias de imagem"
      msg "  • chafa            - Preview de imagens no terminal (auto-detecta protocolo)"
      msg "  • fzf              - Interface de seleção fuzzy (UI moderna)"
      ;;
    macos)
      msg "  • git              - Sistema de controle de versão"
      msg "  • curl             - Ferramenta para transferência de dados"
      msg "  • wget             - Download de arquivos"
      msg "  • imagemagick      - Redimensionar prévias de imagem"
      msg "  • chafa            - Preview de imagens no terminal (auto-detecta protocolo)"
      msg "  • fzf              - Interface de seleção fuzzy (UI moderna)"
      msg ""
      msg "  ℹ️  Instalação via Homebrew"
      ;;
    windows)
      msg "  • Git              - Sistema de controle de versão"
      msg "  • Windows Terminal - Terminal moderno da Microsoft"
      msg "  • ImageMagick      - Redimensionar prévias de imagem"
      msg "  • chafa            - Preview de imagens no terminal"
      msg "  • fzf              - Interface de seleção fuzzy (UI moderna)"
      msg ""
      msg "  ℹ️  Instalação via winget"
      ;;
  esac

  msg ""
  msg "✅ Estas dependências são fundamentais para o funcionamento correto do instalador."
  msg "ℹ️  Após continuar, a instalação das dependências será iniciada."
  msg ""
}
