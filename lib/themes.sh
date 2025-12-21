#!/usr/bin/env bash
# Seleção e instalação de temas para shells
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Variáveis globais para temas
# ═══════════════════════════════════════════════════════════

INSTALL_OH_MY_ZSH=0
INSTALL_POWERLEVEL10K=0
INSTALL_OH_MY_POSH=0
INSTALL_STARSHIP=0

# Arrays para plugins e presets selecionados
declare -a SELECTED_OMZ_PLUGINS=()
declare -a SELECTED_OMZ_EXTERNAL_PLUGINS=()
declare -a SELECTED_FISH_PLUGINS=()
SELECTED_STARSHIP_PRESET=""
SELECTED_OMP_THEME=""

# ═══════════════════════════════════════════════════════════
# Prévia de temas (best-effort)
# ═══════════════════════════════════════════════════════════

theme_preview_cache_dir() {
  local base="${XDG_CACHE_HOME:-$HOME/.cache}"
  echo "$base/dotfiles/theme-previews"
}

theme_preview_renderer() {
  if has_cmd kitty && { [[ -n "${KITTY_WINDOW_ID:-}" ]] || [[ "${TERM_PROGRAM:-}" == "ghostty" ]]; }; then
    echo "kitty"
    return 0
  fi
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] && has_cmd imgcat; then
    echo "imgcat"
    return 0
  fi
  if has_cmd img2sixel; then
    echo "sixel"
    return 0
  fi
  if has_cmd chafa; then
    echo "chafa"
    return 0
  fi
  return 1
}

download_preview_image() {
  local out="$1"
  shift
  local urls=("$@")

  if [[ -s "$out" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$out")"
  local url
  for url in "${urls[@]}"; do
    [[ -z "$url" ]] && continue
    if curl -fsSL "$url" -o "$out" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

show_theme_preview() {
  local title="$1"
  local desc="$2"
  local link="$3"
  local image_path="$4"

  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  🖼️  Prévia: $title"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""
  [[ -n "$desc" ]] && msg "  $desc"
  [[ -n "$link" ]] && msg "  🔗 $link"
  msg ""

  if [[ -f "$image_path" ]]; then
    local renderer
    renderer="$(theme_preview_renderer || true)"
    case "$renderer" in
      kitty) kitty +kitten icat --transfer-mode=stream "$image_path" >/dev/null 2>&1 ;;
      imgcat) imgcat "$image_path" >/dev/null 2>&1 ;;
      sixel) img2sixel "$image_path" >/dev/null 2>&1 ;;
      chafa) chafa -s 80x20 "$image_path" >/dev/null 2>&1 ;;
      *) ;;
    esac
    if [[ -z "$renderer" ]]; then
      msg "  ℹ️  Prévia inline não suportada neste terminal."
    fi
  else
    msg "  ℹ️  Prévia inline indisponível (sem imagem)."
  fi
  msg ""
}

preview_powerlevel10k() {
  local cache_dir
  cache_dir="$(theme_preview_cache_dir)"
  local img="$cache_dir/powerlevel10k.png"
  local url="https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/prompt-styles.png"
  download_preview_image "$img" "$url" || img=""
  show_theme_preview "Oh My Zsh + Powerlevel10k" \
    "Tema ultra-rápido com estilos de prompt configuráveis." \
    "https://github.com/romkatv/powerlevel10k" \
    "$img"
}

preview_starship_preset() {
  local preset="$1"
  local cache_dir
  cache_dir="$(theme_preview_cache_dir)"
  local img="$cache_dir/starship-${preset}.png"
  local url=""

  # URLs das imagens dos presets do Starship
  case "$preset" in
    catppuccin-powerline)
      url="https://starship.rs/presets/img/catppuccin-powerline.png"
      ;;
    tokyo-night)
      url="https://starship.rs/presets/img/tokyo-night.png"
      ;;
    gruvbox-rainbow)
      url="https://starship.rs/presets/img/gruvbox-rainbow.png"
      ;;
    pastel-powerline)
      url="https://starship.rs/presets/img/pastel-powerline.png"
      ;;
    nerd-font-symbols)
      url="https://starship.rs/presets/img/nerd-font-symbols.png"
      ;;
    plain-text-symbols)
      url="https://starship.rs/presets/img/plain-text-symbols.png"
      ;;
  esac

  if [[ -n "$url" ]]; then
    download_preview_image "$img" "$url" || img=""
  else
    img=""
  fi

  show_theme_preview "Starship ($preset)" \
    "Preset do Starship. Veja mais opções no site oficial." \
    "https://starship.rs/presets/" \
    "$img"
}

