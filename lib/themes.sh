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
# Suporte: Kitty, Ghostty, iTerm2, WezTerm, Sixel, Chafa
# ═══════════════════════════════════════════════════════════

THEME_PREVIEW_MAX_WIDTH=800
THEME_PREVIEW_MAX_HEIGHT=400

theme_preview_cache_dir() {
  local base="${XDG_CACHE_HOME:-$HOME/.cache}"
  echo "$base/dotfiles/theme-previews"
}

# ═══════════════════════════════════════════════════════════
# Detecção de suporte a imagens em terminais
# Baseado em: https://yazi-rs.github.io/docs/image-preview/
# ═══════════════════════════════════════════════════════════

_terminal_no_inline_support() {
  # Terminais que NÃO suportam imagens inline
  [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] && return 0
  [[ "${TERM:-}" == "linux" ]] && return 0
  [[ "${TERM:-}" == "dumb" ]] && return 0
  return 1
}

# Detecta qual ferramenta usar para renderizar imagens
# Prioridade: chafa (auto-detecta) > kitty icat > img2sixel > catimg > timg
theme_preview_renderer() {
  _terminal_no_inline_support && return 1

  # chafa é a melhor opção: auto-detecta terminal e suporta
  # Kitty, iTerm2, Sixel e fallback para symbols (ASCII art)
  # Funciona em: Ghostty, Kitty, iTerm2, WezTerm, foot, etc.
  if has_cmd chafa; then
    echo "chafa"
    return 0
  fi

  # Fallback: kitty icat para terminais com protocolo Kitty
  # (Kitty, Ghostty, WezTerm, Konsole)
  if has_cmd kitty; then
    local kitty_term=0
    [[ -n "${KITTY_WINDOW_ID:-}" ]] && kitty_term=1
    [[ "${TERM:-}" == "xterm-kitty" ]] && kitty_term=1
    [[ "${TERM_PROGRAM:-}" == "ghostty" ]] && kitty_term=1
    [[ "${TERM:-}" == "xterm-ghostty" ]] && kitty_term=1
    [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]] && kitty_term=1
    [[ "${TERM_PROGRAM:-}" == "WezTerm" ]] && kitty_term=1
    [[ $kitty_term -eq 1 ]] && { echo "kitty"; return 0; }
  fi

  # Fallback: img2sixel para terminais com suporte Sixel
  # (foot, mlterm, contour, Windows Terminal 1.22+)
  if has_cmd img2sixel; then
    local sixel_term=0
    [[ "${TERM:-}" == *"sixel"* ]] && sixel_term=1
    [[ "${TERM_PROGRAM:-}" == "foot" ]] && sixel_term=1
    [[ "${TERM_PROGRAM:-}" == "mlterm" ]] && sixel_term=1
    [[ "${TERM_PROGRAM:-}" == "contour" ]] && sixel_term=1
    [[ -n "${WT_SESSION:-}" ]] && sixel_term=1  # Windows Terminal
    [[ $sixel_term -eq 1 ]] && { echo "sixel"; return 0; }
  fi

  # Fallbacks ASCII art
  has_cmd catimg && { echo "catimg"; return 0; }
  has_cmd timg && { echo "timg"; return 0; }

  return 1
}

# Verifica se o terminal suporta previews e sugere instalação se necessário
check_preview_support() {
  if _terminal_no_inline_support; then
    return 1
  fi

  # chafa é a solução universal - auto-detecta e suporta todos os protocolos
  if has_cmd chafa; then
    return 0
  fi

  # Sem chafa, verificar se há alternativas
  if has_cmd kitty || has_cmd img2sixel || has_cmd catimg || has_cmd timg; then
    return 0
  fi

  # Nenhuma ferramenta disponível - sugerir instalação do chafa
  warn "Nenhuma ferramenta de preview de imagens encontrada"
  msg "  💡 Para habilitar previews de temas, instale o chafa:"
  case "${TARGET_OS:-linux}" in
    linux|wsl2)
      msg "     sudo apt install chafa           # Debian/Ubuntu"
      msg "     sudo dnf install chafa           # Fedora"
      msg "     sudo pacman -S chafa             # Arch"
      ;;
    macos)
      msg "     brew install chafa"
      ;;
  esac
  msg ""
  msg "  O chafa suporta automaticamente: Ghostty, Kitty, iTerm2, WezTerm,"
  msg "  foot, Windows Terminal e muitos outros terminais modernos."
  msg ""
  return 1
}

