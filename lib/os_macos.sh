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

  if NONINTERACTIVE=1 download_and_run_script "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "Homebrew" "/bin/bash"; then
    # Adicionar brew ao PATH para esta sessão
    if command -v brew >/dev/null 2>&1; then
      eval "$(brew shellenv)"
    elif [[ -f "/opt/homebrew/bin/brew" ]]; then
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

brew_install_batch() {
  local level="${1:-optional}"; shift
  local formulas=("$@")
  [[ ${#formulas[@]} -eq 0 ]] && return

  if ! has_cmd brew; then
    record_failure "$level" "Homebrew não disponível"
    return 1
  fi

  local to_install=()
  for formula in "${formulas[@]}"; do
    if ! brew list "$formula" >/dev/null 2>&1; then
      to_install+=("$formula")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    return 0
  fi

  msg "  📦 Instalando ${#to_install[@]} fórmulas via Homebrew (batch)..."
  if brew install "${to_install[@]}" 2>/dev/null; then
    for formula in "${to_install[@]}"; do
      INSTALLED_MISC+=("brew formula: $formula")
    done
  else
    # Fallback: instalar individualmente
    for formula in "${to_install[@]}"; do
      brew_install_formula "$formula" "$level"
    done
  fi
}

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

  brew_install_batch "critical" "${base_formulae[@]}"
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

  for terminal in "${SELECTED_TERMINALS[@]}"; do
    case "$terminal" in
      iterm2) _install_macos_app iterm2 iterm2 "cask:iterm2" ;;
      ghostty) _install_macos_app ghostty ghostty "cask:ghostty" ;;
      kitty) _install_macos_app kitty kitty "cask:kitty" ;;
      alacritty) _install_macos_app alacritty alacritty "cask:alacritty" ;;
      wezterm) _install_macos_app wezterm wezterm "cask:wezterm" ;;
      *)
        if [[ -n "${APP_SOURCES[$terminal]:-}" ]]; then
          _install_macos_app "$terminal" "$terminal"
        else
          record_failure "optional" "Terminal sem instalador automático no macOS: $terminal"
        fi
        ;;
    esac
  done

  for app in "${SELECTED_IDES[@]}"; do
    case "$app" in
      cursor) install_cursor ;;
      windsurf) install_windsurf ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "IDE sem instalador automático no macOS: $app"
        fi
        ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "Navegador sem instalador automático no macOS: $app"
        fi
        ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "Dev tool sem instalador automático no macOS: $app"
        fi
        ;;
    esac
  done

  for app in "${SELECTED_DATABASES[@]}"; do
    case "$app" in
      postgresql) _install_macos_app postgresql psql postgresql ;;
      mysql) _install_macos_app mysql mysql mysql ;;
      redis) _install_macos_app redis redis-cli redis ;;
      mariadb) _install_macos_app mariadb mariadb mariadb ;;
      mongodb) _install_macos_app mongodb mongod mongodb-community ;;
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "Banco sem instalador automático no macOS: $app"
        fi
        ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "App de produtividade sem instalador automático no macOS: $app"
        fi
        ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "App de comunicação sem instalador automático no macOS: $app"
        fi
        ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "App de mídia sem instalador automático no macOS: $app"
        fi
        ;;
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
      *)
        if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
          _install_macos_app "$app" "$app"
        else
          record_failure "optional" "Utilitário sem instalador automático no macOS: $app"
        fi
        ;;
    esac
  done
}

install_ruby_build_deps_macos() {
  local deps=(
    openssl@3
    readline
    libyaml
    libffi
    gmp
    rust
  )
  local dep=""
  for dep in "${deps[@]}"; do
    brew_install_formula "$dep" optional
  done
}

install_php_build_deps_macos() {
  local deps=(
    autoconf
    bison
    re2c
    pkg-config
    libzip
    icu4c
    openssl@3
    readline
    gettext
    curl
  )
  local dep=""
  for dep in "${deps[@]}"; do
    brew_install_formula "$dep" optional
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

  if [[ ${COPY_TERMINAL_CONFIG:-0} -eq 1 ]]; then
    copy_dir "$source_dir/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty"
  else
    msg "  ⏭️  Terminal config (Ghostty): usuário optou por não copiar"
  fi

  if [[ ${COPY_TERMINAL_CONFIG:-0} -eq 1 ]] && [[ -f "$source_dir/rectangle/com.knollsoft.Rectangle.plist" ]]; then
    copy_file "$source_dir/rectangle/com.knollsoft.Rectangle.plist" "$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
    msg "  ✅ Rectangle configurado (reinicie o app para aplicar)"
  fi

  if [[ ${COPY_TERMINAL_CONFIG:-0} -eq 1 ]] && [[ -f "$source_dir/stats/com.exelban.Stats.plist" ]]; then
    copy_file "$source_dir/stats/com.exelban.Stats.plist" "$HOME/Library/Preferences/com.exelban.Stats.plist"
    msg "  ✅ Stats configurado (reinicie o app para aplicar)"
  fi

  if [[ -f "$source_dir/keycastr/keycastr.json" ]]; then
    msg "  📋 KeyCastr: configuração disponível em $source_dir/keycastr/keycastr.json"
    msg "     Lembre-se de dar permissão de Acessibilidade nas Preferências do Sistema"
  fi
}
