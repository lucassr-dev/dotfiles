#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Timeout portável
# ═══════════════════════════════════════════════════════════
run_with_timeout() {
  local seconds="$1"
  shift
  if has_cmd timeout; then
    timeout "$seconds" "$@"
  elif has_cmd gtimeout; then
    gtimeout "$seconds" "$@"
  else
    "$@"
  fi
}

# ═══════════════════════════════════════════════════════════
# Variáveis globais para Nerd Fonts
# ═══════════════════════════════════════════════════════════

NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-v3.1.1}"
NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download"

NERD_FONTS_POPULAR=(
  "FiraCode"
  "JetBrainsMono"
  "Hack"
  "Meslo"
  "RobotoMono"
  "SourceCodePro"
  "UbuntuMono"
  "CascadiaCode"
  "Inconsolata"
  "Noto"
)

NERD_FONTS_ALL=(
  "0xProto"
  "3270"
  "Agave"
  "AnonymousPro"
  "Arimo"
  "AurulentSansMono"
  "BitstreamVeraSansMono"
  "CascadiaCode"
  "CodeNewRoman"
  "ComicShannsMono"
  "Cousine"
  "DaddyTimeMono"
  "DejaVuSansMono"
  "DroidSansMono"
  "EnvyCodeR"
  "FantasqueSansMono"
  "FiraCode"
  "FiraMono"
  "GeistMono"
  "Go-Mono"
  "Gohu"
  "Hack"
  "Hasklig"
  "HeavyData"
  "Hermit"
  "iA-Writer"
  "IBMPlexMono"
  "Inconsolata"
  "InconsolataGo"
  "InconsolataLGC"
  "IntelOneMono"
  "Iosevka"
  "IosevkaTerm"
  "JetBrainsMono"
  "Lekton"
  "LiberationMono"
  "Lilex"
  "Meslo"
  "Monaspace"
  "Monofur"
  "Monoid"
  "Mononoki"
  "MPlus"
  "NerdFontsSymbolsOnly"
  "Noto"
  "OpenDyslexic"
  "Overpass"
  "ProFont"
  "ProggyClean"
  "Recursive"
  "RobotoMono"
  "ShareTechMono"
  "SourceCodePro"
  "SpaceMono"
  "Terminus"
  "Tinos"
  "Ubuntu"
  "UbuntuMono"
  "UbuntuSans"
  "VictorMono"
)

declare -a SELECTED_NERD_FONTS=()

# ═══════════════════════════════════════════════════════════
# Funções auxiliares para instalação de fontes
# ═══════════════════════════════════════════════════════════

get_fonts_dir() {
  case "$TARGET_OS" in
    linux|wsl2)
      echo "$HOME/.local/share/fonts"
      ;;
    macos)
      echo "$HOME/Library/Fonts"
      ;;
    windows)
      echo "$LOCALAPPDATA/Microsoft/Windows/Fonts"
      ;;
    *)
      echo "$HOME/.fonts"
      ;;
  esac
}

ensure_fonts_dir() {
  local fonts_dir
  fonts_dir="$(get_fonts_dir)"

  if [[ ! -d "$fonts_dir" ]]; then
    msg "  📁 Criando diretório de fontes: $fonts_dir"
    mkdir -p "$fonts_dir" || {
      record_failure "optional" "Falha ao criar diretório de fontes: $fonts_dir"
      return 1
    }
  fi

  return 0
}

