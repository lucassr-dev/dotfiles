#!/usr/bin/env bash
# Funções de seleção interativa para categorias de apps/ferramentas
# shellcheck disable=SC2034,SC2329,SC1091

# Arrays globais para armazenar seleções
declare -a SELECTED_CLI_TOOLS=()
declare -a SELECTED_IA_TOOLS=()
declare -a SELECTED_TERMINALS=()

# ═══════════════════════════════════════════════════════════
# Função auxiliar para seleção de múltiplos itens
# ═══════════════════════════════════════════════════════════

menu_header() {
  local title="$1"
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  $title"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

menu_select_single() {
  local title="$1"
  local prompt="$2"
  local out_var="$3"
  shift 3
  local options=("$@")
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
      eval "$out_var=$selection"
      return 0
    fi
    msg "  ⚠️  Opção inválida. Digite 1-${#options[@]}."
  done
}

select_multiple_items() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  local input=""
  local selected=()

  while true; do
    menu_header "$title"

    local idx=1
    for opt in "${options[@]}"; do
      msg "  $idx) $opt"
      idx=$((idx + 1))
    done
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

  eval "$out_var=(\"\${selected[@]}\")"
}

# ═══════════════════════════════════════════════════════════
# Seleção de CLI Tools
# ═══════════════════════════════════════════════════════════

ask_cli_tools() {
  while true; do
    SELECTED_CLI_TOOLS=()

    show_section_header "🛠️  CLI TOOLS - Ferramentas de Linha de Comando"

    msg "Ferramentas modernas para melhorar sua experiência na linha de comando."
    msg ""

    local tools_with_desc=()
    for tool in "${CLI_TOOLS[@]}"; do
      case "$tool" in
        fzf) tools_with_desc+=("fzf        - Busca fuzzy interativa (arquivos, histórico, comandos)") ;;
        zoxide) tools_with_desc+=("zoxide     - 'cd' inteligente que aprende seus diretórios favoritos") ;;
        eza) tools_with_desc+=("eza        - Substituto moderno do 'ls' com cores e ícones") ;;
        bat) tools_with_desc+=("bat        - 'cat' com syntax highlighting e integração com Git") ;;
        ripgrep) tools_with_desc+=("ripgrep    - Busca de texto ultrarrápida (substitui grep)") ;;
        fd) tools_with_desc+=("fd         - Busca de arquivos moderna (substitui find)") ;;
        delta) tools_with_desc+=("delta      - Visualizador de diffs do Git com syntax highlighting") ;;
        lazygit) tools_with_desc+=("lazygit    - Interface TUI para Git (gerenciar commits, branches, etc)") ;;
        gh) tools_with_desc+=("gh         - CLI oficial do GitHub (PRs, issues, repos)") ;;
        jq) tools_with_desc+=("jq         - Processador JSON para linha de comando") ;;
        direnv) tools_with_desc+=("direnv     - Carrega variáveis de ambiente por diretório") ;;
        btop) tools_with_desc+=("btop       - Monitor de recursos (CPU, RAM, disco, rede)") ;;
        tmux) tools_with_desc+=("tmux       - Multiplexador de terminal (sessões, janelas, painéis)") ;;
        atuin) tools_with_desc+=("atuin      - Histórico de shell sincronizado e com busca avançada") ;;
        *) tools_with_desc+=("$tool") ;;
      esac
    done

    local selected_desc=()
    select_multiple_items "🛠️  Selecione as CLI Tools que deseja instalar" selected_desc "${tools_with_desc[@]}"

    # Mapear de volta para nomes sem descrição
    for item in "${selected_desc[@]}"; do
      # Remove tudo após " - " para pegar só o nome da ferramenta
      local tool_name="${item%% - *}"
      # Remove espaços extras
      tool_name="${tool_name// /}"
      SELECTED_CLI_TOOLS+=("$tool_name")
    done

    msg ""
    msg "✅ Seleção de CLI Tools concluída"
    print_selection_summary "🛠️  CLI Tools" "${SELECTED_CLI_TOOLS[@]}"
    msg ""
    break
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de IA Tools
# ═══════════════════════════════════════════════════════════

