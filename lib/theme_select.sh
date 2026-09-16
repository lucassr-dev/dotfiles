#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ─────────────────────────────────────────────────────────────────
# theme_select.sh — telas de escolha de tema (fase 4, tarefa C: split
# de lib/themes.sh em tres arquivos, sem mudanca de comportamento).
#
# Le e escreve as globais INSTALL_OH_MY_ZSH, INSTALL_POWERLEVEL10K,
# INSTALL_OH_MY_POSH, INSTALL_STARSHIP, SELECTED_OMZ_PLUGINS,
# SELECTED_OMZ_EXTERNAL_PLUGINS, SELECTED_FISH_PLUGINS,
# SELECTED_STARSHIP_PRESET e SELECTED_OMP_THEME — declaradas em
# lib/theme_preview.sh, consumidas depois pelas funcoes install_* de
# lib/themes.sh. Tambem declara e escreve SELECTED_CATPPUCCIN_FLAVOR
# (usada por install_starship em lib/themes.sh).
#
# Le, sem escrever aqui, INSTALL_ZSH/INSTALL_FISH/INSTALL_NUSHELL e
# SELECTED_CLI_TOOLS (globais externas, definidas em install.sh /
# lib/selections.sh antes deste arquivo ser carregado).
#
# Chama funcoes de preview definidas em lib/theme_preview.sh:
# check_preview_support, preview_powerlevel10k, preview_starship_preset,
# preview_oh_my_posh. Por isso lib/theme_preview.sh precisa ser
# carregado antes deste arquivo em install.sh.
# ─────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════
# Tela de seleção de temas
# ═══════════════════════════════════════════════════════════

