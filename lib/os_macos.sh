#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Auto-instalação do Homebrew
# ═══════════════════════════════════════════════════════════

ensure_homebrew() {
  if has_cmd brew; then
    return 0
  fi

  msg "▶ Homebrew não encontrado - instalando automaticamente..."
  msg "  ℹ️  Isso pode demorar alguns minutos na primeira execução"

  if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    # Adicionar brew ao PATH para esta sessão
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    if has_cmd brew; then
      INSTALLED_MISC+=("homebrew: install.sh")
      msg "  ✅ Homebrew instalado com sucesso"
      return 0
    fi
  fi

  record_failure "critical" "Falha ao instalar Homebrew automaticamente"
  return 1
}

# ═══════════════════════════════════════════════════════════
# Funções de suporte para Homebrew
# ═══════════════════════════════════════════════════════════

brew_install_formula() {
  local formula="$1"
  local level="${2:-optional}"

  if ! has_cmd brew; then
    record_failure "$level" "Homebrew não disponível; não foi possível instalar $formula"
    return
  fi

  if brew list "$formula" >/dev/null 2>&1; then
    msg "  🔄 Atualizando $formula..."
    if brew upgrade "$formula"; then
      INSTALLED_MISC+=("brew formula: $formula (upgrade)")
    fi
    return 0
  fi

  msg "  📦 Instalando $formula via Homebrew..."
  if brew install "$formula"; then
    INSTALLED_MISC+=("brew formula: $formula")
  else
    record_failure "$level" "Falha ao instalar formula: $formula"
  fi
}