ask_ia_tools() {
  while true; do
    SELECTED_IA_TOOLS=()

    show_section_header "🤖 IA TOOLS - Ferramentas de Desenvolvimento com IA"

    msg "Ferramentas que usam IA para auxiliar no desenvolvimento."
    msg ""
    msg "⚠️  Algumas ferramentas podem exigir configuração adicional"
    msg "   (API keys, login, instalação manual)."
    msg ""

    local tools_with_desc=()
    for tool in "${IA_TOOLS[@]}"; do
      case "$tool" in
        spec-kit) tools_with_desc+=("spec-kit     - Spec-driven development com IA") ;;
        serena) tools_with_desc+=("serena       - Assistente de código baseado em IA") ;;
        codex) tools_with_desc+=("codex        - Geração de código com OpenAI Codex") ;;
        claude-code) tools_with_desc+=("claude-code  - CLI para interagir com Claude AI") ;;
        *) tools_with_desc+=("$tool") ;;
      esac
    done

    local selected_desc=()
    select_multiple_items "🤖 Selecione as IA Tools que deseja instalar" selected_desc "${tools_with_desc[@]}"

    # Mapear de volta para nomes sem descrição
    for item in "${selected_desc[@]}"; do
      local tool_name="${item%% - *}"
      SELECTED_IA_TOOLS+=("$tool_name")
    done

    msg ""
    msg "✅ Seleção de IA Tools concluída"
    print_selection_summary "🤖 IA Tools" "${SELECTED_IA_TOOLS[@]}"
    msg ""
    break
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de Terminais
# ═══════════════════════════════════════════════════════════

ask_terminals() {
  while true; do
    SELECTED_TERMINALS=()

    show_section_header "💻 TERMINAIS - Emuladores de Terminal"

    msg "Escolha qual(is) emulador(es) de terminal você deseja instalar."
    msg ""
    local ghostty_desc="Terminal rápido e moderno em Zig (Linux/macOS)"
    local kitty_desc="Terminal rico em recursos com GPU acceleration"
    local alacritty_desc="Terminal ultrarrápido focado em performance"
    local iterm_desc="Terminal avançado para macOS"
    local gnome_desc="Terminal padrão do GNOME"
    local windows_desc="Terminal moderno da Microsoft"

    # Filtrar terminais por OS
    local available_terminals=()
    for term in "${TERMINALS[@]}"; do
      case "$term" in
        iterm2)
          if [[ "$TARGET_OS" == "macos" ]]; then
            available_terminals+=("iTerm2 (recomendado macOS) - $iterm_desc")
          fi
          ;;
        windows-terminal)
          if [[ "$TARGET_OS" == "windows" ]]; then
            available_terminals+=("Windows Terminal (recomendado Windows) - $windows_desc")
          fi
          ;;
        gnome-terminal)
          if [[ "$TARGET_OS" == "linux" || "$TARGET_OS" == "wsl2" ]]; then
            available_terminals+=("GNOME Terminal (Linux) - $gnome_desc")
          fi
          ;;
        ghostty)
          if [[ "$TARGET_OS" != "windows" ]]; then
            if [[ "$TARGET_OS" == "macos" ]]; then
              available_terminals+=("Ghostty (recomendado macOS) - $ghostty_desc")
            else
              available_terminals+=("Ghostty (Linux) - $ghostty_desc")
            fi
          fi
          ;;
      kitty|alacritty)
        if [[ "$term" == "kitty" ]]; then
          available_terminals+=("Kitty - $kitty_desc")
        else
          available_terminals+=("Alacritty - $alacritty_desc")
        fi
        ;;
      esac
    done

    if [[ ${#available_terminals[@]} -eq 0 ]]; then
      msg "  ℹ️  Nenhum terminal adicional disponível para $TARGET_OS"
      return
    fi

    local selected_desc=()
    select_multiple_items "💻 Selecione os terminais que deseja instalar" selected_desc "${available_terminals[@]}"

    # Mapear de volta para nomes padronizados
    for item in "${selected_desc[@]}"; do
      case "$item" in
        "iTerm2"*) SELECTED_TERMINALS+=("iterm2") ;;
        "Windows Terminal"*) SELECTED_TERMINALS+=("windows-terminal") ;;
        "GNOME Terminal"*) SELECTED_TERMINALS+=("gnome-terminal") ;;
        "Ghostty"*) SELECTED_TERMINALS+=("ghostty") ;;
        "Kitty"*) SELECTED_TERMINALS+=("kitty") ;;
        "Alacritty"*) SELECTED_TERMINALS+=("alacritty") ;;
      esac
    done

    msg ""
    msg "✅ Seleção de Terminais concluída"
    print_selection_summary "💻 Terminais" "${SELECTED_TERMINALS[@]}"
    msg ""
    break
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de Shells
# ═══════════════════════════════════════════════════════════