theme_preview_resize_image() {
  local src="$1"
  local dest="$2"
  local width="$THEME_PREVIEW_MAX_WIDTH"
  local height="$THEME_PREVIEW_MAX_HEIGHT"

  [[ -f "$dest" ]] && [[ "$dest" -nt "$src" ]] && return 0

  if has_cmd magick; then
    magick "$src" -strip -trim +repage -resize "${width}x${height}>" "$dest" 2>/dev/null && return 0
  fi

  if has_cmd convert; then
    convert "$src" -strip -trim +repage -resize "${width}x${height}>" "$dest" 2>/dev/null && return 0
  fi

  if has_cmd sips && [[ "$OSTYPE" == darwin* ]]; then
    sips --resampleHeightWidthMax "$height" "$src" --out "$dest" 2>/dev/null && return 0
  fi

  if has_cmd ffmpeg; then
    ffmpeg -i "$src" -vf "scale='min($width,iw)':'min($height,ih)':force_original_aspect_ratio=decrease" "$dest" -y 2>/dev/null && return 0
  fi

  cp "$src" "$dest" 2>/dev/null
  return 0
}

download_preview_image() {
  local out="$1"
  shift
  local urls=("$@")

  [[ -s "$out" ]] && return 0

  mkdir -p "$(dirname "$out")"
  local url
  for url in "${urls[@]}"; do
    [[ -z "$url" ]] && continue
    if curl -fsSL --connect-timeout 5 --max-time 15 "$url" -o "$out" 2>/dev/null; then
      [[ -s "$out" ]] && return 0
    fi
    rm -f "$out"
  done
  return 1
}

_render_iterm_inline() {
  local file="$1"
  local name width_px
  name="$(basename "$file")"

  if has_cmd base64; then
    width_px=$(tput cols 2>/dev/null || echo 80)
    width_px=$((width_px * 8))
    [[ $width_px -gt 600 ]] && width_px=600

    printf '\033]1337;File=name=%s;inline=1;width=%spx;preserveAspectRatio=1:' \
      "$(printf '%s' "$name" | base64)" "$width_px"
    base64 < "$file"
    printf '\a\n'
    return 0
  fi
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

  if [[ ! -f "$image_path" ]]; then
    msg "  ℹ️  Prévia indisponível (imagem não encontrada)."
    msg ""
    return
  fi

  local renderer
  renderer="$(theme_preview_renderer || true)"

  if [[ -z "$renderer" ]]; then
    msg "  ℹ️  Prévia inline não disponível (instale chafa para habilitar)."
    [[ -n "$link" ]] && msg "  💡 Acesse o link acima para ver a prévia."
    msg ""
    return
  fi

  local render_path="$image_path"
  local resized_path="${image_path%.*}-preview.${image_path##*.}"

  if theme_preview_resize_image "$image_path" "$resized_path"; then
    render_path="$resized_path"
  fi

  local term_cols
  term_cols=$(tput cols 2>/dev/null || echo 80)
  local chafa_width=$((term_cols - 4))
  [[ $chafa_width -gt 80 ]] && chafa_width=80
  local chafa_height=$((chafa_width / 5))
  [[ $chafa_height -lt 10 ]] && chafa_height=10
  [[ $chafa_height -gt 20 ]] && chafa_height=20

  case "$renderer" in
    chafa)
      # chafa auto-detecta o protocolo correto (Kitty, iTerm2, Sixel, symbols)
      # --animate=off evita problemas com GIFs animados
      chafa --animate=off --size="${chafa_width}x${chafa_height}" "$render_path" 2>/dev/null || \
        msg "  ⚠️  Falha ao renderizar com chafa"
      ;;
    kitty)
      kitty +kitten icat --transfer-mode=stream --align=left "$render_path" 2>/dev/null || \
        msg "  ⚠️  Falha ao renderizar com kitty icat"
      ;;
    sixel)
      img2sixel -w "$((chafa_width * 10))" "$render_path" 2>/dev/null || \
        msg "  ⚠️  Falha ao renderizar com sixel"
      ;;
    catimg)
      catimg -w "$chafa_width" "$render_path" 2>/dev/null || \
        msg "  ⚠️  Falha ao renderizar com catimg"
      ;;
    timg)
      timg -g "${chafa_width}x${chafa_height}" "$render_path" 2>/dev/null || \
        msg "  ⚠️  Falha ao renderizar com timg"
      ;;
  esac

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