ask_themes() {
  local has_zsh=${INSTALL_ZSH:-0}
  local has_fish=${INSTALL_FISH:-0}
  local has_nushell=${INSTALL_NUSHELL:-0}

  if [[ $has_zsh -eq 0 ]] && [[ $has_fish -eq 0 ]] && [[ $has_nushell -eq 0 ]]; then
    show_section_header "🎨 TEMAS - Personalize seu Shell"
    msg "  ℹ️  Nenhum shell foi selecionado. Pulando seleção de temas."
    msg ""
    return 0
  fi

  local theme_options_with_desc=()

  if [[ $has_zsh -eq 1 ]]; then
    theme_options_with_desc+=("OhMyZsh-P10k  - [zsh] Oh My Zsh + Powerlevel10k (framework completo)")
  fi

  if [[ $has_zsh -eq 1 ]] || [[ $has_fish -eq 1 ]] || [[ $has_nushell -eq 1 ]]; then
    local compat=""
    [[ $has_zsh -eq 1 ]] && compat="zsh"
    [[ $has_fish -eq 1 ]] && { [[ -n "$compat" ]] && compat="$compat/fish" || compat="fish"; }
    [[ $has_nushell -eq 1 ]] && { [[ -n "$compat" ]] && compat="$compat/nu" || compat="nu"; }
    theme_options_with_desc+=("Starship      - [$compat] Prompt minimalista com presets prontos")
  fi

  if [[ $has_zsh -eq 1 ]] || [[ $has_fish -eq 1 ]] || [[ $has_nushell -eq 1 ]]; then
    local compat=""
    [[ $has_zsh -eq 1 ]] && compat="zsh"
    [[ $has_fish -eq 1 ]] && { [[ -n "$compat" ]] && compat="$compat/fish" || compat="fish"; }
    [[ $has_nushell -eq 1 ]] && { [[ -n "$compat" ]] && compat="$compat/nu" || compat="nu"; }
    theme_options_with_desc+=("OhMyPosh      - [$compat] Prompt configurável com centenas de temas")
  fi

  while true; do
    INSTALL_OH_MY_ZSH=0
    INSTALL_POWERLEVEL10K=0
    INSTALL_OH_MY_POSH=0
    INSTALL_STARSHIP=0
    clear_screen
    show_section_header "🎨 TEMAS - Personalize seu Shell"

    msg "Temas deixam seu terminal bonito e informativo com ícones, cores e informações úteis."
    msg ""
    msg "⚠️  IMPORTANTE:"
    msg "  • Você pode instalar múltiplos temas e alterná-los depois"
    msg "  • Todos os temas requerem Nerd Fonts instaladas"
    msg ""

    check_preview_support || true

    local selected_desc=()
    select_multiple_items "🎨 Selecione os temas para instalar" selected_desc "${theme_options_with_desc[@]}"

    for item in "${selected_desc[@]}"; do
      local theme_id
      theme_id=$(echo "$item" | awk '{print $1}')
      case "$theme_id" in
        "OhMyZsh-P10k")
          INSTALL_OH_MY_ZSH=1
          INSTALL_POWERLEVEL10K=1
          ;;
        "Starship") INSTALL_STARSHIP=1 ;;
        "OhMyPosh") INSTALL_OH_MY_POSH=1 ;;
      esac
    done

    local selected_themes=()
    [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && selected_themes+=("Oh My Zsh + Powerlevel10k")
    [[ $INSTALL_STARSHIP -eq 1 ]] && selected_themes+=("Starship")
    [[ $INSTALL_OH_MY_POSH -eq 1 ]] && selected_themes+=("Oh My Posh")

    if [[ ${#selected_themes[@]} -eq 0 ]]; then
      selected_themes=("(nenhum)")
    fi

    if confirm_selection "🎨 Temas" "${selected_themes[@]}"; then
      if [[ $INSTALL_STARSHIP -eq 1 || $INSTALL_OH_MY_POSH -eq 1 ]]; then
        msg "  ℹ️  As prévias de Starship e Oh My Posh aparecem nas próximas etapas."
        msg ""
      fi

      if [[ $INSTALL_OH_MY_ZSH -eq 1 ]]; then
        clear_screen
        show_section_header "🖼️  PRÉVIA DO TEMA"
        print_selection_summary "🎨 Temas" "${selected_themes[@]}"
        msg ""
        preview_powerlevel10k
        msg ""
        pause_before_next_section "Pressione Enter para continuar..."
      fi
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de plugins do Oh My Zsh
# ═══════════════════════════════════════════════════════════

ask_oh_my_zsh_plugins() {
  [[ $INSTALL_OH_MY_ZSH -eq 0 ]] && return 0

  while true; do
    SELECTED_OMZ_PLUGINS=()
    SELECTED_OMZ_EXTERNAL_PLUGINS=()
    clear_screen
    show_section_header "🔌 PLUGINS - Oh My Zsh"
    msg "Selecione os plugins built-in do Oh My Zsh."
    msg ""

    local omz_plugins_desc=(
      "git - ⭐ Aliases para Git (gst, gco, gp, glog, etc)"
      "sudo - ⭐ ESC 2x adiciona sudo ao comando anterior"
      "extract - ⭐ Comando 'x' extrai qualquer arquivo compactado"
      "z - ⭐ Jump rápido para diretórios frequentes"
      "history - Aliases para busca no histórico (h, hs, hsi)"
      "aliases - Comando 'acs' lista todos os aliases"
      "copypath - Copia o path atual para clipboard"
      "copyfile - Copia conteúdo de arquivo para clipboard"
      "colored-man-pages - Man pages com cores"
      "safe-paste - Previne execução acidental ao colar"
      "jsontools - Ferramentas JSON (pp_json, is_json)"
      "encode64 - Encode/decode base64 (e64, d64)"
      "web-search - Buscar no Google/Bing do terminal"
      "docker - Autocomplete e aliases para Docker"
      "docker-compose - Autocomplete para docker-compose"
      "kubectl - Autocomplete para Kubernetes"
      "terraform - Autocomplete para Terraform"
      "aws - Autocomplete para AWS CLI"
      "gh - Autocomplete para GitHub CLI"
      "node - Autocomplete para Node.js"
      "npm - Autocomplete para npm"
      "yarn - Autocomplete para yarn"
      "python - Aliases para Python (pyfind, pygrep, pyclean)"
      "pip - Autocomplete para pip"
      "golang - Aliases para Go"
      "rust - Autocomplete para Rust/Cargo"
      "composer - Autocomplete para PHP Composer"
      "laravel - Aliases para Laravel Artisan"
      "fzf - Integração com fuzzy finder"
      "tmux - Aliases para tmux (ta, ts, tl, etc)"
      "systemd - Autocomplete para systemctl (Linux)"
      "brew - Autocomplete para Homebrew (macOS)"
      "command-not-found - Sugere pacotes para comandos não encontrados"
    )

    local selected_omz_desc=()
    select_multiple_items "📦 Plugins built-in" selected_omz_desc "${omz_plugins_desc[@]}"
    for item in "${selected_omz_desc[@]}"; do
      local plugin_name
      plugin_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_OMZ_PLUGINS+=("$plugin_name")
    done

    clear_screen
    show_section_header "🔌 PLUGINS EXTERNOS - Oh My Zsh"
    msg "Selecione os plugins externos do Oh My Zsh."
    msg ""

    local external_plugins_desc=(
      "zsh-autosuggestions - ⭐ Sugestões baseadas no histórico (ESSENCIAL)"
      "zsh-syntax-highlighting - ⭐ Colorir comandos válidos/inválidos (ESSENCIAL)"
      "fast-syntax-highlighting - Alternativa mais rápida ao syntax-highlighting"
      "zsh-completions - Completions extras para vários comandos"
      "you-should-use - ⭐ Lembra dos aliases disponíveis"
      "fzf-tab - Usa fzf para completar com Tab"
      "zsh-autocomplete - Autocomplete avançado com menu interativo"
    )

    local selected_external_desc=()
    select_multiple_items "📦 Plugins externos" selected_external_desc "${external_plugins_desc[@]}"
    for item in "${selected_external_desc[@]}"; do
      local plugin_name
      plugin_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_OMZ_EXTERNAL_PLUGINS+=("$plugin_name")
    done

    local all_plugins=()
    if [[ ${#SELECTED_OMZ_PLUGINS[@]} -gt 0 ]]; then
      local builtin_list
      builtin_list=$(printf "%s, " "${SELECTED_OMZ_PLUGINS[@]}")
      all_plugins+=("Built-in: ${builtin_list%, }")
    fi
    if [[ ${#SELECTED_OMZ_EXTERNAL_PLUGINS[@]} -gt 0 ]]; then
      local external_list
      external_list=$(printf "%s, " "${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}")
      all_plugins+=("Externos: ${external_list%, }")
    fi
    [[ ${#all_plugins[@]} -eq 0 ]] && all_plugins=("(nenhum)")

    if confirm_selection "🔌 Plugins Oh My Zsh" "${all_plugins[@]}"; then
      break
    fi
    clear_screen
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de preset do Starship
# ═══════════════════════════════════════════════════════════

ask_starship_preset() {
  [[ $INSTALL_STARSHIP -eq 0 ]] && return 0

  SELECTED_STARSHIP_PRESET=""
  SELECTED_CATPPUCCIN_FLAVOR=""

  while true; do
    clear_screen
    show_section_header "✨ PRESETS - Starship"

    msg "Starship oferece presets prontos para usar."
    msg ""
    msg "💡 Você pode mudar depois editando ~/.config/starship.toml"
    msg "   Mais presets em: https://starship.rs/presets/"
    msg ""

    local choice=""
    local clear_preview_before_render=0
    menu_select_single "Selecione o preset do Starship" "Digite sua escolha" choice \
      "Catppuccin Powerline - Cores pastel + powerline + 4 sabores" \
      "Tokyo Night - Esquema escuro elegante" \
      "Gruvbox Rainbow - Cores quentes e rainbow" \
      "Pastel Powerline - Cores pastel suaves" \
      "Nerd Font Symbols - Minimalista com ícones Nerd Fonts" \
      "Plain Text Symbols - Minimalista sem ícones Nerd Fonts"

    case "$choice" in
      1)
        SELECTED_STARSHIP_PRESET="catppuccin-powerline"
        msg "  ✅ Selecionado: Catppuccin Powerline"
        msg ""

        msg "🎨 Escolha o sabor (flavor) do Catppuccin:"
        msg ""

        local flavor_choice=""
        menu_select_single "Selecione o sabor Catppuccin" "Digite sua escolha" flavor_choice \
          "Mocha - Escuro, tons quentes (recomendado)" \
          "Latte - Claro, tons suaves" \
          "Frappe - Escuro, tons frios" \
          "Macchiato - Meio-escuro, balanceado"

        case "$flavor_choice" in
          1) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_mocha" ;;
          2) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_latte" ;;
          3) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_frappe" ;;
          4) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_macchiato" ;;
        esac

        msg "  ✅ Selecionado: ${SELECTED_STARSHIP_PRESET} (${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_})"
        clear_preview_before_render=1
        ;;
      2)
        SELECTED_STARSHIP_PRESET="tokyo-night"
        msg "  ✅ Selecionado: Tokyo Night"
        ;;
      3)
        SELECTED_STARSHIP_PRESET="gruvbox-rainbow"
        msg "  ✅ Selecionado: Gruvbox Rainbow"
        ;;
      4)
        SELECTED_STARSHIP_PRESET="pastel-powerline"
        msg "  ✅ Selecionado: Pastel Powerline"
        ;;
      5)
        SELECTED_STARSHIP_PRESET="nerd-font-symbols"
        msg "  ✅ Selecionado: Nerd Font Symbols"
        ;;
      6)
        SELECTED_STARSHIP_PRESET="plain-text-symbols"
        msg "  ✅ Selecionado: Plain Text Symbols"
        ;;
    esac

    if [[ $clear_preview_before_render -eq 1 ]]; then
      if declare -F clear_screen >/dev/null; then
        clear_screen
      else
        clear
      fi
    fi
    preview_starship_preset "$SELECTED_STARSHIP_PRESET"
    if [[ "$SELECTED_STARSHIP_PRESET" == "catppuccin-powerline" ]]; then
      msg "  🗺️  Legenda da imagem (2x2):"
      msg "  • Topo-esquerda: Latte"
      msg "  • Topo-direita: Frappe"
      msg "  • Baixo-esquerda: Macchiato"
      msg "  • Baixo-direita: Mocha"
      if [[ -n "$SELECTED_CATPPUCCIN_FLAVOR" ]]; then
        local flavor_pos=""
        case "$SELECTED_CATPPUCCIN_FLAVOR" in
          catppuccin_latte) flavor_pos="topo-esquerda" ;;
          catppuccin_frappe) flavor_pos="topo-direita" ;;
          catppuccin_macchiato) flavor_pos="baixo-esquerda" ;;
          catppuccin_mocha) flavor_pos="baixo-direita" ;;
        esac
        msg "  ✅ Selecionado: ${SELECTED_STARSHIP_PRESET} (${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}, ${flavor_pos})"
      fi
      msg ""
    fi

    local preset_display="$SELECTED_STARSHIP_PRESET"
    [[ -n "$SELECTED_CATPPUCCIN_FLAVOR" ]] && preset_display+=" (${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_})"
    if confirm_selection "✨ Starship Preset" "$preset_display"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de tema do Oh My Posh
# ═══════════════════════════════════════════════════════════

ask_oh_my_posh_theme() {
  [[ $INSTALL_OH_MY_POSH -eq 0 ]] && return 0

  SELECTED_OMP_THEME=""

  while true; do
    clear_screen
    show_section_header "🎭 TEMAS - Oh My Posh"

    msg "Oh My Posh tem centenas de temas prontos."
    msg ""
    msg "💡 Veja todos os temas em: https://ohmyposh.dev/docs/themes"
    msg "   Comando: oh-my-posh config export --format json"
    msg ""

    local choice=""
    menu_select_single "Selecione um tema do Oh My Posh" "Digite sua escolha" choice \
      "Catppuccin - Cores pastel suaves" \
      "Tokyo Night - Esquema escuro elegante" \
      "Dracula - Cores vibrantes" \
      "Nord - Paleta fria" \
      "Paradox - Clássico e limpo" \
      "Pure - Minimalista" \
      "Atomic - Moderno e informativo" \
      "Default - Tema padrão do Oh My Posh"

    case "$choice" in
      1)
        SELECTED_OMP_THEME="catppuccin"
        msg "  ✅ Selecionado: Catppuccin"
        ;;
      2)
        SELECTED_OMP_THEME="tokyo"
        msg "  ✅ Selecionado: Tokyo Night"
        ;;
      3)
        SELECTED_OMP_THEME="dracula"
        msg "  ✅ Selecionado: Dracula"
        ;;
      4)
        SELECTED_OMP_THEME="nord"
        msg "  ✅ Selecionado: Nord"
        ;;
      5)
        SELECTED_OMP_THEME="paradox"
        msg "  ✅ Selecionado: Paradox"
        ;;
      6)
        SELECTED_OMP_THEME="pure"
        msg "  ✅ Selecionado: Pure"
        ;;
      7)
        SELECTED_OMP_THEME="atomic"
        msg "  ✅ Selecionado: Atomic"
        ;;
      8)
        SELECTED_OMP_THEME="default"
        msg "  ✅ Selecionado: Default"
        ;;
    esac

    preview_oh_my_posh "$SELECTED_OMP_THEME"

    if confirm_selection "🎭 Tema Oh My Posh" "$SELECTED_OMP_THEME"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de plugins do Fish