ask_shells() {
  show_section_header "🐚 SHELLS - Escolha seu Interpretador de Comandos"

  msg "Shells são interpretadores de comandos que você usa no terminal."
  msg ""
  msg "📝 Descrição dos shells disponíveis:"
  msg ""
  msg "  • Zsh (Z Shell)"
  msg "    - Shell poderoso e altamente customizável"
  msg "    - Grande ecossistema de plugins (Oh My Zsh, Prezto)"
  msg "    - Compatível com Bash na maioria dos casos"
  msg "    - Themes: Oh My Zsh + Powerlevel10k, Starship, Oh My Posh"
  msg "    - Ideal para: usuários que querem customização total"
  msg ""
  msg "  • Fish (Friendly Interactive Shell)"
  msg "    - Sintaxe moderna e amigável (não POSIX)"
  msg "    - Autosugestões e syntax highlighting nativos"
  msg "    - Configuração via web interface (fish_config)"
  msg "    - Themes: Starship, Oh My Posh, Fisher plugins"
  msg "    - Ideal para: quem quer algo funcional 'out of the box'"
  msg ""
  msg "💡 Você pode instalar ambos e alternar quando quiser com:"
  msg "   chsh -s \$(which zsh)  # ou \$(which fish)"
  msg ""

  local choice=""
  menu_select_single "Qual(is) shell(s) você deseja instalar?" "Digite sua escolha" choice \
    "Zsh apenas" \
    "Fish apenas" \
    "Ambos (Zsh + Fish)" \
    "Nenhum (manter shell atual)"

  case "$choice" in
    1)
      INSTALL_ZSH=1
      INSTALL_FISH=0
      msg ""
      msg "  ✅ Selecionado: Zsh"
      ;;
    2)
      INSTALL_ZSH=0
      INSTALL_FISH=1
      msg ""
      msg "  ✅ Selecionado: Fish"
      ;;
    3)
      INSTALL_ZSH=1
      INSTALL_FISH=1
      msg ""
      msg "  ✅ Selecionado: Zsh + Fish"
      ;;
    4)
      INSTALL_ZSH=0
      INSTALL_FISH=0
      msg ""
      msg "  ⏭️  Nenhum shell será instalado (mantendo shell atual)"
      ;;
  esac

  msg ""
  local shells_selected=()
  [[ $INSTALL_ZSH -eq 1 ]] && shells_selected+=("Zsh")
  [[ $INSTALL_FISH -eq 1 ]] && shells_selected+=("Fish")

  if [[ ${#shells_selected[@]} -gt 0 ]]; then
    print_selection_summary "🐚 Shells" "${shells_selected[@]}"
  else
    print_selection_summary "🐚 Shells" "(nenhum)"
  fi
  msg ""
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
      ;;
    macos)
      msg "  • git              - Sistema de controle de versão"
      msg "  • curl             - Ferramenta para transferência de dados"
      msg "  • wget             - Download de arquivos"
      msg ""
      msg "  ℹ️  Instalação via Homebrew"
      ;;
    windows)
      msg "  • Git              - Sistema de controle de versão"
      msg "  • Windows Terminal - Terminal moderno da Microsoft"
      msg ""
      msg "  ℹ️  Instalação via winget"
      ;;
  esac

  msg ""
  msg "✅ Estas dependências são fundamentais para o funcionamento correto do instalador."
  msg ""
}
