#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Anti-duplicidade: rastrear apps já processados nesta execução
# ═══════════════════════════════════════════════════════════

declare -A APPS_PROCESSED

mark_app_processed() {
  local app="$1"
  APPS_PROCESSED["$app"]=1
}

is_app_processed() {
  local app="$1"
  [[ "${APPS_PROCESSED[$app]:-0}" == "1" ]]
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
  if ! has_cmd brew; then
    record_failure "critical" "Homebrew não encontrado. Instale via https://brew.sh"
    return
  fi

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
# Geração dinâmica do Brewfile
# ═══════════════════════════════════════════════════════════

generate_dynamic_brewfile() {
  local brewfile="$HOME/Brewfile"

  msg "▶ Gerando Brewfile dinâmico com apps selecionados"

  cat > "$brewfile" <<EOF
# Brewfile gerado automaticamente pelo dotfiles installer
# Data: $(date)
# IMPORTANTE: Este arquivo foi criado baseado nas suas seleções

# Taps
tap "homebrew/bundle"
tap "homebrew/cask"
tap "homebrew/cask-fonts"
tap "homebrew/core"

EOF

  if [[ ${#SELECTED_CLI_TOOLS[@]} -gt 0 ]]; then
    echo "# CLI Tools selecionadas" >> "$brewfile"
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do
      case "$tool" in
        fzf) echo "brew \"fzf\"" >> "$brewfile" ;;
        zoxide) echo "brew \"zoxide\"" >> "$brewfile" ;;
        eza) echo "brew \"eza\"" >> "$brewfile" ;;
        bat) echo "brew \"bat\"" >> "$brewfile" ;;
        ripgrep) echo "brew \"ripgrep\"" >> "$brewfile" ;;
        fd) echo "brew \"fd\"" >> "$brewfile" ;;
        delta) echo "brew \"git-delta\"" >> "$brewfile" ;;
        lazygit) echo "brew \"lazygit\"" >> "$brewfile" ;;
        gh) echo "brew \"gh\"" >> "$brewfile" ;;
        jq) echo "brew \"jq\"" >> "$brewfile" ;;
        direnv) echo "brew \"direnv\"" >> "$brewfile" ;;
        btop) echo "brew \"btop\"" >> "$brewfile" ;;
        tmux) echo "brew \"tmux\"" >> "$brewfile" ;;
        starship) echo "brew \"starship\"" >> "$brewfile" ;;
        atuin) echo "brew \"atuin\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_TERMINALS[@]} -gt 0 ]]; then
    echo "# Terminais selecionados" >> "$brewfile"
    for terminal in "${SELECTED_TERMINALS[@]}"; do
      case "$terminal" in
        iterm2) echo "cask \"iterm2\"" >> "$brewfile" ;;
        ghostty) echo "cask \"ghostty\"" >> "$brewfile" ;;
        kitty) echo "cask \"kitty\"" >> "$brewfile" ;;
        alacritty) echo "cask \"alacritty\"" >> "$brewfile" ;;
        wezterm) echo "cask \"wezterm\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_BROWSERS[@]} -gt 0 ]]; then
    echo "# Navegadores selecionados" >> "$brewfile"
    for browser in "${SELECTED_BROWSERS[@]}"; do
      case "$browser" in
        firefox) echo "cask \"firefox\"" >> "$brewfile" ;;
        chrome) echo "cask \"google-chrome\"" >> "$brewfile" ;;
        brave) echo "cask \"brave-browser\"" >> "$brewfile" ;;
        arc) echo "cask \"arc\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_IDES[@]} -gt 0 ]]; then
    echo "# IDEs e editores selecionados" >> "$brewfile"
    for ide in "${SELECTED_IDES[@]}"; do
      case "$ide" in
        vscode) echo "cask \"visual-studio-code\"" >> "$brewfile" ;;
        zed) echo "cask \"zed\"" >> "$brewfile" ;;
        neovim) echo "brew \"neovim\"" >> "$brewfile" ;;
        intellij-idea) echo "cask \"intellij-idea-ce\"" >> "$brewfile" ;;
        pycharm) echo "cask \"pycharm-ce\"" >> "$brewfile" ;;
        webstorm) echo "cask \"webstorm\"" >> "$brewfile" ;;
        phpstorm) echo "cask \"phpstorm\"" >> "$brewfile" ;;
        goland) echo "cask \"goland\"" >> "$brewfile" ;;
        rubymine) echo "cask \"rubymine\"" >> "$brewfile" ;;
        clion) echo "cask \"clion\"" >> "$brewfile" ;;
        rider) echo "cask \"rider\"" >> "$brewfile" ;;
        datagrip) echo "cask \"datagrip\"" >> "$brewfile" ;;
        sublime-text) echo "cask \"sublime-text\"" >> "$brewfile" ;;
        android-studio) echo "cask \"android-studio\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_DEV_TOOLS[@]} -gt 0 ]]; then
    echo "# Ferramentas de desenvolvimento selecionadas" >> "$brewfile"
    for tool in "${SELECTED_DEV_TOOLS[@]}"; do
      case "$tool" in
        vscode) echo "cask \"visual-studio-code\"" >> "$brewfile" ;;
        docker) echo "cask \"docker\"" >> "$brewfile" ;;
        postman) echo "cask \"postman\"" >> "$brewfile" ;;
        dbeaver) echo "cask \"dbeaver-community\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_DATABASES[@]} -gt 0 ]]; then
    echo "# Bancos de dados selecionados" >> "$brewfile"
    for db in "${SELECTED_DATABASES[@]}"; do
      case "$db" in
        postgresql) echo "brew \"postgresql@16\"" >> "$brewfile" ;;
        redis) echo "brew \"redis\"" >> "$brewfile" ;;
        mysql) echo "brew \"mysql\"" >> "$brewfile" ;;
        mongodb) echo "brew \"mongodb-community\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_PRODUCTIVITY[@]} -gt 0 ]]; then
    echo "# Produtividade selecionada" >> "$brewfile"
    for app in "${SELECTED_PRODUCTIVITY[@]}"; do
      case "$app" in
        slack) echo "cask \"slack\"" >> "$brewfile" ;;
        notion) echo "cask \"notion\"" >> "$brewfile" ;;
        obsidian) echo "cask \"obsidian\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_COMMUNICATION[@]} -gt 0 ]]; then
    echo "# Comunicação selecionada" >> "$brewfile"
    for app in "${SELECTED_COMMUNICATION[@]}"; do
      case "$app" in
        discord) echo "cask \"discord\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_MEDIA[@]} -gt 0 ]]; then
    echo "# Mídia selecionada" >> "$brewfile"
    for app in "${SELECTED_MEDIA[@]}"; do
      case "$app" in
        vlc) echo "cask \"vlc\"" >> "$brewfile" ;;
        spotify) echo "cask \"spotify\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  if [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]]; then
    echo "# Utilitários selecionados" >> "$brewfile"
    for app in "${SELECTED_UTILITIES[@]}"; do
      case "$app" in
        rectangle) echo "cask \"rectangle\"" >> "$brewfile" ;;
        alfred) echo "cask \"alfred\"" >> "$brewfile" ;;
        bartender) echo "cask \"bartender\"" >> "$brewfile" ;;
        cleanmymac) echo "cask \"cleanmymac\"" >> "$brewfile" ;;
        istat-menus) echo "cask \"istat-menus\"" >> "$brewfile" ;;
        bitwarden) echo "cask \"bitwarden\"" >> "$brewfile" ;;
        1password) echo "cask \"1password\"" >> "$brewfile" ;;
        keepassxc) echo "cask \"keepassxc\"" >> "$brewfile" ;;
        veracrypt) echo "cask \"veracrypt\"" >> "$brewfile" ;;
        balenaetcher) echo "cask \"balenaetcher\"" >> "$brewfile" ;;
        syncthing) echo "brew \"syncthing\"" >> "$brewfile" ;;
        rclone) echo "brew \"rclone\"" >> "$brewfile" ;;
      esac
    done
    echo "" >> "$brewfile"
  fi

  msg "  ✅ Brewfile gerado em: $brewfile"
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

