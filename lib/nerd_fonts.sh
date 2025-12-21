#!/usr/bin/env bash
# Instalação de Nerd Fonts com download dinâmico
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Variáveis globais para Nerd Fonts
# ═══════════════════════════════════════════════════════════

NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-v3.1.1}"
NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download"

# Fontes mais populares e recomendadas
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

# Todas as fontes disponíveis (2025)
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
      # Windows: %LOCALAPPDATA%\Microsoft\Windows\Fonts
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

  # Limpar arquivos temporários antigos se existirem (proteção contra crash anterior)
  rm -rf "$temp_zip" "$temp_dir" 2>/dev/null

  # Download do arquivo zip com timeout de 120s
  if ! timeout 120 curl -fsSL --max-time 120 "$download_url" -o "$temp_zip" 2>/dev/null; then
    if ! timeout 120 curl -fsSL --max-time 120 "$latest_url" -o "$temp_zip" 2>/dev/null; then
      warn "Falha ao baixar $font_name"
      rm -f "$temp_zip" 2>/dev/null
      return 1
    fi
  fi

  # Verificar se o arquivo foi baixado e tem tamanho razoável
  if [[ ! -f "$temp_zip" ]] || [[ ! -s "$temp_zip" ]]; then
    warn "Arquivo de $font_name vazio ou não encontrado"
    rm -f "$temp_zip" 2>/dev/null
    return 1
  fi

  # Criar diretório temporário
  mkdir -p "$temp_dir"

  # Extrair apenas arquivos .ttf e .otf (com timeout para evitar travamento)
  if timeout 60 unzip -q -o "$temp_zip" -d "$temp_dir" 2>/dev/null; then
    # Copiar fontes para o diretório correto
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

  # Limpar arquivos temporários imediatamente para economizar espaço
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
      # macOS atualiza automaticamente, mas podemos forçar
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
  SELECTED_NERD_FONTS=()

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
  msg ""

  local choice=""
  while true; do
    read -r -p "  Digite 1, 2 ou 3: " choice
    case "$choice" in
      1)
        msg ""
        msg "  ✅ Instalando fontes recomendadas..."
        SELECTED_NERD_FONTS=(
          "FiraCode"
          "JetBrainsMono"
          "Hack"
          "Meslo"
          "CascadiaCode"
        )
        break
        ;;
      2)
        msg ""
        select_multiple_items "🔤 Selecione as Nerd Fonts que deseja instalar" SELECTED_NERD_FONTS "${NERD_FONTS_ALL[@]}"
        break
        ;;
      3)
        msg ""
        msg "  ⚠️  AVISO: Instalar todas as fontes baixará ~2GB de dados!"
        if ask_yes_no "Tem certeza que deseja instalar TODAS as ${#NERD_FONTS_ALL[@]} fontes?"; then
          SELECTED_NERD_FONTS=("${NERD_FONTS_ALL[@]}")
          break
        else
          msg "  ↩️  Voltando ao menu..."
          msg ""
          continue
        fi
        ;;
      *)
        msg "  ⚠️  Opção inválida. Digite 1, 2 ou 3."
        ;;
    esac
  done

  if [[ ${#SELECTED_NERD_FONTS[@]} -eq 0 ]]; then
    warn "Nenhuma fonte selecionada"
    return 0
  fi

  msg ""
  msg "✅ Seleção de Nerd Fonts concluída"
  print_selection_summary "🔤 Nerd Fonts" "${SELECTED_NERD_FONTS[@]}"
  msg ""
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

  # Warning para muitas fontes
  if [[ $total_fonts -gt 10 ]]; then
    warn "⚠️  Você selecionou $total_fonts fontes. Isso pode demorar alguns minutos."
    warn "    Cada fonte tem ~20-50MB e precisa ser baixada e extraída."
    msg ""
    if ! ask_yes_no "Deseja continuar com a instalação de todas as $total_fonts fontes?"; then
      msg "  ⏭️  Instalação de fontes cancelada pelo usuário"
      return 0
    fi
    msg ""
  fi

  # Verificar dependências
  if ! has_cmd curl; then
    record_failure "critical" "curl não encontrado - necessário para download de fontes"
    return 1
  fi

  if ! has_cmd unzip; then
    record_failure "critical" "unzip não encontrado - necessário para extrair fontes"
    return 1
  fi

  # Garantir que o diretório de fontes existe
  ensure_fonts_dir || return 1

  # Instalar cada fonte selecionada
  local installed_count=0
  local failed_count=0
  local current=0

  for font in "${SELECTED_NERD_FONTS[@]}"; do
    ((current++))
    msg "  [$current/$total_fonts] Processando $font..."

    # Proteção contra crash: tentar 2x antes de desistir
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

  # Atualizar cache de fontes
  refresh_font_cache

  msg "  ✅ Instalação de Nerd Fonts concluída!"
  msg ""

  # Dica para o usuário
  msg "  💡 DICA: Reinicie seu terminal para ver as novas fontes."
  msg "     Configure seu terminal para usar uma das fontes instaladas:"
  msg ""
  for font in "${SELECTED_NERD_FONTS[@]}"; do
    msg "       • $font Nerd Font"
  done
  msg ""
}
