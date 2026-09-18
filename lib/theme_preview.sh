#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Variáveis globais para temas
# ═══════════════════════════════════════════════════════════

INSTALL_OH_MY_ZSH=0
INSTALL_POWERLEVEL10K=0
INSTALL_OH_MY_POSH=0
INSTALL_STARSHIP=0

declare -a SELECTED_OMZ_PLUGINS=()
declare -a SELECTED_OMZ_EXTERNAL_PLUGINS=()
declare -a SELECTED_FISH_PLUGINS=()
SELECTED_STARSHIP_PRESET=""
SELECTED_OMP_THEME=""

# ─────────────────────────────────────────────────────────────────
# Globais que atravessam para lib/theme_select.sh e lib/themes.sh
# (fase 4, tarefa C: split de lib/themes.sh em tres arquivos, todos
# carregados no mesmo processo por install.sh — nada muda em runtime).
#
# Declaradas/inicializadas aqui, ESCRITAS pelas funcoes ask_* de
# lib/theme_select.sh e LIDAS la e pelas funcoes install_* de
# lib/themes.sh:
#   INSTALL_OH_MY_ZSH, INSTALL_POWERLEVEL10K, INSTALL_OH_MY_POSH,
#   INSTALL_STARSHIP, SELECTED_OMZ_PLUGINS, SELECTED_OMZ_EXTERNAL_PLUGINS,
#   SELECTED_FISH_PLUGINS, SELECTED_STARSHIP_PRESET, SELECTED_OMP_THEME
#
# SELECTED_CATPPUCCIN_FLAVOR e outra global cruzada, mas nao e declarada
# aqui: nasce em ask_starship_preset (lib/theme_select.sh) e e lida, com
# possivel default, em install_starship (lib/themes.sh).
#
# THEME_PREVIEW_MAX_WIDTH e THEME_PREVIEW_MAX_HEIGHT sao locais a este
# arquivo, nao atravessam para os outros dois.
# ─────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════
# Prévia de temas
# ═══════════════════════════════════════════════════════════

THEME_PREVIEW_MAX_WIDTH=800
THEME_PREVIEW_MAX_HEIGHT=400

theme_preview_cache_dir() {
  local base="${XDG_CACHE_HOME:-$HOME/.cache}"
  echo "$base/dotfiles/theme-previews"
}

# ═══════════════════════════════════════════════════════════
# Detecção de suporte a imagens em terminais
# ═══════════════════════════════════════════════════════════

_terminal_no_inline_support() {
  [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] && return 0
  [[ "${TERM:-}" == "linux" ]] && return 0
  [[ "${TERM:-}" == "dumb" ]] && return 0
  return 1
}

theme_preview_renderer() {
  _terminal_no_inline_support && return 1

  if has_cmd chafa; then
    echo "chafa"
    return 0
  fi

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

  if has_cmd img2sixel; then
    local sixel_term=0
    [[ "${TERM:-}" == *"sixel"* ]] && sixel_term=1
    [[ "${TERM_PROGRAM:-}" == "foot" ]] && sixel_term=1
    [[ "${TERM_PROGRAM:-}" == "mlterm" ]] && sixel_term=1
    [[ "${TERM_PROGRAM:-}" == "contour" ]] && sixel_term=1
    [[ -n "${WT_SESSION:-}" ]] && sixel_term=1  # Windows Terminal
    [[ $sixel_term -eq 1 ]] && { echo "sixel"; return 0; }
  fi

  has_cmd catimg && { echo "catimg"; return 0; }
  has_cmd timg && { echo "timg"; return 0; }

  return 1
}

check_preview_support() {
  if _terminal_no_inline_support; then
    return 1
  fi

  if has_cmd chafa; then
    return 0
  fi

  if has_cmd kitty || has_cmd img2sixel || has_cmd catimg || has_cmd timg; then
    return 0
  fi

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
    if curl -fsSL --connect-timeout 5 --max-time "$CURL_TIMEOUT_FAST" "$url" -o "$out" 2>/dev/null; then
      [[ -s "$out" ]] && return 0
    fi
    rm -f "$out"
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
  term_cols=$(ui_term_cols)
  local chafa_width=$((term_cols - 4))
  [[ $chafa_width -gt 80 ]] && chafa_width=80
  local chafa_height=$((chafa_width / 5))
  [[ $chafa_height -lt 10 ]] && chafa_height=10
  [[ $chafa_height -gt 20 ]] && chafa_height=20

  case "$renderer" in
    chafa)
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