install_macos_selected_apps() {
  msg "▶ Instalando apps GUI selecionados (macOS)"

  for app in "${SELECTED_IDES[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      cursor) install_cursor ;;
      xcode) msg "  ℹ️  Xcode deve ser instalado via App Store." ;;
      *) ;;
    esac
  done

  for app in "${SELECTED_BROWSERS[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      firefox) brew_install_cask firefox optional ;;
      chrome) brew_install_cask google-chrome optional ;;
      brave) brew_install_cask brave-browser optional ;;
      zen) warn "Zen Browser não disponível via Homebrew; instale manualmente." ;;
      *) ;;
    esac
  done

  for app in "${SELECTED_DEV_TOOLS[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      docker) brew_install_cask docker optional ;;
      postman) brew_install_cask postman optional ;;
      dbeaver) brew_install_cask dbeaver-community optional ;;
      *) ;;
    esac
  done

  for app in "${SELECTED_DATABASES[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      postgresql) brew_install_formula postgresql@16 optional ;;
      mysql) brew_install_formula mysql optional ;;
      redis) brew_install_formula redis optional ;;
      mariadb) brew_install_formula mariadb optional ;;
      mongodb) brew_install_formula mongodb-community optional ;;
      *) ;;
    esac
  done

  for app in "${SELECTED_PRODUCTIVITY[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      slack) brew_install_cask slack optional ;;
      notion) brew_install_cask notion optional ;;
      obsidian) brew_install_cask obsidian optional ;;
      *) ;;
    esac
  done

  for app in "${SELECTED_COMMUNICATION[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      discord) brew_install_cask discord optional ;;
      *) ;;
    esac
  done

  for app in "${SELECTED_MEDIA[@]}"; do
      if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      vlc) brew_install_cask vlc optional ;;
      spotify) brew_install_cask spotify optional ;;
      *) ;;
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