brew_install_cask() {
  local cask="$1"
  local level="${2:-optional}"

  if ! has_cmd brew; then
    record_failure "$level" "Homebrew não disponível; não foi possível instalar $cask"
    return
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    msg "  🔄 Atualizando $cask..."
    if brew upgrade --cask "$cask"; then
      INSTALLED_MISC+=("brew cask: $cask (upgrade)")
    fi
    return 0
  fi

  msg "  📦 Instalando $cask via Homebrew Cask..."
  if brew install --cask "$cask"; then
    INSTALLED_MISC+=("brew cask: $cask")
  else
    record_failure "$level" "Falha ao instalar cask: $cask"
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de dependências base no macOS
# ═══════════════════════════════════════════════════════════

install_macos_base_dependencies() {
  # Garantir que Homebrew está instalado (auto-instala se necessário)
  ensure_homebrew || return 1

  msg "▶ Atualizando Homebrew (brew update)"
  if brew update; then
    INSTALLED_MISC+=("brew: update")
  else
    warn "Falha ao rodar brew update"
  fi

  msg "▶ Verificando dependências macOS (Homebrew)"

  local base_formulae=(
    git
    curl
    wget
    imagemagick
    chafa
    fzf
    gum
  )

  for formula in "${base_formulae[@]}"; do
    brew_install_formula "$formula" "critical"
  done
}

# ═══════════════════════════════════════════════════════════
# Instalação de shells selecionados no macOS
# ═══════════════════════════════════════════════════════════

install_macos_shells() {
  if [[ ${INSTALL_ZSH:-0} -eq 1 ]] && ! has_cmd zsh; then
    brew_install_formula zsh optional
  fi

  if [[ ${INSTALL_FISH:-0} -eq 1 ]] && ! has_cmd fish; then
    brew_install_formula fish optional
  fi

  if [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && ! has_cmd nu; then
    brew_install_formula nushell optional
  fi
}

# ═══════════════════════════════════════════════════════════
# Geração dinâmica do Brewfile (apenas apps fora do catálogo)
# ═══════════════════════════════════════════════════════════
# NOTA: Apps que estão em APP_SOURCES já são instalados via
#       install_with_priority(). O Brewfile contém apenas apps
#       específicos do macOS que não têm entrada no catálogo.

generate_dynamic_brewfile() {
  local brewfile="$HOME/Brewfile"
  local has_entries=0

  msg "▶ Gerando Brewfile para apps específicos do macOS"

  cat > "$brewfile" <<EOF
# Brewfile gerado automaticamente pelo dotfiles installer
# Data: $(date)
# NOTA: Contém apenas apps específicos do macOS não gerenciados pelo catálogo

# Taps
tap "homebrew/bundle"
tap "homebrew/cask"
tap "homebrew/cask-fonts"

EOF

  # Helper: adiciona ao brewfile apenas se NÃO estiver no catálogo APP_SOURCES
  _add_if_not_in_catalog() {
    local app="$1"
    local brew_entry="$2"
    if [[ -z "${APP_SOURCES[$app]:-}" ]]; then
      echo "$brew_entry" >> "$brewfile"
      has_entries=1
    fi
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Terminais (muitos são macOS-only)
  # ─────────────────────────────────────────────────────────────────────────────
  if [[ ${#SELECTED_TERMINALS[@]} -gt 0 ]]; then
    echo "# Terminais" >> "$brewfile"
    for terminal in "${SELECTED_TERMINALS[@]}"; do
      case "$terminal" in
        iterm2) _add_if_not_in_catalog iterm2 "cask \"iterm2\"" ;;
        ghostty) _add_if_not_in_catalog ghostty "cask \"ghostty\"" ;;
        kitty) _add_if_not_in_catalog kitty "cask \"kitty\"" ;;
        alacritty) _add_if_not_in_catalog alacritty "cask \"alacritty\"" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  # ─────────────────────────────────────────────────────────────────────────────
  # IDEs JetBrains (não estão no catálogo)
  # ─────────────────────────────────────────────────────────────────────────────
  if [[ ${#SELECTED_IDES[@]} -gt 0 ]]; then
    echo "# IDEs" >> "$brewfile"
    for ide in "${SELECTED_IDES[@]}"; do
      case "$ide" in
        intellij-idea) _add_if_not_in_catalog intellij-idea "cask \"intellij-idea-ce\"" ;;
        pycharm) _add_if_not_in_catalog pycharm "cask \"pycharm-ce\"" ;;
        webstorm) _add_if_not_in_catalog webstorm "cask \"webstorm\"" ;;
        phpstorm) _add_if_not_in_catalog phpstorm "cask \"phpstorm\"" ;;
        goland) _add_if_not_in_catalog goland "cask \"goland\"" ;;
        rubymine) _add_if_not_in_catalog rubymine "cask \"rubymine\"" ;;
        clion) _add_if_not_in_catalog clion "cask \"clion\"" ;;
        rider) _add_if_not_in_catalog rider "cask \"rider\"" ;;
        datagrip) _add_if_not_in_catalog datagrip "cask \"datagrip\"" ;;
        android-studio) _add_if_not_in_catalog android-studio "cask \"android-studio\"" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  # ─────────────────────────────────────────────────────────────────────────────
  # Utilitários específicos macOS (Rectangle, Alfred, etc.)
  # ─────────────────────────────────────────────────────────────────────────────
  if [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]]; then
    echo "# Utilitários macOS" >> "$brewfile"
    for app in "${SELECTED_UTILITIES[@]}"; do
      case "$app" in
        rectangle) _add_if_not_in_catalog rectangle "cask \"rectangle\"" ;;
        alfred) _add_if_not_in_catalog alfred "cask \"alfred\"" ;;
        bartender) _add_if_not_in_catalog bartender "cask \"bartender\"" ;;
        cleanmymac) _add_if_not_in_catalog cleanmymac "cask \"cleanmymac\"" ;;
        istat-menus) _add_if_not_in_catalog istat-menus "cask \"istat-menus\"" ;;
        veracrypt) _add_if_not_in_catalog veracrypt "cask \"veracrypt\"" ;;
        balenaetcher) _add_if_not_in_catalog balenaetcher "cask \"balenaetcher\"" ;;
        rclone) _add_if_not_in_catalog rclone "brew \"rclone\"" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ $has_entries -eq 1 ]]; then
    msg "  ✅ Brewfile gerado em: $brewfile"
  else
    msg "  ℹ️  Nenhum app adicional para Brewfile (todos já estão no catálogo)"
    rm -f "$brewfile"
  fi
}