download_and_install_font() {
  local font_name="$1"
  local fonts_dir
  fonts_dir="$(get_fonts_dir)"

  local download_url="$NERD_FONTS_BASE_URL/$NERD_FONTS_VERSION/${font_name}.zip"
  local latest_url="$NERD_FONTS_BASE_URL/latest/download/${font_name}.zip"
  local temp_zip="/tmp/${font_name}.zip"
  local temp_dir="/tmp/nerd-fonts-${font_name}"

  rm -rf "$temp_zip" "$temp_dir" 2>/dev/null

  if ! run_with_timeout 120 curl -fsSL --max-time 120 "$download_url" -o "$temp_zip"; then
    msg "  ⚠️  URL versão específica falhou, tentando latest..."
    if ! run_with_timeout 120 curl -fsSL --max-time 120 "$latest_url" -o "$temp_zip"; then
      warn "Falha ao baixar $font_name"
      rm -f "$temp_zip" 2>/dev/null
      return 1
    fi
  fi

  if [[ ! -f "$temp_zip" ]] || [[ ! -s "$temp_zip" ]]; then
    warn "Arquivo de $font_name vazio ou não encontrado"
    rm -f "$temp_zip" 2>/dev/null
    return 1
  fi

  mkdir -p "$temp_dir"

  if run_with_timeout 60 unzip -o "$temp_zip" -d "$temp_dir"; then
    local font_count=0
    while IFS= read -r -d '' font_file; do
      cp -f "$font_file" "$fonts_dir/" 2>/dev/null && ((font_count++))
    done < <(find "$temp_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 2>/dev/null)

    if [[ $font_count -gt 0 ]]; then
      INSTALLED_MISC+=("nerd-font: $font_name")
    else
      warn "Nenhum arquivo de fonte encontrado em $font_name"
      rm -rf "$temp_zip" "$temp_dir" 2>/dev/null
      return 1
    fi
  else
    warn "Falha ao extrair $font_name"
    rm -rf "$temp_zip" "$temp_dir" 2>/dev/null
    return 1
  fi

  rm -rf "$temp_zip" "$temp_dir" 2>/dev/null
  return 0
}

refresh_font_cache() {
  case "$TARGET_OS" in
    linux|wsl2)
      if has_cmd fc-cache; then
        msg "  🔄 Atualizando cache de fontes (fc-cache)..."
        fc-cache -f "$(get_fonts_dir)" >/dev/null 2>&1 || true
      fi
      ;;
    macos)
      msg "  🔄 Cache de fontes será atualizado automaticamente pelo macOS"
      ;;
    windows)
      msg "  ℹ️  Reinicie aplicativos para ver as novas fontes"
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Tela de informação sobre Nerd Fonts
# ═══════════════════════════════════════════════════════════

show_nerd_fonts_info() {
  show_section_header "🔤 NERD FONTS - Fontes com Ícones e Símbolos"

  msg "Nerd Fonts são fontes patcheadas com milhares de ícones e símbolos."
  msg ""
  msg "⚠️  Por que são essenciais:"
  msg ""
  msg "  • Temas de shell (Starship, Oh My Zsh, Oh My Posh) usam ícones"
  msg "  • Terminais modernos (Ghostty, Kitty, Alacritty) exibem símbolos"
  msg "  • IDEs e editores (VS Code, Neovim) mostram file icons"
  msg "  • Ferramentas CLI (eza, lsd, bat) usam ícones coloridos"
  msg "  • Sem elas, você verá '�' ou '?' no lugar de ícones, temas podem quebrar"
  msg ""
  msg "📦 Onde serão instaladas:"
  msg ""

  case "$TARGET_OS" in
    linux|wsl2)
      msg "  • Linux/WSL2: ~/.local/share/fonts (user fonts directory)"
      ;;
    macos)
      msg "  • macOS: ~/Library/Fonts (user Library folder)"
      ;;
    windows)
      msg "  • Windows: %LOCALAPPDATA%\\Microsoft\\Windows\\Fonts (AppData\\Local)"
      ;;
  esac

  msg ""
  msg "🎨 Fontes recomendadas:"
  msg ""
  msg "  • FiraCode       - Ligaduras elegantes, muito popular"
  msg "  • JetBrainsMono  - Ótima legibilidade, feita para código"
  msg "  • Hack           - Limpa e clara, boa para terminais"
  msg "  • Meslo          - Derivada da Menlo, excelente no macOS"
  msg "  • CascadiaCode   - Moderna, feita pela Microsoft"
  msg ""
}

# ═══════════════════════════════════════════════════════════
# Seleção de Nerd Fonts
# ═══════════════════════════════════════════════════════════