resolve_oh_my_posh_preview_url() {
  local theme="$1"
  local html url

  html="$(curl -fsSL https://ohmyposh.dev/docs/themes 2>/dev/null | tr '\n' ' ')"
  [[ -z "$html" ]] && return 1

  url="$(printf '%s' "$html" | awk -v theme="$theme" '{
    split($0, parts, "id=\"" theme "\"");
    if (length(parts) < 2) exit;
    if (match(parts[2], /src="[^"]+"/)) {
      print substr(parts[2], RSTART + 5, RLENGTH - 6);
      exit;
    }
  }')"

  [[ -z "$url" ]] && return 1
  if [[ "$url" == /* ]]; then
    url="https://ohmyposh.dev${url}"
  fi
  printf '%s' "$url"
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

  if ! download_preview_image "$img" "$url1" "$url2" "$url3" "$url4"; then
    local resolved_url=""
    resolved_url="$(resolve_oh_my_posh_preview_url "$theme" || true)"
    if [[ -n "$resolved_url" ]]; then
      download_preview_image "$img" "$resolved_url" || img=""
    else
      img=""
    fi
  fi

  show_theme_preview "Oh My Posh ($theme)" \
    "Tema do Oh My Posh com preset pronto." \
    "https://ohmyposh.dev/docs/themes" \
    "$img"
}

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

    # Verificar e informar sobre suporte a previews
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

    # Montar resumo com separador correto
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

        # Perguntar variante Catppuccin
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

    # Confirmação padronizada
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

    # Confirmação padronizada
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
    # Mapear de volta para nomes sem descrição (pegar primeira palavra)
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
        you-should-use)
          msg "  📥 Baixando you-should-use..."
          if git clone https://github.com/MichaelAquilina/zsh-you-should-use.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ you-should-use instalado"
            INSTALLED_MISC+=("omz-plugin: you-should-use")
          else
            warn "Falha ao clonar you-should-use"
          fi
          ;;
        fzf-tab)
          msg "  📥 Baixando fzf-tab..."
          if git clone https://github.com/Aloxaf/fzf-tab.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ fzf-tab instalado"
            INSTALLED_MISC+=("omz-plugin: fzf-tab")
          else
            warn "Falha ao clonar fzf-tab"
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

      if [[ "$preset" == "catppuccin-powerline" ]] && [[ -n "${SELECTED_CATPPUCCIN_FLAVOR:-}" ]]; then
        if [[ -z "$SELECTED_CATPPUCCIN_FLAVOR" ]]; then
          warn "Sabor Catppuccin não selecionado, usando padrão (mocha)"
          SELECTED_CATPPUCCIN_FLAVOR="catppuccin_mocha"
        fi
        msg "  🎨 Aplicando sabor Catppuccin: ${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}"
        if [[ -f "$starship_config" ]]; then
          sed -i.bak "s/palette = 'catppuccin_mocha'/palette = '$SELECTED_CATPPUCCIN_FLAVOR'/" "$starship_config" && rm -f "${starship_config}.bak"
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

      if [[ ${INSTALL_NUSHELL:-0} -eq 1 ]]; then
        local nu_config_dir="$HOME/.config/nushell"
        mkdir -p "$nu_config_dir"
        cp "$theme_file" "$nu_config_dir/omp-theme.json"
        msg "  ✅ Oh My Posh configurado para Nushell ($nu_config_dir/omp-theme.json)"
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