install_from_brewfile() {
  local brewfile="$HOME/Brewfile"

  if [[ ! -f "$brewfile" ]]; then
    msg "  ℹ️  Nenhum Brewfile encontrado, pulando"
    return
  fi

  if ! has_cmd brew; then
    warn "Homebrew não disponível, não foi possível instalar do Brewfile"
    return
  fi

  msg "▶ Instalando apps do Brewfile"
  msg "  ℹ️  Arquivo: $brewfile"

  if brew bundle --file="$brewfile"; then
    INSTALLED_MISC+=("brewfile: instalação completa")
    msg "  ✅ Apps do Brewfile instalados com sucesso"
  else
    record_failure "optional" "Alguns apps do Brewfile falharam ao instalar"
  fi
}

# ═══════════════════════════════════════════════════════════
# Helper: instalar app usando o catálogo ou fallback para brew
# ═══════════════════════════════════════════════════════════

_install_macos_app() {
  local app="$1"
  local cmd_check="${2:-$app}"
  local brew_pkg="${3:-}"

  if is_app_processed "$app"; then
    return 0
  fi
  mark_app_processed "$app"

  if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
    install_with_priority "$app" "$cmd_check" optional
  elif [[ -n "$brew_pkg" ]]; then
    if [[ "$brew_pkg" == "cask:"* ]]; then
      brew_install_cask "${brew_pkg#cask:}" optional
    else
      brew_install_formula "$brew_pkg" optional
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de apps GUI selecionados no macOS
# ═══════════════════════════════════════════════════════════

install_macos_selected_apps() {
  msg "▶ Instalando apps GUI selecionados (macOS)"

  for app in "${SELECTED_IDES[@]}"; do
    case "$app" in
      cursor) install_cursor ;;
      xcode) msg "  ℹ️  Xcode deve ser instalado via App Store." ;;
      vscode) _install_macos_app vscode code "cask:visual-studio-code" ;;
      zed) _install_macos_app zed zed "cask:zed" ;;
      neovim) _install_macos_app neovim nvim neovim ;;
      sublime-text) _install_macos_app sublime-text subl "cask:sublime-text" ;;
      intellij-idea) _install_macos_app intellij-idea idea "cask:intellij-idea-ce" ;;
      pycharm) _install_macos_app pycharm pycharm "cask:pycharm-ce" ;;
      webstorm) _install_macos_app webstorm webstorm "cask:webstorm" ;;
      phpstorm) _install_macos_app phpstorm phpstorm "cask:phpstorm" ;;
      goland) _install_macos_app goland goland "cask:goland" ;;
      rubymine) _install_macos_app rubymine rubymine "cask:rubymine" ;;
      clion) _install_macos_app clion clion "cask:clion" ;;
      rider) _install_macos_app rider rider "cask:rider" ;;
      datagrip) _install_macos_app datagrip datagrip "cask:datagrip" ;;
      android-studio) _install_macos_app android-studio studio "cask:android-studio" ;;
    esac
  done

  for app in "${SELECTED_BROWSERS[@]}"; do
    case "$app" in
      firefox) _install_macos_app firefox firefox "cask:firefox" ;;
      chrome) _install_macos_app chrome "google-chrome" "cask:google-chrome" ;;
      brave) _install_macos_app brave brave "cask:brave-browser" ;;
      arc) _install_macos_app arc arc "cask:arc" ;;
      zen) _install_macos_app zen zen "cask:zen-browser" ;;
      vivaldi) _install_macos_app vivaldi vivaldi "cask:vivaldi" ;;
      edge) _install_macos_app edge edge "cask:microsoft-edge" ;;
      opera) _install_macos_app opera opera "cask:opera" ;;
      librewolf) _install_macos_app librewolf librewolf "cask:librewolf" ;;
    esac
  done

  for app in "${SELECTED_DEV_TOOLS[@]}"; do
    case "$app" in
      docker) _install_macos_app docker docker "cask:docker" ;;
      postman) _install_macos_app postman postman "cask:postman" ;;
      dbeaver) _install_macos_app dbeaver dbeaver "cask:dbeaver-community" ;;
      bruno) _install_macos_app bruno bruno "cask:bruno" ;;
      insomnia) _install_macos_app insomnia insomnia "cask:insomnia" ;;
      gitkraken) _install_macos_app gitkraken gitkraken "cask:gitkraken" ;;
      mongodb-compass) _install_macos_app mongodb-compass "MongoDB Compass" "cask:mongodb-compass" ;;
      redis-insight) install_redis_insight ;;
    esac
  done

  for app in "${SELECTED_DATABASES[@]}"; do
    case "$app" in
      postgresql) _install_macos_app postgresql psql postgresql@16 ;;
      mysql) _install_macos_app mysql mysql mysql ;;
      redis) _install_macos_app redis redis-cli redis ;;
      mariadb) _install_macos_app mariadb mariadb mariadb ;;
      mongodb) _install_macos_app mongodb mongod mongodb-community ;;
    esac
  done

  for app in "${SELECTED_PRODUCTIVITY[@]}"; do
    case "$app" in
      slack) _install_macos_app slack slack "cask:slack" ;;
      notion) _install_macos_app notion notion "cask:notion" ;;
      obsidian) _install_macos_app obsidian obsidian "cask:obsidian" ;;
      logseq) _install_macos_app logseq logseq "cask:logseq" ;;
      anki) _install_macos_app anki anki "cask:anki" ;;
      joplin) _install_macos_app joplin joplin "cask:joplin" ;;
      appflowy) _install_macos_app appflowy appflowy "cask:appflowy" ;;
    esac
  done

  for app in "${SELECTED_COMMUNICATION[@]}"; do
    case "$app" in
      discord) _install_macos_app discord discord "cask:discord" ;;
      telegram) _install_macos_app telegram telegram "cask:telegram" ;;
      whatsapp) _install_macos_app whatsapp whatsapp "cask:whatsapp" ;;
      signal) _install_macos_app signal signal "cask:signal" ;;
      teams) _install_macos_app teams teams "cask:microsoft-teams" ;;
      zoom) _install_macos_app zoom zoom "cask:zoom" ;;
      thunderbird) _install_macos_app thunderbird thunderbird "cask:thunderbird" ;;
    esac
  done

  for app in "${SELECTED_MEDIA[@]}"; do
    case "$app" in
      vlc) _install_macos_app vlc vlc "cask:vlc" ;;
      spotify) _install_macos_app spotify spotify "cask:spotify" ;;
      obs-studio) _install_macos_app obs-studio obs "cask:obs" ;;
      gimp) _install_macos_app gimp gimp "cask:gimp" ;;
      inkscape) _install_macos_app inkscape inkscape "cask:inkscape" ;;
      blender) _install_macos_app blender blender "cask:blender" ;;
      audacity) _install_macos_app audacity audacity "cask:audacity" ;;
      kdenlive) _install_macos_app kdenlive kdenlive "cask:kdenlive" ;;
    esac
  done

  for app in "${SELECTED_UTILITIES[@]}"; do
    case "$app" in
      rectangle) brew_install_cask rectangle optional ;;
      alfred) brew_install_cask alfred optional ;;
      bartender) brew_install_cask bartender optional ;;
      cleanmymac) brew_install_cask cleanmymac optional ;;
      istat-menus) brew_install_cask istat-menus optional ;;
      bitwarden) _install_macos_app bitwarden bitwarden "cask:bitwarden" ;;
      1password) _install_macos_app 1password 1password "cask:1password" ;;
      keepassxc) _install_macos_app keepassxc keepassxc "cask:keepassxc" ;;
      syncthing) _install_macos_app syncthing syncthing syncthing ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════
# Aplicação de configurações específicas do macOS
# ═══════════════════════════════════════════════════════════

apply_macos_configs() {
  local source_dir="$CONFIG_MACOS"
  [[ -d "$source_dir" ]] || source_dir="$CONFIG_UNIX_LEGACY"
  [[ -d "$source_dir" ]] || return
  msg "▶ Copiando configs macOS"

  if [[ -d "$source_dir/ghostty" ]]; then
    copy_dir "$source_dir/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty"
  fi
}