# ═══════════════════════════════════════════════════════════

ask_fish_plugins() {
  [[ $INSTALL_FISH -eq 0 ]] && return 0
  while true; do
    SELECTED_FISH_PLUGINS=()
    clear_screen
    show_section_header "🐟 PLUGINS - Fish Shell"

    msg "Fish tem funcionalidades nativas (autosuggestions, syntax highlighting)"
    msg "e plugins via Fisher (gerenciador de plugins moderno)."
    msg ""

    local has_zoxide=0
    local has_fzf=0
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do
      [[ "$tool" == "zoxide" ]] && has_zoxide=1
      [[ "$tool" == "fzf" ]] && has_fzf=1
    done

    if [[ $has_zoxide -eq 1 ]] || [[ $has_fzf -eq 1 ]]; then
      msg "⚠️  AVISO: Você já selecionou ferramentas similares em Ferramentas CLI:"
      [[ $has_zoxide -eq 1 ]] && msg "  • zoxide já foi selecionado (similar ao plugin 'z')"
      [[ $has_fzf -eq 1 ]] && msg "  • fzf já foi selecionado (integração via plugin 'fzf.fish')"
      msg ""
      msg "  Os plugins Fish funcionarão com essas ferramentas se instalados."
      msg ""
    fi

    local fish_plugins_desc=(
      "z - Jump para diretórios frequentes"
      "fzf.fish - Integração com fzf (busca fuzzy)"
      "done - Notificações quando comandos longos terminam"
      "autopair.fish - Fechar parênteses/aspas automaticamente"
    )

    if [[ ${INSTALL_STARSHIP:-0} -eq 0 ]] && [[ ${INSTALL_OH_MY_POSH:-0} -eq 0 ]]; then
      fish_plugins_desc+=("tide - Prompt customizável para Fish (tema completo)")
    fi

    local selected_fish_desc=()
    select_multiple_items "🐟 Selecione os plugins do Fish" selected_fish_desc "${fish_plugins_desc[@]}"
    for item in "${selected_fish_desc[@]}"; do
      local plugin_name
      plugin_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_FISH_PLUGINS+=("$plugin_name")
    done

    local fish_summary=()
    if [[ ${#SELECTED_FISH_PLUGINS[@]} -gt 0 ]]; then
      fish_summary=("${SELECTED_FISH_PLUGINS[@]}")
    else
      fish_summary=("(nenhum - apenas funcionalidades nativas)")
    fi

    if confirm_selection "🐟 Plugins Fish" "${fish_summary[@]}"; then
      break
    fi
    clear_screen
  done
}

