#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# Globals declarados em install.sh; text utilities em lib/utils.sh

# ═══════════════════════════════════════════════════════════
# Funções de compatibilidade
# ═══════════════════════════════════════════════════════════

_has_modern_ui() {
  declare -F ui_select_multiple >/dev/null 2>&1
}

menu_header() {
  # Delega para ui_section (components.sh) quando disponível
  if declare -F ui_section >/dev/null 2>&1; then
    ui_section "$1"
  else
    local title="$1"
    msg ""
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  $title"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
}

menu_select_single() {
  local title="$1"
  local prompt="$2"
  local out_var="$3"
  shift 3
  local options=("$@")

  if _has_modern_ui; then
    local result=""
    ui_select_single "$title" result "${options[@]}"
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

select_multiple_items() {
  local title="$1"
  local out_var="$2"
  shift 2
  local options=("$@")

  if _has_modern_ui; then
    ui_select_multiple "$title" "$out_var" "${options[@]}"
    return
  fi

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

  declare -n array_ref="$out_var"
  array_ref=("${selected[@]}")
  unset -n array_ref
}

confirm_selection() {
  local title="$1"
  shift
  local items=("$@")

  local term_w
  term_w=$(tput cols 2>/dev/null || echo 80)
  local box_w=$((term_w > 70 ? 70 : term_w - 4))
  [[ $box_w -lt 40 ]] && box_w=40
  local inner_w=$((box_w - 2))
  local content_w=$((box_w - 6))

  local h_line
  h_line=$(printf '─%.0s' $(seq 1 "$inner_w"))

  echo ""

  local title_visual_w
  title_visual_w=$(_visible_len "$title")
  local fill_len=$((inner_w - title_visual_w - 2))
  [[ $fill_len -lt 0 ]] && fill_len=0
  local fill
  fill=$(printf '─%.0s' $(seq 1 "$fill_len"))
  echo -e "${UI_CYAN}╭─ ${UI_BOLD}$title${UI_RESET}${UI_CYAN} ${fill}╮${UI_RESET}"

  if [[ ${#items[@]} -gt 0 ]]; then
    for item in "${items[@]}"; do
      local item_vis
      item_vis=$(_visible_len "$item")
      if [[ $item_vis -le $content_w ]]; then
        local pad=$((inner_w - 4 - item_vis))
        [[ $pad -lt 0 ]] && pad=0
        echo -e "${UI_CYAN}│${UI_RESET}  ${UI_GREEN}✓${UI_RESET} ${item}$(printf '%*s' "$pad" '')${UI_CYAN}│${UI_RESET}"
      else
        local current_line=""
        local first_line=1
        local words=()

        read -ra words <<< "$item"

        for word in "${words[@]}"; do
          if [[ -z "$current_line" ]]; then
            current_line="$word"
          else
            local cur_vis word_vis
            cur_vis=$(_visible_len "$current_line")
            word_vis=$(_visible_len "$word")
            if (( cur_vis + 1 + word_vis <= content_w )); then
              current_line="$current_line $word"
            else
              local pad=$(( inner_w - 4 - cur_vis ))
              [[ $pad -lt 0 ]] && pad=0
              if [[ $first_line -eq 1 ]]; then
                echo -e "${UI_CYAN}│${UI_RESET}  ${UI_GREEN}✓${UI_RESET} ${current_line}$(printf '%*s' "$pad" '')${UI_CYAN}│${UI_RESET}"
                first_line=0
              else
                echo -e "${UI_CYAN}│${UI_RESET}    ${current_line}$(printf '%*s' "$pad" '')${UI_CYAN}│${UI_RESET}"
              fi
              current_line="$word"
            fi
          fi
        done

        if [[ -n "$current_line" ]]; then
          local cur_vis
          cur_vis=$(_visible_len "$current_line")
          local pad=$(( inner_w - 4 - cur_vis ))
          [[ $pad -lt 0 ]] && pad=0
          if [[ $first_line -eq 1 ]]; then
            echo -e "${UI_CYAN}│${UI_RESET}  ${UI_GREEN}✓${UI_RESET} ${current_line}$(printf '%*s' "$pad" '')${UI_CYAN}│${UI_RESET}"
          else
            echo -e "${UI_CYAN}│${UI_RESET}    ${current_line}$(printf '%*s' "$pad" '')${UI_CYAN}│${UI_RESET}"
          fi
        fi
      fi
    done
  else
    local empty_msg="(nenhum selecionado)"
    local pad=$((inner_w - 2 - ${#empty_msg}))
    [[ $pad -lt 0 ]] && pad=0
    echo -e "${UI_CYAN}│${UI_RESET}  ${UI_DIM}${empty_msg}${UI_RESET}$(printf '%*s' "$pad" '')${UI_CYAN}│${UI_RESET}"
  fi

  echo -e "${UI_CYAN}├${h_line}┤${UI_RESET}"
  local action_text="Enter Continuar    B Voltar e editar"
  local action_pad=$((inner_w - 2 - ${#action_text}))
  [[ $action_pad -lt 0 ]] && action_pad=0
  echo -e "${UI_CYAN}│${UI_RESET}  ${UI_GREEN}Enter${UI_RESET} Continuar    ${UI_YELLOW}B${UI_RESET} Voltar e editar$(printf '%*s' "$action_pad" '')${UI_CYAN}│${UI_RESET}"
  echo -e "${UI_CYAN}╰${h_line}╯${UI_RESET}"
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
      btop)       tools_with_desc+=("btop       - Monitor de recursos (CPU, RAM, disco, rede, GPU) ⭐") ;;
      tmux)       tools_with_desc+=("tmux       - Multiplexador de terminal (sessões, janelas, painéis)") ;;
      atuin)      tools_with_desc+=("atuin      - Histórico de shell sincronizado e com busca avançada") ;;
      tealdeer)   tools_with_desc+=("tealdeer   - tldr em Rust - man pages simplificadas e práticas") ;;
      yazi)       tools_with_desc+=("yazi       - File manager moderno em Rust (substitui ranger)") ;;
      procs)      tools_with_desc+=("procs      - ps moderno com cores e informações detalhadas") ;;
      dust)       tools_with_desc+=("dust       - du visual e intuitivo (uso de disco)") ;;
      sd)         tools_with_desc+=("sd         - sed intuitivo e moderno (find & replace)") ;;
      tokei)      tools_with_desc+=("tokei      - Contador de linhas de código por linguagem") ;;
      hyperfine)  tools_with_desc+=("hyperfine  - Benchmarking CLI (medir tempo de comandos)") ;;
      mise)       tools_with_desc+=("mise       - Runtime version manager (node, python, ruby...)") ;;
      bottom)     tools_with_desc+=("bottom     - Monitor de sistema TUI em Rust (alternativa a btop)") ;;
      duf)        tools_with_desc+=("duf        - Visualizador de uso de disco moderno") ;;
      gping)      tools_with_desc+=("gping      - Ping com gráfico em tempo real") ;;
      difftastic) tools_with_desc+=("difftastic - Diff estrutural que entende a linguagem") ;;
      zellij)     tools_with_desc+=("zellij     - Multiplexador de terminal moderno") ;;
      xh)         tools_with_desc+=("xh         - Cliente HTTP moderno (alternativa ao curl)") ;;
      gitui)      tools_with_desc+=("gitui      - Interface Git TUI rápida em Rust") ;;
      broot)      tools_with_desc+=("broot      - Navegador de árvore interativo (alternativa a tree)") ;;
      glow)       tools_with_desc+=("glow       - Renderizador de Markdown no terminal") ;;
      navi)       tools_with_desc+=("navi       - Cheatsheets interativos para CLI") ;;
      topgrade)   tools_with_desc+=("topgrade   - Atualiza tudo (pkgs/rust/mise/brew...) de uma vez") ;;
      *)          tools_with_desc+=("$tool") ;;
    esac
  done

  while true; do
    SELECTED_CLI_TOOLS=()
    clear_screen
    show_section_header "🛠️  FERRAMENTAS CLI - Linha de Comando"

    msg "Ferramentas modernas para melhorar sua experiência na linha de comando."
    msg ""

    local selected_desc=()
    select_multiple_items "🛠️  Selecione as Ferramentas CLI" selected_desc "${tools_with_desc[@]}"

    for item in "${selected_desc[@]}"; do
      local tool_name
      tool_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_CLI_TOOLS+=("$tool_name")
    done

    if confirm_selection "🛠️  Ferramentas CLI" "${SELECTED_CLI_TOOLS[@]}"; then
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
      codex)       tools_with_desc+=("codex       - Codex CLI da OpenAI (assistente de código no terminal)") ;;
      gemini-cli)  tools_with_desc+=("gemini-cli  - CLI oficial do Gemini (Google)") ;;
      opencode)    tools_with_desc+=("opencode    - Agente de terminal open-source multi-model") ;;
      crush)       tools_with_desc+=("crush       - Agente de terminal da Charm (multi-model)") ;;
      claude-code) tools_with_desc+=("claude-code - CLI oficial do Claude AI (Anthropic)") ;;
      aider)       tools_with_desc+=("aider       - AI pair programming (25K+ GitHub stars)") ;;
      continue)    tools_with_desc+=("continue    - Open-source AI assistant para IDEs") ;;
      goose)       tools_with_desc+=("goose       - AI agent framework (Block/Square)") ;;
      ollama)      tools_with_desc+=("ollama      - Runtime LLM local (modelos open-source)") ;;
      promptfoo)   tools_with_desc+=("promptfoo   - Framework de eval/testing para LLMs") ;;
      llm)         tools_with_desc+=("llm         - Chamada de modelo via pipe, para scripts") ;;
      *)           tools_with_desc+=("$tool") ;;
    esac
  done

  while true; do
    SELECTED_IA_TOOLS=()
    clear_screen
    show_section_header "🤖 FERRAMENTAS IA - Desenvolvimento Assistido"

    msg "Ferramentas que usam IA para auxiliar no desenvolvimento."
    msg ""
    msg "⚠️  Algumas ferramentas podem exigir configuração adicional"
    msg "   (API keys, login, instalação manual)."
    msg ""

    local selected_desc=()
    select_multiple_items "🤖 Selecione as Ferramentas IA" selected_desc "${tools_with_desc[@]}"

    for item in "${selected_desc[@]}"; do
      local tool_name
      tool_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_IA_TOOLS+=("$tool_name")
    done

    if confirm_selection "🤖 Ferramentas IA" "${SELECTED_IA_TOOLS[@]}"; then
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
        # Kitty não tem build oficial Windows — omitir do menu
        [[ "$TARGET_OS" != "windows" ]] && available_terminals+=("Kitty      - $kitty_desc")
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
      msg "  • ca-certificates  - Certificados SSL/TLS"
      msg "  • git              - Sistema de controle de versão"
      msg_wrap "• curl — ferramenta para transferência de dados" 2
      msg "  • wget             - Download de arquivos"
      msg "  • gnupg            - Criptografia e assinaturas digitais"
      msg "  • unzip            - Descompressão de arquivos"
      msg "  • fontconfig       - Gerenciamento de fontes"
      msg "  • imagemagick      - Preview de imagens e temas"
      msg "  • chafa            - Preview de imagens no terminal"
      msg_wrap "• fzf — interface de seleção fuzzy (UI moderna)" 2
      msg_wrap "• gum — UI interativa para terminal (fallback)" 2
      ;;
    macos)
      msg "  • git              - Sistema de controle de versão"
      msg "  • curl             - Ferramenta para transferência de dados"
      msg "  • wget             - Download de arquivos"
      msg "  • imagemagick      - Redimensionar prévias de imagem"
      msg "  • chafa            - Preview de imagens no terminal (auto-detecta protocolo)"
      msg "  • fzf              - Interface de seleção fuzzy (UI moderna)"
      msg "  • gum              - UI interativa para terminal (fallback)"
      msg ""
      msg "  ℹ️  Instalação via Homebrew"
      ;;
    windows)
      msg "  • Git              - Sistema de controle de versão"
      msg "  • Windows Terminal - Terminal moderno da Microsoft"
      msg "  • ImageMagick      - Redimensionar prévias de imagem"
      msg "  • chafa            - Preview de imagens no terminal"
      msg "  • fzf              - Interface de seleção fuzzy (UI moderna)"
      msg "  • gum              - UI interativa para terminal (fallback)"
      msg ""
      msg "  ℹ️  Instalação via winget"
      ;;
  esac

  msg ""
  msg_wrap "✅ Estas dependências são fundamentais para o funcionamento correto do instalador."
  msg_wrap "ℹ️  Após continuar, a instalação das dependências será iniciada."
  msg ""
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO DE SELEÇÕES INTERATIVAS
# ══════════════════════════════════════════════════════════════════════════════