preview_oh_my_posh() {
  local theme="$1"
  local cache_dir
  cache_dir="$(theme_preview_cache_dir)"
  local img="$cache_dir/ohmyposh-${theme}.png"
  local url1="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/website/static/themes/${theme}.png"
  local url2="https://ohmyposh.dev/assets/themes/${theme}.png"
  local url3="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/website/static/themes/${theme}.webp"
  local url4="https://ohmyposh.dev/assets/themes/${theme}.webp"
  download_preview_image "$img" "$url1" "$url2" "$url3" "$url4" || img=""
  show_theme_preview "Oh My Posh ($theme)" \
    "Tema do Oh My Posh com preset pronto." \
    "https://ohmyposh.dev/docs/themes" \
    "$img"
}

# ═══════════════════════════════════════════════════════════
# Tela de seleção de temas
# ═══════════════════════════════════════════════════════════

ask_themes() {
  while true; do
    INSTALL_OH_MY_ZSH=0
    INSTALL_POWERLEVEL10K=0
    INSTALL_OH_MY_POSH=0
    INSTALL_STARSHIP=0

    show_section_header "🎨 TEMAS - Personalize seu Shell"

    msg "Temas deixam seu terminal bonito e informativo com ícones, cores e informações úteis."
    msg ""

    # Verificar quais shells foram selecionados
    local has_zsh=$INSTALL_ZSH
    local has_fish=$INSTALL_FISH

    if [[ $has_zsh -eq 0 ]] && [[ $has_fish -eq 0 ]]; then
      msg "  ℹ️  Nenhum shell foi selecionado. Pulando seleção de temas."
      msg ""
      return 0
    fi

    msg "📝 Temas disponíveis para os shells selecionados:"
    msg ""

    # Mostrar temas disponíveis baseado nos shells
    if [[ $has_zsh -eq 1 ]]; then
      msg "  🔷 Para Zsh:"
      msg ""
      msg "    1. Oh My Zsh + Powerlevel10k"
      msg "       - Framework completo com centenas de plugins"
      msg "       - Powerlevel10k: tema ultra-rápido e customizável"
      msg "       - Wizard de configuração interativo"
      msg "       - Ideal para: máximo de customização"
      msg "       - Requer: Nerd Fonts"
      msg ""
      msg "    2. Starship"
      msg "       - Prompt minimalista e super rápido"
      msg "       - Configuração via TOML simples"
      msg "       - Presets prontos (Catppuccin, Tokyo Night, etc)"
      msg "       - Cross-shell (funciona em Zsh e Fish)"
      msg "       - Ideal para: simplicidade e performance"
      msg "       - Requer: Nerd Fonts"
      msg ""
      msg "    3. Oh My Posh"
      msg "       - Prompt bonito e configurável"
      msg "       - Centenas de temas prontos"
      msg "       - Cross-shell e cross-platform"
      msg "       - Ideal para: consistência entre Zsh/Fish/PowerShell"
      msg "       - Requer: Nerd Fonts"
      msg ""
    fi

    if [[ $has_fish -eq 1 ]]; then
      msg "  🔶 Para Fish:"
      msg ""
      msg "    1. Starship"
      msg "       - Prompt minimalista e super rápido"
      msg "       - Mesmo tema em Zsh e Fish"
      msg "       - Presets prontos"
      msg "       - Ideal para: simplicidade"
      msg "       - Requer: Nerd Fonts"
      msg ""
      msg "    2. Oh My Posh"
      msg "       - Prompt configurável"
      msg "       - Cross-shell"
      msg "       - Ideal para: consistência"
      msg "       - Requer: Nerd Fonts"
      msg ""
    fi

    msg "⚠️  IMPORTANTE:"
    msg ""
    msg "  • Você pode instalar múltiplos temas e alterná-los depois"
    msg "  • Todos os temas requerem Nerd Fonts instaladas"
    msg ""
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  Selecione os temas que deseja instalar"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg ""
    msg "  (Você pode selecionar múltiplos temas)"
    msg ""

    # Opções de temas baseadas nos shells
    local theme_options=()
    local theme_compat=()

    if [[ $has_zsh -eq 1 ]]; then
      theme_options+=("Oh My Zsh + Powerlevel10k")
      theme_compat+=("zsh")
    fi

    # Starship funciona em ambos
    if [[ $has_zsh -eq 1 ]] || [[ $has_fish -eq 1 ]]; then
      local compat=""
      [[ $has_zsh -eq 1 ]] && compat="zsh"
      [[ $has_fish -eq 1 ]] && [[ -n "$compat" ]] && compat="$compat/fish" || compat="fish"
      theme_options+=("Starship")
      theme_compat+=("$compat")
    fi

    # Oh My Posh funciona em ambos
    if [[ $has_zsh -eq 1 ]] || [[ $has_fish -eq 1 ]]; then
      local compat=""
      [[ $has_zsh -eq 1 ]] && compat="zsh"
      [[ $has_fish -eq 1 ]] && [[ -n "$compat" ]] && compat="$compat/fish" || compat="fish"
      theme_options+=("Oh My Posh")
      theme_compat+=("$compat")
    fi

    # Mostrar opções com compatibilidade
    local idx=1
    for i in "${!theme_options[@]}"; do
      msg "  $idx) ${theme_options[$i]} (${theme_compat[$i]})"
      idx=$((idx + 1))
    done
    msg ""
    msg "  a) Todos"
    msg "  (Enter para nenhum)"
    msg ""

    local input=""
    read -r -p "  Selecione números separados por vírgula ou 'a': " input

    # Processar seleção
    local selected_themes=()

    if [[ -z "$input" ]]; then
      msg ""
      msg "  ⏭️  Nenhum tema selecionado"
      msg ""
      return 0
    fi

    case "$input" in
      a|A|all|ALL|todos|T|t)
        selected_themes=("${theme_options[@]}")
        ;;
      *)
        local nums=()
        IFS=',' read -r -a nums <<< "$input"
        for n in "${nums[@]}"; do
          n="${n//[[:space:]]/}"
          [[ -z "$n" ]] && continue
          if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 )) && (( n <= ${#theme_options[@]} )); then
            selected_themes+=("${theme_options[n-1]}")
          fi
        done
        ;;
    esac

    # Mapear seleções para variáveis
    for theme in "${selected_themes[@]}"; do
      case "$theme" in
        "Oh My Zsh + Powerlevel10k")
          INSTALL_OH_MY_ZSH=1
          INSTALL_POWERLEVEL10K=1
          ;;
        "Starship")
          INSTALL_STARSHIP=1
          ;;
        "Oh My Posh")
          INSTALL_OH_MY_POSH=1
          ;;
      esac
    done

    msg ""
    msg "✅ Seleção de temas concluída"

    if [[ ${#selected_themes[@]} -gt 0 ]]; then
      print_selection_summary "🎨 Temas" "${selected_themes[@]}"
    else
      print_selection_summary "🎨 Temas" "(nenhum)"
    fi

    # Mostrar prévia de cada tema selecionado
    for theme in "${selected_themes[@]}"; do
      case "$theme" in
        "Oh My Zsh + Powerlevel10k")
          preview_powerlevel10k
          ;;
        "Starship")
          show_theme_preview "Starship" \
            "Prompt minimalista e super rápido. Você escolherá o preset depois." \
            "https://starship.rs/presets/" \
            ""
          ;;
        "Oh My Posh")
          show_theme_preview "Oh My Posh" \
            "Prompt bonito e configurável. Você escolherá o tema depois." \
            "https://ohmyposh.dev/docs/themes" \
            ""
          ;;
      esac
    done

    msg ""
    break
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

    show_section_header "🔌 PLUGINS - Oh My Zsh"

    msg "Plugins adicionam funcionalidades extras ao seu shell."
    msg ""

    local omz_plugins_desc=(
      "git - Aliases úteis para Git (gst, gco, gp, etc)"
      "docker - Autocomplete e aliases para Docker"
      "docker-compose - Autocomplete para docker-compose"
      "kubectl - Autocomplete para Kubernetes"
      "npm - Autocomplete para npm"
      "yarn - Autocomplete para yarn"
      "node - Autocomplete para node"
      "python - Aliases para Python"
      "golang - Aliases para Go"
      "rust - Autocomplete para Rust/Cargo"
      "command-not-found - Sugere instalação de comandos não encontrados"
      "sudo - Pressione ESC 2x para adicionar sudo"
      "extract - Comando 'x' para extrair qualquer arquivo"
      "z - Jump para diretórios frequentes"
      "web-search - Buscar no Google/Bing direto do terminal"
    )

    local selected_omz_desc=()
    select_multiple_items "🔌 Selecione os plugins built-in do Oh My Zsh" selected_omz_desc "${omz_plugins_desc[@]}"
    for item in "${selected_omz_desc[@]}"; do
      SELECTED_OMZ_PLUGINS+=("${item%% - *}")
    done

    msg ""
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  📦 PLUGINS EXTERNOS - Oh My Zsh"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg ""

    local external_plugins_desc=(
      "zsh-autosuggestions - ⭐ Sugestões baseadas no histórico (ESSENCIAL)"
      "zsh-syntax-highlighting - ⭐ Colorir comandos válidos/inválidos (ESSENCIAL)"
      "fast-syntax-highlighting - Alternativa mais rápida ao anterior"
      "zsh-autocomplete - Autocomplete avançado com menu interativo"
      "zsh-completions - Completions extras para vários comandos"
    )

    local selected_external_desc=()
    select_multiple_items "📦 Selecione os plugins externos do Oh My Zsh" selected_external_desc "${external_plugins_desc[@]}"
    for item in "${selected_external_desc[@]}"; do
      SELECTED_OMZ_EXTERNAL_PLUGINS+=("${item%% - *}")
    done

    msg ""
    if [[ ${#SELECTED_OMZ_PLUGINS[@]} -gt 0 ]]; then
      print_selection_summary "🔌 Plugins Built-in" "${SELECTED_OMZ_PLUGINS[@]}"
    else
      print_selection_summary "🔌 Plugins Built-in" "(nenhum)"
    fi

    if [[ ${#SELECTED_OMZ_EXTERNAL_PLUGINS[@]} -gt 0 ]]; then
      print_selection_summary "📦 Plugins Externos" "${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}"
    else
      print_selection_summary "📦 Plugins Externos" "(nenhum)"
    fi
    msg ""
    break
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
    show_section_header "✨ PRESETS - Starship"

    msg "Starship oferece presets prontos para usar."
    msg ""
    msg "📝 Presets disponíveis:"
    msg ""
    msg "  1. Catppuccin Powerline (Recomendado)"
    msg "     - Cores pastel suaves inspiradas em Catppuccin"
    msg "     - Powerline segments bonitos"
    msg "     - Ícones e Git status"
    msg "     - Escolha entre 4 sabores: Mocha, Latte, Frappe, Macchiato"
    msg ""
    msg "  2. Tokyo Night"
    msg "     - Esquema de cores escuro e elegante"
    msg "     - Inspirado no tema Tokyo Night"
    msg ""
    msg "  3. Gruvbox Rainbow"
    msg "     - Cores quentes do Gruvbox"
    msg "     - Rainbow colorido"
    msg ""
    msg "  4. Pastel Powerline"
    msg "     - Cores pastel suaves"
    msg "     - Powerline style"
    msg ""
    msg "  5. Nerd Font Symbols"
    msg "     - Minimalista com ícones Nerd Fonts"
    msg "     - Apenas essencial (path, git, status)"
    msg ""
    msg "  6. Plain Text Symbols"
    msg "     - Versão minimalista sem ícones Nerd Font"
    msg ""
    msg "💡 Você pode mudar depois editando ~/.config/starship.toml"
    msg "   Mais presets em: https://starship.rs/presets/"
    msg ""

    local choice=""
    menu_select_single "Selecione o preset do Starship" "Digite sua escolha" choice \
      "Catppuccin Powerline" \
      "Tokyo Night" \
      "Gruvbox Rainbow" \
      "Pastel Powerline" \
      "Nerd Font Symbols" \
      "Plain Text Symbols"

    case "$choice" in
      1)
        SELECTED_STARSHIP_PRESET="catppuccin-powerline"
        msg "  ✅ Selecionado: Catppuccin Powerline"
        msg ""

        # Perguntar variante Catppuccin
        msg "🎨 Escolha o sabor (flavor) do Catppuccin:"
        msg ""
        msg "  1. Mocha (escuro, tons quentes - Recomendado)"
        msg "  2. Latte (claro, tons suaves)"
        msg "  3. Frappe (escuro, tons frios)"
        msg "  4. Macchiato (meio-escuro, balanceado)"
        msg ""

        local flavor_choice=""
        menu_select_single "Selecione o sabor Catppuccin" "Digite sua escolha" flavor_choice \
          "Mocha (escuro, quente)" \
          "Latte (claro, suave)" \
          "Frappe (escuro, frio)" \
          "Macchiato (meio-escuro)"

        case "$flavor_choice" in
          1) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_mocha" ;;
          2) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_latte" ;;
          3) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_frappe" ;;
          4) SELECTED_CATPPUCCIN_FLAVOR="catppuccin_macchiato" ;;
        esac

        msg "  ✅ Sabor selecionado: ${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}"
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

    preview_starship_preset "$SELECTED_STARSHIP_PRESET"
    if [[ -n "$SELECTED_CATPPUCCIN_FLAVOR" ]]; then
      print_selection_summary "✨ Preset Starship" "$SELECTED_STARSHIP_PRESET (${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_})"
    else
      print_selection_summary "✨ Preset Starship" "$SELECTED_STARSHIP_PRESET"
    fi
    msg ""
    break
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de tema do Oh My Posh
# ═══════════════════════════════════════════════════════════

ask_oh_my_posh_theme() {
  [[ $INSTALL_OH_MY_POSH -eq 0 ]] && return 0

  SELECTED_OMP_THEME=""

  while true; do
    show_section_header "🎭 TEMAS - Oh My Posh"

    msg "Oh My Posh tem centenas de temas prontos."
    msg ""
    msg "📝 Temas populares:"
    msg ""
    msg "  1. Catppuccin (Recomendado)"
    msg "     - Cores pastel suaves"
    msg "     - Powerline segments"
    msg ""
    msg "  2. Tokyo Night"
    msg "     - Esquema escuro elegante"
    msg ""
    msg "  3. Dracula"
    msg "     - Cores vibrantes"
    msg ""
    msg "  4. Nord"
    msg "     - Paleta fria"
    msg ""
    msg "  5. Paradox"
    msg "     - Clássico e limpo"
    msg ""
    msg "  6. Pure"
    msg "     - Minimalista"
    msg ""
    msg "  7. Atomic"
    msg "     - Moderno e informativo"
    msg ""
    msg "  8. Default"
    msg "     - Tema padrão do Oh My Posh"
    msg ""
    msg "💡 Veja todos os temas em: https://ohmyposh.dev/docs/themes"
    msg "   Comando: oh-my-posh config export --format json"
    msg ""

    local choice=""
    menu_select_single "Selecione um tema do Oh My Posh" "Digite sua escolha" choice \
      "Catppuccin" \
      "Tokyo Night" \
      "Dracula" \
      "Nord" \
      "Paradox" \
      "Pure" \
      "Atomic" \
      "Default"

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
    print_selection_summary "🎭 Tema Oh My Posh" "$SELECTED_OMP_THEME"
    msg ""
    break
  done
}

# ═══════════════════════════════════════════════════════════
# Seleção de plugins do Fish
# ═══════════════════════════════════════════════════════════

ask_fish_plugins() {
  [[ $INSTALL_FISH -eq 0 ]] && return 0
  while true; do
    SELECTED_FISH_PLUGINS=()

    show_section_header "🐟 PLUGINS - Fish Shell"

    msg "Fish tem funcionalidades nativas (autosuggestions, syntax highlighting)"
    msg "e plugins via Fisher (gerenciador de plugins moderno)."
    msg ""

    # Avisar sobre duplicação com CLI Tools
    local has_zoxide=0
    local has_fzf=0
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do
      [[ "$tool" == "zoxide" ]] && has_zoxide=1
      [[ "$tool" == "fzf" ]] && has_fzf=1
    done

    if [[ $has_zoxide -eq 1 ]] || [[ $has_fzf -eq 1 ]]; then
      msg "⚠️  AVISO: Você já selecionou ferramentas similares em CLI Tools:"
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
      "tide - Prompt customizável (alternativa ao Starship/Oh My Posh)"
    )

    local selected_fish_desc=()
    select_multiple_items "🐟 Selecione os plugins do Fish" selected_fish_desc "${fish_plugins_desc[@]}"
    for item in "${selected_fish_desc[@]}"; do
      SELECTED_FISH_PLUGINS+=("${item%% - *}")
    done

    msg ""
    if [[ ${#SELECTED_FISH_PLUGINS[@]} -gt 0 ]]; then
      print_selection_summary "🐟 Plugins Fish" "${SELECTED_FISH_PLUGINS[@]}"
    else
      print_selection_summary "🐟 Plugins Fish" "(nenhum - apenas funcionalidades nativas)"
    fi
    msg ""
    break
  done
}

# ═══════════════════════════════════════════════════════════
# Instalação de Oh My Zsh
# ═══════════════════════════════════════════════════════════

install_oh_my_zsh() {
  [[ $INSTALL_OH_MY_ZSH -eq 0 ]] && return 0
  [[ $INSTALL_ZSH -eq 0 ]] && return 0

  local oh_my_zsh_dir="$HOME/.oh-my-zsh"
  local zshrc="$HOME/.zshrc"

  if [[ -d "$oh_my_zsh_dir" ]]; then
    msg "  ℹ️  Oh My Zsh já está instalado"
  else
    msg "  📦 Instalando Oh My Zsh..."

    # Download e instalação via script oficial
    if has_cmd curl; then
      if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null; then
        INSTALLED_MISC+=("oh-my-zsh: framework")
        msg "  ✅ Oh My Zsh instalado"
      else
        record_failure "optional" "Falha ao instalar Oh My Zsh"
        return 1
      fi
    else
      record_failure "optional" "curl não encontrado - necessário para instalar Oh My Zsh"
      return 1
    fi
  fi

  # Instalar plugins externos se houver seleções
  if [[ ${#SELECTED_OMZ_EXTERNAL_PLUGINS[@]} -gt 0 ]]; then
    msg "  📦 Instalando plugins externos..."

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    for plugin in "${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}"; do
      local plugin_dir="$zsh_custom/plugins/$plugin"

      if [[ -d "$plugin_dir" ]]; then
        msg "  ℹ️  Plugin $plugin já está instalado"
        continue
      fi

      case "$plugin" in
        zsh-autosuggestions)
          msg "  📥 Baixando zsh-autosuggestions..."
          if git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-autosuggestions instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-autosuggestions")
          else
            warn "Falha ao clonar zsh-autosuggestions"
          fi
          ;;
        zsh-syntax-highlighting)
          msg "  📥 Baixando zsh-syntax-highlighting..."
          if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-syntax-highlighting instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-syntax-highlighting")
          else
            warn "Falha ao clonar zsh-syntax-highlighting"
          fi
          ;;
        fast-syntax-highlighting)
          msg "  📥 Baixando fast-syntax-highlighting..."
          if git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ fast-syntax-highlighting instalado"
            INSTALLED_MISC+=("omz-plugin: fast-syntax-highlighting")
          else
            warn "Falha ao clonar fast-syntax-highlighting"
          fi
          ;;
        zsh-autocomplete)
          msg "  📥 Baixando zsh-autocomplete..."
          if git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-autocomplete instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-autocomplete")
          else
            warn "Falha ao clonar zsh-autocomplete"
          fi
          ;;
        zsh-completions)
          msg "  📥 Baixando zsh-completions..."
          if git clone https://github.com/zsh-users/zsh-completions.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-completions instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-completions")
          else
            warn "Falha ao clonar zsh-completions"
          fi
          ;;
      esac
    done
  fi

  # Configurar plugins (built-in + externos) se houver seleções
  local all_plugins=()
  all_plugins+=("${SELECTED_OMZ_PLUGINS[@]}")
  all_plugins+=("${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}")

  if [[ ${#all_plugins[@]} -gt 0 ]] && [[ -f "$zshrc" ]]; then
    msg "  🔌 Configurando plugins no .zshrc..."

    # Criar string de plugins: git docker kubectl zsh-autosuggestions ...
    local plugins_str="${all_plugins[*]}"

    # Substituir linha de plugins no .zshrc
    if grep -q "^plugins=" "$zshrc"; then
      sed -i.bak "s/^plugins=.*/plugins=($plugins_str)/" "$zshrc"
      msg "  ✅ Plugins configurados: $plugins_str"
    else
      # Se não existir linha de plugins, adicionar
      echo "plugins=($plugins_str)" >> "$zshrc"
      msg "  ✅ Plugins adicionados ao .zshrc"
    fi

    rm -f "$zshrc.bak"
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Powerlevel10k
# ═══════════════════════════════════════════════════════════

install_powerlevel10k() {
  [[ $INSTALL_POWERLEVEL10K -eq 0 ]] && return 0
  [[ $INSTALL_ZSH -eq 0 ]] && return 0

  local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

  if [[ -d "$p10k_dir" ]]; then
    msg "  ℹ️  Powerlevel10k já está instalado"
    return 0
  fi

  msg "  📦 Instalando Powerlevel10k..."

  if has_cmd git; then
    if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" 2>/dev/null; then
      INSTALLED_MISC+=("powerlevel10k: tema")
      msg "  ✅ Powerlevel10k instalado"
      msg "  💡 Execute 'p10k configure' para configurar o tema"
    else
      record_failure "optional" "Falha ao instalar Powerlevel10k"
    fi
  else
    record_failure "optional" "git não encontrado - necessário para instalar Powerlevel10k"
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Starship
# ═══════════════════════════════════════════════════════════

install_starship() {
  [[ $INSTALL_STARSHIP -eq 0 ]] && return 0

  local starship_installed=0

  if has_cmd starship; then
    msg "  ℹ️  Starship já está instalado"
    starship_installed=1
  else
    msg "  📦 Instalando Starship..."

    case "$TARGET_OS" in
      linux|wsl2)
        if has_cmd curl; then
          if sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes 2>/dev/null; then
            INSTALLED_MISC+=("starship: prompt")
            msg "  ✅ Starship instalado"
            starship_installed=1
          else
            record_failure "optional" "Falha ao instalar Starship"
            return 1
          fi
        else
          record_failure "optional" "curl não encontrado - necessário para instalar Starship"
          return 1
        fi
        ;;
      macos)
        brew_install_formula starship optional && starship_installed=1
        ;;
      windows)
        winget_install starship optional && starship_installed=1
        ;;
    esac
  fi

  # Configurar preset se selecionado
  if [[ $starship_installed -eq 1 ]] && [[ -n "$SELECTED_STARSHIP_PRESET" ]]; then
    local config_dir="$HOME/.config"
    local starship_config="$config_dir/starship.toml"
    local preset="$SELECTED_STARSHIP_PRESET"

    if [[ "$preset" == "plain" ]]; then
      preset="plain-text-symbols"
    fi

    msg "  ✨ Configurando preset: $preset"

    # Criar diretório de config se não existir
    mkdir -p "$config_dir"

    # Usar comando starship preset para aplicar
    if starship preset "$preset" -o "$starship_config" 2>/dev/null; then
      msg "  ✅ Preset $preset aplicado"

      # Se for Catppuccin, aplicar o sabor selecionado
      if [[ "$preset" == "catppuccin-powerline" ]] && [[ -n "$SELECTED_CATPPUCCIN_FLAVOR" ]]; then
        msg "  🎨 Aplicando sabor Catppuccin: ${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}"
        # Substituir a linha palette = 'catppuccin_mocha' pelo sabor escolhido
        if [[ -f "$starship_config" ]]; then
          sed -i "s/palette = 'catppuccin_mocha'/palette = '$SELECTED_CATPPUCCIN_FLAVOR'/" "$starship_config"
          msg "  ✅ Sabor ${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_} aplicado"
        fi
      fi

      msg "  📄 Configuração salva em: $starship_config"
    else
      warn "Preset $preset não encontrado"
      msg "  ℹ️  Usando preset 'nerd-font-symbols' como fallback"
      if starship preset nerd-font-symbols -o "$starship_config" 2>/dev/null; then
        msg "  ✅ Preset fallback aplicado"
      else
        msg "  💡 Você pode configurar manualmente editando $starship_config"
      fi
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Oh My Posh
# ═══════════════════════════════════════════════════════════

install_oh_my_posh() {
  [[ $INSTALL_OH_MY_POSH -eq 0 ]] && return 0

  local omp_installed=0

  if has_cmd oh-my-posh; then
    msg "  ℹ️  Oh My Posh já está instalado"
    omp_installed=1
  else
    msg "  📦 Instalando Oh My Posh..."

    case "$TARGET_OS" in
      linux|wsl2)
        if has_cmd curl; then
          if curl -s https://ohmyposh.dev/install.sh | bash -s 2>/dev/null; then
            INSTALLED_MISC+=("oh-my-posh: prompt")
            msg "  ✅ Oh My Posh instalado"
            omp_installed=1
          else
            record_failure "optional" "Falha ao instalar Oh My Posh"
            return 1
          fi
        else
          record_failure "optional" "curl não encontrado - necessário para instalar Oh My Posh"
          return 1
        fi
        ;;
      macos)
        brew_install_formula oh-my-posh optional && omp_installed=1
        ;;
      windows)
        winget_install JanDeDobbeleer.OhMyPosh optional && omp_installed=1
        ;;
    esac
  fi

  # Configurar tema se selecionado
  if [[ $omp_installed -eq 1 ]] && [[ -n "$SELECTED_OMP_THEME" ]]; then
    msg "  🎭 Configurando tema: $SELECTED_OMP_THEME"

    # Oh My Posh instala temas em diretórios diferentes por OS
    local theme_file=""

    # Tentar encontrar o arquivo de tema
    # Formato: nome.omp.json (ex: catppuccin.omp.json)
    local possible_dirs=(
      "$HOME/.poshthemes"
      "$(brew --prefix oh-my-posh 2>/dev/null)/themes"
      "/usr/local/share/oh-my-posh/themes"
      "$HOME/.local/share/oh-my-posh/themes"
    )

    for dir in "${possible_dirs[@]}"; do
      if [[ -f "$dir/${SELECTED_OMP_THEME}.omp.json" ]]; then
        theme_file="$dir/${SELECTED_OMP_THEME}.omp.json"
        break
      fi
    done

    if [[ -n "$theme_file" ]]; then
      msg "  ✅ Tema encontrado: $theme_file"

      # Adicionar init ao shell config
      if [[ $INSTALL_ZSH -eq 1 ]] && [[ -f "$HOME/.zshrc" ]]; then
        local init_line="eval \"\$(oh-my-posh init zsh --config '$theme_file')\""
        if ! grep -q "oh-my-posh init zsh" "$HOME/.zshrc"; then
          {
            echo ""
            echo "# Oh My Posh"
            echo "$init_line"
          } >> "$HOME/.zshrc"
          msg "  ✅ Oh My Posh configurado no .zshrc"
        fi
      fi

      if [[ $INSTALL_FISH -eq 1 ]] && [[ -d "$HOME/.config/fish" ]]; then
        local fish_config="$HOME/.config/fish/config.fish"
        mkdir -p "$HOME/.config/fish"
        local init_line="oh-my-posh init fish --config '$theme_file' | source"
        if ! grep -q "oh-my-posh init fish" "$fish_config" 2>/dev/null; then
          {
            echo ""
            echo "# Oh My Posh"
            echo "$init_line"
          } >> "$fish_config"
          msg "  ✅ Oh My Posh configurado no config.fish"
        fi
      fi
    else
      warn "Tema $SELECTED_OMP_THEME não encontrado em diretórios conhecidos"
      msg "  💡 Configure manualmente: oh-my-posh init <shell> --config <tema>.omp.json"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Fisher e plugins do Fish
# ═══════════════════════════════════════════════════════════

install_fish_plugins() {
  [[ $INSTALL_FISH -eq 0 ]] && return 0
  [[ ${#SELECTED_FISH_PLUGINS[@]} -eq 0 ]] && return 0

  if ! has_cmd fish; then
    warn "Fish não está instalado - pulando instalação de plugins"
    return 1
  fi

  msg "  🐟 Instalando Fisher e plugins do Fish..."

  # Instalar Fisher (gerenciador de plugins)
  local fisher_file="$HOME/.config/fish/functions/fisher.fish"
  if [[ ! -f "$fisher_file" ]]; then
    msg "  📦 Instalando Fisher (gerenciador de plugins)..."
    if fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" 2>/dev/null; then
      INSTALLED_MISC+=("fisher: gerenciador de plugins Fish")
      msg "  ✅ Fisher instalado"
    else
      warn "Falha ao instalar Fisher"
      return 1
    fi
  else
    msg "  ℹ️  Fisher já está instalado"
  fi

  # Instalar plugins selecionados via Fisher
  for plugin in "${SELECTED_FISH_PLUGINS[@]}"; do
    local plugin_repo=""
    local plugin_name=""

    case "$plugin" in
      z)
        plugin_repo="jethrokuan/z"
        plugin_name="z (navegação rápida)"
        ;;
      fzf.fish)
        plugin_repo="PatrickF1/fzf.fish"
        plugin_name="fzf.fish (integração fzf)"
        ;;
      done)
        plugin_repo="franciscolourenco/done"
        plugin_name="done (notificações)"
        ;;
      autopair.fish)
        plugin_repo="jorgebucaran/autopair.fish"
        plugin_name="autopair.fish (fechar parênteses)"
        ;;
      tide)
        plugin_repo="IlanCosman/tide@v6"
        plugin_name="tide (prompt)"
        ;;
    esac

    if [[ -n "$plugin_repo" ]]; then
      msg "  📥 Instalando $plugin_name..."
      if fish -c "fisher install $plugin_repo" 2>/dev/null; then
        INSTALLED_MISC+=("fish-plugin: $plugin")
        msg "  ✅ $plugin instalado"
      else
        warn "Falha ao instalar $plugin"
      fi
    fi
  done

  msg "  ✅ Plugins Fish instalados com sucesso!"
}