ask_nerd_fonts() {
  while true; do
    SELECTED_NERD_FONTS=()
    clear_screen
    show_nerd_fonts_info

    msg ""
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  🎯 ESCOLHA SUAS FONTES"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg ""
    msg "Escolha uma das opções:"
    msg ""
    msg "  1) Instalar apenas fontes recomendadas (5 fontes mais populares)"
    msg "  2) Escolher fontes manualmente (lista completa)"
    msg "  3) Instalar todas as fontes disponíveis (~2GB)"
    msg "  4) Pular instalação de fontes"
    msg ""

    local choice=""
    local selection_done=0
    while [[ $selection_done -eq 0 ]]; do
      read -r -p "  Digite 1, 2, 3 ou 4: " choice
      case "$choice" in
        1)
          SELECTED_NERD_FONTS=("FiraCode" "JetBrainsMono" "Hack" "Meslo" "CascadiaCode")
          selection_done=1
          ;;
        2)
          msg ""
          select_multiple_items "🔤 Selecione as Nerd Fonts que deseja instalar" SELECTED_NERD_FONTS "${NERD_FONTS_ALL[@]}"
          selection_done=1
          ;;
        3)
          msg ""
          msg "  ⚠️  AVISO: Instalar todas as fontes baixará ~2GB de dados!"
          msg ""
          echo -e "  ${UI_CYAN}Enter${UI_RESET} para confirmar  │  ${UI_YELLOW}P${UI_RESET} para voltar"
          local confirm_all
          read -r -p "  → " confirm_all
          if [[ "${confirm_all,,}" != "p" ]]; then
            SELECTED_NERD_FONTS=("${NERD_FONTS_ALL[@]}")
            selection_done=1
          fi
          ;;
        4)
          SELECTED_NERD_FONTS=()
          selection_done=1
          ;;
        *)
          msg "  ⚠️  Opção inválida. Digite 1, 2, 3 ou 4."
          ;;
      esac
    done

    local fonts_summary=()
    if [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]]; then
      fonts_summary=("${SELECTED_NERD_FONTS[@]}")
    else
      fonts_summary=("(nenhuma)")
    fi

    if confirm_selection "🔤 Nerd Fonts" "${fonts_summary[@]}"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Instalação das Nerd Fonts selecionadas
# ═══════════════════════════════════════════════════════════

install_nerd_fonts() {
  [[ ${#SELECTED_NERD_FONTS[@]} -eq 0 ]] && return 0

  local total_fonts=${#SELECTED_NERD_FONTS[@]}

  msg "▶ Instalando Nerd Fonts"
  msg "  📍 Versão: $NERD_FONTS_VERSION"
  msg "  📂 Destino: $(get_fonts_dir)"
  msg "  📊 Total: $total_fonts fonte(s)"
  msg ""

  if [[ $total_fonts -gt 10 ]]; then
    warn "⚠️  Você selecionou $total_fonts fontes. Isso pode demorar alguns minutos."
    warn "    Cada fonte tem ~20-50MB e precisa ser baixada e extraída."
    msg ""
    echo -e "  ${UI_CYAN}Enter${UI_RESET} para continuar  │  ${UI_YELLOW}P${UI_RESET} para pular"
    local continue_choice
    read -r -p "  → " continue_choice
    if [[ "${continue_choice,,}" == "p" ]]; then
      msg "  ⏭️  Instalação de fontes cancelada pelo usuário"
      return 0
    fi
    msg ""
  fi

  if ! has_cmd curl; then
    record_failure "critical" "curl não encontrado - necessário para download de fontes"
    return 1
  fi

  if ! has_cmd unzip; then
    record_failure "critical" "unzip não encontrado - necessário para extrair fontes"
    return 1
  fi

  ensure_fonts_dir || return 1

  local installed_count=0
  local failed_count=0
  local current=0

  for font in "${SELECTED_NERD_FONTS[@]}"; do
    ((current++))
    msg "  [$current/$total_fonts] Processando $font..."

    if download_and_install_font "$font"; then
      ((installed_count++))
    elif download_and_install_font "$font"; then
      msg "  ✅ Sucesso na 2ª tentativa para $font"
      ((installed_count++))
    else
      ((failed_count++))
      msg "  ❌ Falha ao instalar $font após 2 tentativas"
      record_failure "optional" "Falha ao instalar fonte: $font"
    fi
  done

  msg ""
  msg "  📊 Resumo da instalação:"
  msg "    ✅ Instaladas: $installed_count"
  [[ $failed_count -gt 0 ]] && msg "    ❌ Falharam: $failed_count"
  msg ""

  refresh_font_cache

  msg "  ✅ Instalação de Nerd Fonts concluída!"
  msg ""
}