review_selections() {
  local choice=""
  while true; do
    if declare -F clear_screen >/dev/null; then
      clear_screen
    else
      clear
    fi

    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)

    local width=$((term_width > 98 ? 92 : term_width - 6))
    [[ $width -lt 48 ]] && width=48
    local left_pad=2
    local rv_divider_color="${UI_OVERLAY1:-$UI_BORDER}"
    local rv_section_color="${UI_MAUVE:-$UI_ACCENT}"
    local rv_label_color="${UI_SUBTEXT1:-$UI_MUTED}"

    local total_pkgs total_cfgs
    total_pkgs=$(_count_total_packages)
    total_cfgs=$(_count_configs_to_copy)

    local actions_to_do=()
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]] && actions_to_do+=("Git")
    [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]] && actions_to_do+=("P10k")
    [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && actions_to_do+=("Starship")
    [[ ${INSTALL_OH_MY_POSH:-0} -eq 1 ]] && actions_to_do+=("OMP")
    [[ ${COPY_SSH_KEYS:-0} -eq 1 ]] && actions_to_do+=("SSH")

    local so_color="$UI_TEAL"
    local so_icon="🐧"
    local so_name="${TARGET_OS:-linux}"
    if [[ "${TARGET_OS:-linux}" == "macos" ]]; then
      so_color="$UI_PEACH"
      so_icon="🍎"
      so_name="macOS"
    elif [[ "${TARGET_OS:-linux}" == "windows" ]]; then
      so_color="$UI_BLUE"
      so_icon="⊞"
      so_name="Windows"
    elif [[ "${TARGET_OS:-linux}" == "wsl2" ]]; then
      so_color="$UI_SKY"
      so_name="WSL2"
    else
      so_name="Linux"
    fi

    echo ""
    _rv_hbar "$width"
    printf "%*s%b\n" "$left_pad" "" "  ${UI_GREEN}${UI_BOLD}📋 RESUMO FINAL${UI_RESET}"
    echo ""
    printf "%*s%b\n" "$left_pad" "" "  ${UI_SUBTEXT1}Revise o plano abaixo. Use ${UI_YELLOW}${UI_BOLD}0-8${UI_RESET}${UI_SUBTEXT1} para ajustar qualquer grupo antes de iniciar.${UI_RESET}"
    _rv_hbar "$width"
    echo ""

    local selected_shells=()
    [[ ${INSTALL_ZSH:-0} -eq 1 ]] && selected_shells+=("zsh")
    [[ ${INSTALL_FISH:-0} -eq 1 ]] && selected_shells+=("fish")
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && selected_shells+=("nushell")

    local themes_selected=()
    [[ ${INSTALL_OH_MY_ZSH:-0} -eq 1 ]] && themes_selected+=("OMZ+P10k")
    if [[ ${INSTALL_STARSHIP:-0} -eq 1 ]]; then
      local starship_label="Starship"
      if [[ "${SELECTED_STARSHIP_PRESET:-}" == "catppuccin-powerline" ]]; then
        if [[ -n "${SELECTED_CATPPUCCIN_FLAVOR:-}" ]]; then
          local starship_flavor="${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}"
          starship_label="Starship Catppuccin (${starship_flavor^})"
        else
          starship_label="Starship Catppuccin"
        fi
      elif [[ -n "${SELECTED_STARSHIP_PRESET:-}" ]]; then
        local preset_display
        case "${SELECTED_STARSHIP_PRESET}" in
          tokyo-night) preset_display="Tokyo Night" ;;
          gruvbox-rainbow) preset_display="Gruvbox Rainbow" ;;
          pastel-powerline) preset_display="Pastel Powerline" ;;
          nerd-font-symbols) preset_display="Nerd Font Symbols" ;;
          plain-text-symbols) preset_display="Plain Text" ;;
          *) preset_display="${SELECTED_STARSHIP_PRESET}" ;;
        esac
        starship_label="Starship ($preset_display)"
      fi
      themes_selected+=("$starship_label")
    fi
    [[ ${INSTALL_OH_MY_POSH:-0} -eq 1 ]] && themes_selected+=("OMP")

    _rv_lv() {
      local lbl_w="$1" label="$2" empty_val="$3"
      shift 3
      local items=("$@")
      local pad_left="${left_pad:-0}"
      local label_color="${rv_label_color:-$UI_MUTED}"
      local label_str="${label}:"
      local label_vis pad label_col
      label_vis=$(_visible_len "$label_str")
      pad=$(( lbl_w - label_vis ))
      [[ $pad -lt 0 ]] && pad=0
      printf -v label_col '%s%*s' "$label_str" "$pad" ''
      local value_w=$(( width - lbl_w - 4 ))
      [[ $value_w -lt 10 ]] && value_w=10
      if [[ ${#items[@]} -eq 0 ]]; then
        printf "%*s  ${label_color}%s${UI_RESET}${UI_DIM}%s${UI_RESET}\n" "$pad_left" "" "$label_col" "$empty_val"
        return
      fi
      local -a lines=()
      local line="" item candidate
      for item in "${items[@]}"; do
        if [[ -z "$line" ]]; then
          line="$item"
          continue
        fi
        candidate="${line}, ${item}"
        if (( $(_visible_len "$candidate") > value_w )); then
          lines+=("${line},")
          line="$item"
        else
          line="$candidate"
        fi
      done
      [[ -n "$line" ]] && lines+=("$line")
      printf "%*s  ${label_color}%s${UI_RESET}${UI_TEXT}%s${UI_RESET}\n" "$pad_left" "" "$label_col" "${lines[0]}"
      local indent
      printf -v indent '%*s' "$((lbl_w + 2))" ''
      local i
      for (( i=1; i<${#lines[@]}; i++ )); do
        printf "%*s  %s${UI_TEXT}%s${UI_RESET}\n" "$pad_left" "" "$indent" "${lines[i]}"
      done
    }

    _rv_kv() {
      local lbl_w="$1" label="$2" value="$3"
      local pad_left="${left_pad:-0}"
      local label_color="${rv_label_color:-$UI_MUTED}"
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
      printf "%*s  ${label_color}%s${UI_RESET}%b\n" "$pad_left" "" "$label_col" "${lines[0]}"
      local indent
      printf -v indent '%*s' "$((lbl_w + 2))" ''
      local i
      for (( i=1; i<${#lines[@]}; i++ )); do
        printf "%*s  %s%b\n" "$pad_left" "" "$indent" "${lines[i]}"
      done
    }

    _rv_cfg_item() {
      local available="$1" selected_flag="$2" name="$3"
      if [[ $available -eq 1 ]]; then
        if [[ $selected_flag -eq 1 ]]; then
          echo "${UI_GREEN}${UI_BOLD}✓${UI_RESET} ${UI_TEXT}${name}${UI_RESET}"
        else
          echo "${UI_DIM}✗ ${name}${UI_RESET}"
        fi
      fi
    }

    _rv_cfg_row() {
      local lbl_w="$1" label="$2" arr_name="$3"
      local -n _cfg_ref="$arr_name"
      [[ ${#_cfg_ref[@]} -eq 0 ]] && return
      local pad_left="${left_pad:-0}"
      local label_color="${rv_label_color:-$UI_MUTED}"
      local label_str="${label}:"
      local label_vis pad label_col
      label_vis=$(_visible_len "$label_str")
      pad=$(( lbl_w - label_vis ))
      [[ $pad -lt 0 ]] && pad=0
      printf -v label_col '%s%*s' "$label_str" "$pad" ''
      local value_w=$(( width - lbl_w - 4 ))
      [[ $value_w -lt 10 ]] && value_w=10
      local -a lines=()
      local line="" item candidate
      for item in "${_cfg_ref[@]}"; do
        if [[ -z "$line" ]]; then
          line="$item"
          continue
        fi
        candidate="${line}  ${item}"
        if (( $(_visible_len "$candidate") > value_w )); then
          lines+=("$line")
          line="$item"
        else
          line="$candidate"
        fi
      done
      [[ -n "$line" ]] && lines+=("$line")
      printf "%*s  ${label_color}%s${UI_RESET}%b\n" "$pad_left" "" "$label_col" "${lines[0]}"
      local indent
      printf -v indent '%*s' "$((lbl_w + 2))" ''
      local i
      for (( i=1; i<${#lines[@]}; i++ )); do
        printf "%*s  %s%b\n" "$pad_left" "" "$indent" "${lines[i]}"
      done
    }

    _rv_menu_cell() {
      local num="$1" label="$2" cell_w="$3" badge="${4:-}"
      local badge_str=""
      if [[ -n "$badge" ]]; then
        badge_str=" (${badge})"
      fi
      local cell_plain="${num} ${label}${badge_str}"
      local pad=$(( cell_w - $(_visible_len "$cell_plain") ))
      [[ $pad -lt 0 ]] && pad=0
      if [[ -n "$badge" ]]; then
        printf "${UI_YELLOW}${UI_BOLD}%s${UI_RESET} ${UI_SUBTEXT1}%s${UI_RESET} ${UI_SUBTEXT0}(%s)${UI_RESET}%*s" "$num" "$label" "$badge" "$pad" ""
      else
        printf "${UI_YELLOW}${UI_BOLD}%s${UI_RESET} ${UI_SUBTEXT1}%s${UI_RESET}%*s" "$num" "$label" "$pad" ""
      fi
    }

    local env_label_w tools_label_w apps_label_w cfg_label_w
    env_label_w=$(_rv_measure_label_width 10 "Shells" "Terminais" "Temas" "Fontes")
    tools_label_w=$(_rv_measure_label_width 10 "CLI" "IA" "Runtimes")
    apps_label_w=$(_rv_measure_label_width 12 "IDEs" "Navegadores" "Dev Tools" "Bancos" "Produtividade" "Comunicação" "Mídia" "Utilitários")
    cfg_label_w=$(_rv_measure_label_width 12 "Shells" "Terminais" "Editores" "Runtimes" "Ferramentas")

    _rv_kv 15 "Pacotes" "${UI_PEACH}${UI_BOLD}${total_pkgs}${UI_RESET} ${UI_TEXT}selecionados${UI_RESET}"
    _rv_kv 15 "Configs" "${UI_BLUE}${UI_BOLD}${total_cfgs}${UI_RESET} ${UI_TEXT}para copiar${UI_RESET}"
    _rv_kv 15 "Sistema" "${so_color}${UI_BOLD}${so_icon} ${so_name}${UI_RESET}"
    if [[ ${#actions_to_do[@]} -gt 0 ]]; then
      _rv_kv 15 "Ações extras" "${UI_TEXT}$(_join_items "${actions_to_do[@]}")${UI_RESET}"
    fi
    if [[ -n "$BACKUP_DIR" ]]; then
      _rv_kv 15 "Backup" "${UI_SUBTEXT0}${BACKUP_DIR}${UI_RESET}"
    else
      _rv_kv 15 "Backup" "${UI_SUBTEXT0}(criado sob demanda, se necessário)${UI_RESET}"
    fi
    echo ""

    local env_count=$(( ${#selected_shells[@]} + ${#SELECTED_TERMINALS[@]} + ${#themes_selected[@]} + ${#SELECTED_NERD_FONTS[@]} ))
    _rv_div "$width" "🏠 AMBIENTE" "$env_count"
    _rv_lv "$env_label_w" "Shells"    "(nenhum)"  "${selected_shells[@]}"
    _rv_lv "$env_label_w" "Terminais" "(nenhum)"  "${SELECTED_TERMINALS[@]}"
    _rv_lv "$env_label_w" "Temas"     "(nenhum)"  "${themes_selected[@]}"
    _rv_lv "$env_label_w" "Fontes"    "(nenhuma)" "${SELECTED_NERD_FONTS[@]}"
    echo ""

    local tools_count=$(( ${#SELECTED_CLI_TOOLS[@]} + ${#SELECTED_IA_TOOLS[@]} + ${#SELECTED_RUNTIMES[@]} ))
    _rv_div "$width" "🔧 FERRAMENTAS" "$tools_count"
    _rv_lv "$tools_label_w" "CLI"      "(nenhuma)" "${SELECTED_CLI_TOOLS[@]}"
    _rv_lv "$tools_label_w" "IA"       "(nenhuma)" "${SELECTED_IA_TOOLS[@]}"
    _rv_lv "$tools_label_w" "Runtimes" "(nenhum)"  "${SELECTED_RUNTIMES[@]}"
    echo ""

    local gui_total=0
    gui_total=$((${#SELECTED_IDES[@]} + ${#SELECTED_BROWSERS[@]} + ${#SELECTED_DEV_TOOLS[@]} + \
                 ${#SELECTED_DATABASES[@]} + ${#SELECTED_PRODUCTIVITY[@]} + \
                 ${#SELECTED_COMMUNICATION[@]} + ${#SELECTED_MEDIA[@]} + ${#SELECTED_UTILITIES[@]}))
    if [[ $gui_total -gt 0 ]]; then
      _rv_div "$width" "🖥 APPS GUI" "$gui_total"
      [[ ${#SELECTED_IDES[@]} -gt 0 ]]          && _rv_lv "$apps_label_w" "IDEs"          "" "${SELECTED_IDES[@]}"
      [[ ${#SELECTED_BROWSERS[@]} -gt 0 ]]      && _rv_lv "$apps_label_w" "Navegadores"   "" "${SELECTED_BROWSERS[@]}"
      [[ ${#SELECTED_DEV_TOOLS[@]} -gt 0 ]]     && _rv_lv "$apps_label_w" "Dev Tools"     "" "${SELECTED_DEV_TOOLS[@]}"
      [[ ${#SELECTED_DATABASES[@]} -gt 0 ]]     && _rv_lv "$apps_label_w" "Bancos"        "" "${SELECTED_DATABASES[@]}"
      [[ ${#SELECTED_PRODUCTIVITY[@]} -gt 0 ]]  && _rv_lv "$apps_label_w" "Produtividade" "" "${SELECTED_PRODUCTIVITY[@]}"
      [[ ${#SELECTED_COMMUNICATION[@]} -gt 0 ]] && _rv_lv "$apps_label_w" "Comunicação"   "" "${SELECTED_COMMUNICATION[@]}"
      [[ ${#SELECTED_MEDIA[@]} -gt 0 ]]         && _rv_lv "$apps_label_w" "Mídia"         "" "${SELECTED_MEDIA[@]}"
      [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]]     && _rv_lv "$apps_label_w" "Utilitários"   "" "${SELECTED_UTILITIES[@]}"
      echo ""
    fi

    # ── COPIAR CONFIGURAÇÕES ──
    local cfg_shells=()
    [[ ${INSTALL_ZSH:-0} -eq 1 ]]     && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_ZSH_CONFIG:-0}"    "Zsh")")
    [[ ${INSTALL_FISH:-0} -eq 1 ]]    && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_FISH_CONFIG:-0}"   "Fish")")
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_NUSHELL_CONFIG:-0}" "Nushell")")
    [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]] && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_STARSHIP_CONFIG:-0}" "Starship")")

    local cfg_terminals=()
    for term in "${SELECTED_TERMINALS[@]}"; do
      case "$term" in
        ghostty)   cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_TERMINAL_CONFIG:-0}"  "ghostty")") ;;
        kitty)     cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_KITTY_CONFIG:-0}"     "kitty")") ;;
        alacritty) cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_ALACRITTY_CONFIG:-0}" "alacritty")") ;;
        wezterm)   cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_WEZTERM_CONFIG:-0}"   "wezterm")") ;;
      esac
    done

    local cfg_editors=()
    local has_neovim=0 has_vscode=0 has_zed=0 has_helix=0
    for ide in "${SELECTED_IDES[@]}"; do
      case "$ide" in
        neovim) has_neovim=1 ;; vscode) has_vscode=1 ;;
        zed)    has_zed=1    ;; helix)  has_helix=1   ;;
      esac
    done
    [[ $has_neovim -eq 1 ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_NVIM_CONFIG:-0}"     "Neovim")")
    [[ $has_vscode -eq 1 ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_VSCODE_SETTINGS:-0}" "VSCode")")
    [[ $has_zed -eq 1    ]] && [[ -f "$CONFIG_SHARED/zed/settings.json" ]]  && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_ZED_CONFIG:-0}"   "Zed")")
    [[ $has_helix -eq 1  ]] && [[ -f "$CONFIG_SHARED/helix/config.toml" ]]  && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_HELIX_CONFIG:-0}" "Helix")")

    local cfg_tools=()
    local has_tmux=0 has_lazygit=0 has_yazi=0 has_btop=0 has_bat=0 has_direnv=0
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do
      case "$tool" in
        tmux)    has_tmux=1    ;; lazygit) has_lazygit=1 ;;
        yazi)    has_yazi=1    ;; btop)    has_btop=1     ;;
        bat)     has_bat=1     ;; direnv)  has_direnv=1   ;;
      esac
    done
    [[ $has_tmux -eq 1    ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_TMUX_CONFIG:-0}"    "tmux")")
    [[ $has_lazygit -eq 1 ]] && [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]  && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_LAZYGIT_CONFIG:-0}" "lazygit")")
    [[ $has_yazi -eq 1    ]] && [[ -d "$CONFIG_SHARED/yazi" ]]                 && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_YAZI_CONFIG:-0}"    "yazi")")
    [[ $has_btop -eq 1    ]] && [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]       && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_BTOP_CONFIG:-0}"    "btop")")
    [[ $has_bat -eq 1     ]] && [[ -f "$CONFIG_SHARED/bat/config" ]]           && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_BAT_CONFIG:-0}"     "bat")")
    [[ $has_direnv -eq 1  ]] && [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]     && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_DIRENV_CONFIG:-0}"  "direnv")")
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]]                                            && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_GIT_CONFIG:-0}"     "Git")")
    [[ -n "$(_resolve_ssh_source)" ]]                                          && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_SSH_KEYS:-0}"      "SSH Keys")")

    local cfg_runtime=()
    [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && cfg_runtime+=("$(_rv_cfg_item 1 "${COPY_MISE_CONFIG:-0}"     "Mise")")

    _rv_div "$width" "📋 COPIAR CONFIGURAÇÕES" "$total_cfgs"
    _rv_cfg_row "$cfg_label_w" "Shells"      "cfg_shells"
    _rv_cfg_row "$cfg_label_w" "Terminais"   "cfg_terminals"
    _rv_cfg_row "$cfg_label_w" "Editores"    "cfg_editors"
    _rv_cfg_row "$cfg_label_w" "Runtimes"    "cfg_runtime"
    _rv_cfg_row "$cfg_label_w" "Ferramentas" "cfg_tools"

    local has_any_cfg=0
    [[ ${#cfg_shells[@]} -gt 0    || ${#cfg_editors[@]} -gt 0   || \
       ${#cfg_tools[@]} -gt 0     || ${#cfg_terminals[@]} -gt 0 || \
       ${#cfg_runtime[@]} -gt 0 ]] && has_any_cfg=1
    if [[ $has_any_cfg -eq 0 ]]; then
      printf "%*s  ${UI_SUBTEXT0}(nenhuma configuração disponível)${UI_RESET}\n" "$left_pad" ""
    fi

    echo ""
    _rv_div "$width" "✏️ AJUSTAR SELEÇÕES"
    printf "%*s%b\n" "$left_pad" "" "  ${UI_SUBTEXT1}Digite o número da seção que deseja revisar:${UI_RESET}"
    echo ""

    local menu_numbers=(0 1 2 3 4 5 6 7 8)
    local menu_labels=("Configs" "Shells" "Fontes" "Terminais" "CLI" "IA" "Apps GUI" "Runtimes" "Git")
    local shells_count=${#selected_shells[@]}
    local git_badge=""
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]] && git_badge="✓"
    local menu_badges=("$total_cfgs" "$shells_count" "${#SELECTED_NERD_FONTS[@]}" "${#SELECTED_TERMINALS[@]}" "${#SELECTED_CLI_TOOLS[@]}" "${#SELECTED_IA_TOOLS[@]}" "$gui_total" "${#SELECTED_RUNTIMES[@]}" "$git_badge")
    local menu_cols=3
    [[ $width -lt 64 ]] && menu_cols=2
    [[ $width -lt 48 ]] && menu_cols=1
    local menu_gap=3
    local menu_cell_w=$(( (width - (menu_gap * (menu_cols - 1)) - 2) / menu_cols ))
    [[ $menu_cell_w -lt 16 ]] && menu_cell_w=16
    local i
    for (( i=0; i<${#menu_numbers[@]}; i++ )); do
      if (( i % menu_cols == 0 )); then
        printf "%*s  " "$left_pad" ""
      fi
      _rv_menu_cell "${menu_numbers[i]}" "${menu_labels[i]}" "$menu_cell_w" "${menu_badges[i]}"
      if (( (i + 1) % menu_cols == 0 || i == ${#menu_numbers[@]} - 1 )); then
        echo ""
      else
        printf "%*s" "$menu_gap" ""
      fi
    done
    echo ""
    printf "%*s  ${UI_GREEN}${UI_BOLD}⏎ Enter${UI_RESET} ${UI_TEXT}iniciar instalação${UI_RESET}    ${UI_SUBTEXT0}S sair${UI_RESET}\n" "$left_pad" ""

    _rv_hbar "$width"
    echo ""
    read -r -p "$(printf '%*s  → ' "$left_pad" '')" choice

    case "$choice" in
      ""|c|C)
        break
        ;;
      s|S)
        msg ""
        msg "⏹️  Instalação cancelada pelo usuário."
        msg ""
        exit 0
        ;;
      1)
        ask_shells
        ask_nerd_fonts
        ask_themes
        [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && ask_oh_my_zsh_plugins
        [[ $INSTALL_STARSHIP -eq 1 ]] && ask_starship_preset
        [[ $INSTALL_OH_MY_POSH -eq 1 ]] && ask_oh_my_posh_theme
        [[ $INSTALL_FISH -eq 1 ]] && ask_fish_plugins
        ;;
      2)
        ask_nerd_fonts
        ;;
      3)
        ask_terminals
        ;;
      4)
        ask_cli_tools
        ;;
      5)
        ask_ia_tools
        ;;
      6)
        ask_gui_apps
        ;;
      7)
        ask_runtimes
        ;;
      8)
        ask_git_configuration
        ;;
      0)
        _toggle_configs
        ;;
      *)
        msg "  ⚠️ Opção inválida."
        sleep 1
        ;;
    esac
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# TOGGLE CONFIGS — toggle inline rápido no RESUMO FINAL (opção 0)
# ══════════════════════════════════════════════════════════════════════════════
_toggle_configs() {
  local cfg_names=()
  local cfg_keys=()
  local cfg_labels=()

  [[ ${INSTALL_ZSH:-0} -eq 1 ]]      && cfg_names+=("Zsh")      && cfg_keys+=("COPY_ZSH_CONFIG")
  [[ ${INSTALL_FISH:-0} -eq 1 ]]     && cfg_names+=("Fish")     && cfg_keys+=("COPY_FISH_CONFIG")
  [[ ${INSTALL_NUSHELL:-0} -eq 1 ]]  && cfg_names+=("Nushell")  && cfg_keys+=("COPY_NUSHELL_CONFIG")
  [[ ${GIT_CONFIGURE:-0} -eq 1 ]]    && cfg_names+=("Git")      && cfg_keys+=("COPY_GIT_CONFIG")
  [[ -n "$(_resolve_ssh_source)" ]]  && cfg_names+=("SSH Keys")  && cfg_keys+=("COPY_SSH_KEYS")

  local _ide
  for _ide in "${SELECTED_IDES[@]}"; do
    case "$_ide" in
      neovim)       [[ -d "$CONFIG_SHARED/nvim" ]]                 && cfg_names+=("Neovim")  && cfg_keys+=("COPY_NVIM_CONFIG") ;;
      vscode|cursor) [[ -f "$CONFIG_SHARED/vscode/settings.json" ]] && cfg_names+=("VSCode")  && cfg_keys+=("COPY_VSCODE_SETTINGS") ;;
      zed)          [[ -f "$CONFIG_SHARED/zed/settings.json" ]]    && cfg_names+=("Zed")     && cfg_keys+=("COPY_ZED_CONFIG") ;;
      helix)        [[ -f "$CONFIG_SHARED/helix/config.toml" ]]    && cfg_names+=("Helix")   && cfg_keys+=("COPY_HELIX_CONFIG") ;;
    esac
  done

  local _tool
  for _tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$_tool" in
      tmux)    [[ -d "$CONFIG_SHARED/tmux" ]]                && cfg_names+=("tmux")    && cfg_keys+=("COPY_TMUX_CONFIG") ;;
      lazygit) [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]  && cfg_names+=("lazygit") && cfg_keys+=("COPY_LAZYGIT_CONFIG") ;;
      yazi)    [[ -d "$CONFIG_SHARED/yazi" ]]                 && cfg_names+=("yazi")    && cfg_keys+=("COPY_YAZI_CONFIG") ;;
      btop)    [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]       && cfg_names+=("btop")    && cfg_keys+=("COPY_BTOP_CONFIG") ;;
      bat)     [[ -f "$CONFIG_SHARED/bat/config" ]]           && cfg_names+=("bat")     && cfg_keys+=("COPY_BAT_CONFIG") ;;
      ripgrep) [[ -f "$CONFIG_SHARED/.ripgreprc" ]]           && cfg_names+=("ripgrep") && cfg_keys+=("COPY_RIPGREP_CONFIG") ;;
      direnv)  [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]     && cfg_names+=("direnv")  && cfg_keys+=("COPY_DIRENV_CONFIG") ;;
    esac
  done

  local _ia
  for _ia in "${SELECTED_IA_TOOLS[@]}"; do
    [[ "$_ia" == "aider" ]] && [[ -f "$CONFIG_SHARED/aider/.aider.conf.yml" ]] && cfg_names+=("aider") && cfg_keys+=("COPY_AIDER_CONFIG")
    [[ "$_ia" == "claude-code" ]] && [[ -f "$CONFIG_SHARED/claude/CLAUDE.md" ]] && cfg_names+=("Claude Code") && cfg_keys+=("COPY_CLAUDE_CONFIG")
  done

  local _term
  for _term in "${SELECTED_TERMINALS[@]}"; do
    case "$_term" in
      ghostty)   cfg_names+=("ghostty")   && cfg_keys+=("COPY_TERMINAL_CONFIG") ;;
      kitty)     [[ -f "$CONFIG_SHARED/kitty/kitty.conf" ]]       && cfg_names+=("kitty")     && cfg_keys+=("COPY_KITTY_CONFIG") ;;
      alacritty) [[ -f "$CONFIG_SHARED/alacritty/alacritty.toml" ]] && cfg_names+=("alacritty") && cfg_keys+=("COPY_ALACRITTY_CONFIG") ;;
      wezterm)   [[ -f "$CONFIG_SHARED/wezterm/wezterm.lua" ]]     && cfg_names+=("wezterm")   && cfg_keys+=("COPY_WEZTERM_CONFIG") ;;
    esac
  done

  [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]] && cfg_names+=("Starship") && cfg_keys+=("COPY_STARSHIP_CONFIG")
  [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && cfg_names+=("Mise") && cfg_keys+=("COPY_MISE_CONFIG")

  local _rt
  for _rt in "${SELECTED_RUNTIMES[@]}"; do
    case "$_rt" in
      node)   [[ -f "$CONFIG_SHARED/npm/.npmrc" ]]       && cfg_names+=("npm")   && cfg_keys+=("COPY_NPM_CONFIG") ;;
      python) [[ -f "$CONFIG_SHARED/pip/pip.conf" ]]     && cfg_names+=("pip")   && cfg_keys+=("COPY_PIP_CONFIG") ;;
      rust)   [[ -f "$CONFIG_SHARED/cargo/config.toml" ]] && cfg_names+=("cargo") && cfg_keys+=("COPY_CARGO_CONFIG") ;;
    esac
  done

  local _dt
  for _dt in "${SELECTED_DEV_TOOLS[@]}"; do
    [[ "$_dt" == "docker" ]] && [[ -f "$CONFIG_SHARED/docker/config.json" ]] && cfg_names+=("Docker") && cfg_keys+=("COPY_DOCKER_CONFIG")
  done

  if [[ ${#cfg_names[@]} -eq 0 ]]; then
    msg "  ℹ️  Nenhuma configuração disponível."
    sleep 1
    return
  fi

  while true; do
    clear_screen
    echo ""
    echo -e "  ${UI_ACCENT}${UI_BOLD}📋 Toggle Configs${UI_RESET}  ${UI_MUTED}(digite número para alternar, Enter para voltar)${UI_RESET}"
    echo ""

    local i cols=3
    local col_w=25
    local count=${#cfg_names[@]}

    for (( i=0; i<count; i++ )); do
      local key="${cfg_keys[$i]}"
      local val="${!key:-0}"
      local icon="${UI_DIM}✗${UI_RESET}"
      [[ $val -eq 1 ]] && icon="${UI_GREEN}${UI_BOLD}✓${UI_RESET}"
      local num="${UI_PEACH}${UI_BOLD}$((i+1))${UI_RESET}"
      printf "  ${num} ${icon} ${UI_TEXT}%-16s${UI_RESET}" "${cfg_names[$i]}"
      if (( (i+1) % cols == 0 )); then
        echo ""
      fi
    done
    (( count % cols != 0 )) && echo ""
    echo ""

    local toggle_choice
    read -r -p "  → " toggle_choice

    [[ -z "$toggle_choice" ]] && return

    if [[ "$toggle_choice" =~ ^[0-9]+$ ]] && (( toggle_choice >= 1 && toggle_choice <= count )); then
      local idx=$((toggle_choice - 1))
      local key="${cfg_keys[$idx]}"
      local cur="${!key:-0}"
      if [[ $cur -eq 1 ]]; then
        eval "$key=0"
      else
        eval "$key=1"
      fi
    fi
  done
}