# ═══════════════════════════════════════════════════════════
# Instalação de todos os temas selecionados
# ═══════════════════════════════════════════════════════════

install_selected_themes() {
  local any_theme=0
  [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && any_theme=1
  [[ $INSTALL_STARSHIP -eq 1 ]] && any_theme=1
  [[ $INSTALL_OH_MY_POSH -eq 1 ]] && any_theme=1

  [[ $any_theme -eq 0 ]] && return 0

  msg "▶ Instalando temas selecionados"
  msg ""

  install_oh_my_zsh
  install_powerlevel10k
  install_starship
  install_oh_my_posh
  install_fish_plugins

  msg ""
  msg "  ✅ Temas instalados com sucesso!"
  msg ""

  # Resumo de configurações aplicadas
  if [[ $INSTALL_OH_MY_ZSH -eq 1 ]]; then
    local all_omz_plugins=()
    all_omz_plugins+=("${SELECTED_OMZ_PLUGINS[@]}")
    all_omz_plugins+=("${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}")

    if [[ ${#all_omz_plugins[@]} -gt 0 ]]; then
      msg "  🔌 Plugins Oh My Zsh: ${all_omz_plugins[*]}"
    fi
  fi

  if [[ $INSTALL_FISH -eq 1 ]] && [[ ${#SELECTED_FISH_PLUGINS[@]} -gt 0 ]]; then
    msg "  🐟 Plugins Fish: ${SELECTED_FISH_PLUGINS[*]}"
  fi

  if [[ $INSTALL_STARSHIP -eq 1 ]] && [[ -n "$SELECTED_STARSHIP_PRESET" ]]; then
    msg "  ✨ Preset Starship aplicado: $SELECTED_STARSHIP_PRESET"
  fi

  if [[ $INSTALL_OH_MY_POSH -eq 1 ]] && [[ -n "$SELECTED_OMP_THEME" ]]; then
    msg "  🎭 Tema Oh My Posh configurado: $SELECTED_OMP_THEME"
  fi

  msg ""

  # Dicas de configuração
  if [[ $INSTALL_POWERLEVEL10K -eq 1 ]]; then
    msg "  💡 Powerlevel10k: Execute 'p10k configure' para personalizar"
  fi

  if [[ $INSTALL_STARSHIP -eq 1 ]]; then
    msg "  💡 Starship: Edite ~/.config/starship.toml para personalizar"
    msg "     Presets: https://starship.rs/presets/"
  fi

  if [[ $INSTALL_OH_MY_POSH -eq 1 ]]; then
    msg "  💡 Oh My Posh: Veja temas disponíveis com 'oh-my-posh get shell'"
    msg "     Temas: https://ohmyposh.dev/docs/themes"
  fi

  msg ""
}
