#!/usr/bin/env bash
# Instaladores e configurações específicas do Linux
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
# Detecção de gerenciador de pacotes
# ═══════════════════════════════════════════════════════════

detect_linux_pkg_manager() {
  [[ -n "$LINUX_PKG_MANAGER" ]] && return
  for candidate in apt-get dnf pacman zypper; do
    if has_cmd "$candidate"; then
      LINUX_PKG_MANAGER="$candidate"
      return
    fi
  done
}

linux_pkg_update_cache() {
  [[ $LINUX_PKG_UPDATED -eq 1 ]] && return
  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if run_with_sudo apt-get update -qq >/dev/null 2>&1; then
        LINUX_PKG_UPDATED=1
      fi
      ;;
    dnf)
      if run_with_sudo dnf makecache --refresh >/dev/null 2>&1; then
        LINUX_PKG_UPDATED=1
      fi
      ;;
    zypper)
      if run_with_sudo zypper refresh >/dev/null 2>&1; then
        LINUX_PKG_UPDATED=1
      fi
      ;;
    *)
      LINUX_PKG_UPDATED=1
      ;;
  esac
}

install_linux_packages() {
  local level="$1"
  shift
  local packages=("$@")
  [[ ${#packages[@]} -gt 0 ]] || return 0
  detect_linux_pkg_manager
  if [[ -z "$LINUX_PKG_MANAGER" ]]; then
    record_failure "$level" "Nenhum gerenciador de pacotes suportado encontrado (apt, dnf, pacman, zypper). Instale manualmente: ${packages[*]}"
    return 0
  fi
  linux_pkg_update_cache
  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if run_with_sudo apt-get install -qq -y "${packages[@]}" >/dev/null 2>&1; then
        INSTALLED_PACKAGES+=("apt: ${packages[*]}")
      else
        record_failure "$level" "Falha ao instalar (apt) ${packages[*]}"
      fi
      ;;
    dnf)
      if run_with_sudo dnf install -q -y "${packages[@]}" >/dev/null 2>&1; then
        INSTALLED_PACKAGES+=("dnf: ${packages[*]}")
      else
        record_failure "$level" "Falha ao instalar (dnf) ${packages[*]}"
      fi
      ;;
    pacman)
      if run_with_sudo pacman -Sy --noconfirm --needed "${packages[@]}" >/dev/null 2>&1; then
        INSTALLED_PACKAGES+=("pacman: ${packages[*]}")
      else
        record_failure "$level" "Falha ao instalar (pacman) ${packages[*]}"
      fi
      ;;
    zypper)
      if run_with_sudo zypper install -y "${packages[@]}" >/dev/null 2>&1; then
        INSTALLED_PACKAGES+=("zypper: ${packages[*]}")
      else
        record_failure "$level" "Falha ao instalar (zypper) ${packages[*]}"
      fi
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Instalação de dependências base no Linux
# ═══════════════════════════════════════════════════════════

install_linux_base_dependencies() {
  detect_linux_pkg_manager

  local base_packages=()

  case "$LINUX_PKG_MANAGER" in
    apt-get)
      base_packages=(
        build-essential
        pkg-config
        ca-certificates
        git
        curl
        wget
        gnupg
        lsb-release
        unzip
        zip
        fontconfig
        imagemagick
        fzf
      )
      ;;
    dnf)
      base_packages=(
        gcc
        gcc-c++
        make
        pkg-config
        ca-certificates
        git
        curl
        wget
        gnupg
        unzip
        zip
        fontconfig
        ImageMagick
        fzf
      )
      ;;
    pacman)
      base_packages=(
        base-devel
        pkg-config
        ca-certificates
        git
        curl
        wget
        gnupg
        unzip
        zip
        fontconfig
        imagemagick
        fzf
      )
      ;;
    zypper)
      base_packages=(
        gcc
        gcc-c++
        make
        pkg-config
        ca-certificates-mozilla
        git
        curl
        wget
        gpg2
        unzip
        zip
        fontconfig
        ImageMagick
        fzf
      )
      ;;
  esac

  if [[ ${#base_packages[@]} -gt 0 ]]; then
    msg "  📦 Instalando dependências base..."
    install_linux_packages "critical" "${base_packages[@]}"
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de shells selecionados no Linux
# ═══════════════════════════════════════════════════════════

install_linux_shells() {
  detect_linux_pkg_manager

  if [[ ${INSTALL_ZSH:-0} -eq 1 ]] && ! has_cmd zsh; then
    msg "  📦 Instalando Zsh..."
    install_linux_packages optional zsh
  fi

  if [[ ${INSTALL_FISH:-0} -eq 1 ]] && ! has_cmd fish; then
    msg "  📦 Instalando Fish..."
    install_linux_packages optional fish
  fi

  if [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && ! has_cmd nu; then
    msg "  📦 Instalando Nushell..."
    install_nushell_linux
  fi
}

install_nushell_linux() {
  case "$LINUX_PKG_MANAGER" in
    pacman)
      install_linux_packages optional nushell && return 0
      ;;
    dnf)
      if dnf copr list 2>/dev/null | grep -q "nushell"; then
        install_linux_packages optional nushell && return 0
      fi
      ;;
  esac

  if has_cmd cargo; then
    msg "  📦 Instalando Nushell via cargo..."
    if cargo_smart_install nu "nu"; then
      INSTALLED_MISC+=("nushell: cargo")
      return 0
    fi
  fi

  msg "  📦 Instalando Nushell via GitHub release..."
  local arch=""
  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="aarch64" ;;
    *)
      warn "Arquitetura não suportada para Nushell"
      return 1
      ;;
  esac

  local nu_version
  nu_version=$(curl -fsSL "https://api.github.com/repos/nushell/nushell/releases/latest" 2>/dev/null | grep -Po '"tag_name": "\K[^"]+' || echo "")

  if [[ -z "$nu_version" ]]; then
    warn "Não foi possível obter versão do Nushell"
    return 1
  fi

  local download_url="https://github.com/nushell/nushell/releases/download/${nu_version}/nu-${nu_version}-${arch}-unknown-linux-gnu.tar.gz"
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' RETURN

  if curl -fsSL "$download_url" -o "$temp_dir/nu.tar.gz"; then
    tar -xzf "$temp_dir/nu.tar.gz" -C "$temp_dir"
    local nu_bin
    nu_bin=$(find "$temp_dir" -name "nu" -type f -executable | head -n 1)
    if [[ -n "$nu_bin" ]]; then
      mkdir -p "$HOME/.local/bin"
      cp "$nu_bin" "$HOME/.local/bin/nu"
      chmod +x "$HOME/.local/bin/nu"
      INSTALLED_MISC+=("nushell: github ${nu_version}")
      msg "  ✅ Nushell ${nu_version} instalado"
      return 0
    fi
  fi

  record_failure "optional" "Falha ao instalar Nushell"
  return 1
}

# ═══════════════════════════════════════════════════════════
# Instalação de apps selecionados no Linux
# ═══════════════════════════════════════════════════════════

install_linux_selected_apps() {
  msg "▶ Instalando apps GUI selecionados (Linux)"

  # Terminais
  for terminal in "${SELECTED_TERMINALS[@]}"; do
    case "$terminal" in
      ghostty) ensure_ghostty_linux ;;
      kitty) install_linux_packages optional kitty ;;
      alacritty) install_linux_packages optional alacritty ;;
      wezterm) install_wezterm_linux ;;
      gnome-terminal) install_linux_packages optional gnome-terminal ;;
    esac
  done

  # IDEs
  for app in "${SELECTED_IDES[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      vscode) install_vscode ;;
      zed) install_zed ;;
      cursor) install_cursor ;;
      neovim) install_neovim ;;
      sublime-text) install_sublime_text ;;
      *) warn "IDE sem instalador automático no Linux: $app" ;;
    esac
  done

  # Navegadores
  for app in "${SELECTED_BROWSERS[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      firefox) install_linux_packages optional firefox ;;
      chrome) install_chrome_linux ;;
      brave) install_brave_linux ;;
      zen) install_zen_linux ;;
      arc) install_arc ;;
      vivaldi) install_vivaldi ;;
      edge) install_edge ;;
      opera) install_opera ;;
      librewolf) install_librewolf ;;
      *) warn "Navegador sem instalador automático no Linux: $app" ;;
    esac
  done

  # Dev tools
  for app in "${SELECTED_DEV_TOOLS[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      vscode) install_vscode ;;
      docker) install_docker_linux ;;
      postman|dbeaver|notion|obsidian) ;;
      bruno) install_bruno ;;
      insomnia) install_insomnia ;;
      gitkraken) install_gitkraken ;;
      mongodb-compass) install_mongodb_compass ;;
      redis-insight) install_redis_insight ;;
      *) warn "Dev tool sem instalador automático no Linux: $app" ;;
    esac
  done

  # Bancos
  for app in "${SELECTED_DATABASES[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      postgresql) install_linux_packages optional postgresql ;;
      redis) install_linux_packages optional redis ;;
      mysql) install_linux_packages optional mysql-server ;;
      mariadb) install_mariadb ;;
      pgadmin) install_pgadmin_linux ;;
      mongodb) install_mongodb_linux ;;
      *) warn "Banco sem instalador automático no Linux: $app" ;;
    esac
  done

  # Produtividade
  for app in "${SELECTED_PRODUCTIVITY[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      slack|notion|obsidian) ;;
      logseq) install_logseq ;;
      anki) install_anki ;;
      joplin) install_joplin ;;
      appflowy) install_appflowy ;;
      *) warn "Produtividade sem instalador automático no Linux: $app" ;;
    esac
  done

  # Comunicação
  for app in "${SELECTED_COMMUNICATION[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      discord) ;;
      telegram) install_telegram ;;
      whatsapp) install_whatsapp ;;
      signal) install_signal ;;
      teams) install_teams ;;
      zoom) install_zoom ;;
      thunderbird) install_thunderbird ;;
      *) warn "Comunicação sem instalador automático no Linux: $app" ;;
    esac
  done

  # Mídia
  for app in "${SELECTED_MEDIA[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      vlc) install_linux_packages optional vlc ;;
      spotify) ;;
      obs-studio) install_obs_studio ;;
      gimp) install_gimp ;;
      inkscape) install_inkscape ;;
      blender) install_blender ;;
      audacity) install_audacity ;;
      kdenlive) install_kdenlive ;;
      *) warn "Mídia sem instalador automático no Linux: $app" ;;
    esac
  done

  # Utilitários
  for app in "${SELECTED_UTILITIES[@]}"; do
    # Anti-duplicidade: pular se já foi processado nesta execução
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      flameshot) install_flameshot ;;
      screenkey) install_linux_packages optional screenkey ;;
      bitwarden) install_bitwarden ;;
      1password) install_1password ;;
      keepassxc) install_keepassxc ;;
      syncthing) install_syncthing ;;
      *) warn "Utilitário sem instalador automático no Linux: $app" ;;
    esac
  done

  # Instalar apps via Snap/Flatpak quando aplicável
  if has_cmd snap; then
    msg "▶ Instalando apps selecionados via Snap"
    for app in "${SELECTED_PRODUCTIVITY[@]}"; do
      case "$app" in
        slack) ensure_snap_app slack "Slack" com.slack.Slack slack optional --classic ;;
        obsidian) ensure_snap_app obsidian "Obsidian" md.obsidian.Obsidian obsidian optional --classic ;;
        notion) ensure_snap_app notion-snap-reborn "Notion" "" notion optional ;;
      esac
    done
    for app in "${SELECTED_COMMUNICATION[@]}"; do
      case "$app" in
        discord) ensure_snap_app discord "Discord" com.discordapp.Discord discord optional ;;
      esac
    done
    for app in "${SELECTED_MEDIA[@]}"; do
      case "$app" in
        spotify) ensure_snap_app spotify "Spotify" com.spotify.Client spotify optional ;;
      esac
    done
    for app in "${SELECTED_DEV_TOOLS[@]}"; do
      case "$app" in
        postman) ensure_snap_app postman "Postman" com.getpostman.Postman postman optional ;;
        dbeaver) ensure_snap_app dbeaver-ce "DBeaver" io.dbeaver.DBeaverCommunity dbeaver optional ;;
      esac
    done
  fi

  if has_cmd flatpak; then
    msg "▶ Instalando apps selecionados via Flatpak"
    for app in "${SELECTED_PRODUCTIVITY[@]}"; do
      case "$app" in
        slack) ensure_flatpak_app com.slack.Slack "Slack" slack slack optional ;;
        obsidian) ensure_flatpak_app md.obsidian.Obsidian "Obsidian" obsidian obsidian optional ;;
      esac
    done
    for app in "${SELECTED_COMMUNICATION[@]}"; do
      case "$app" in
        discord) ensure_flatpak_app com.discordapp.Discord "Discord" discord discord optional ;;
      esac
    done
    for app in "${SELECTED_MEDIA[@]}"; do
      case "$app" in
        spotify) ensure_flatpak_app com.spotify.Client "Spotify" spotify spotify optional ;;
        vlc) ensure_flatpak_app org.videolan.VLC "VLC" "" vlc optional ;;
      esac
    done
    for app in "${SELECTED_DEV_TOOLS[@]}"; do
      case "$app" in
        postman) ensure_flatpak_app com.getpostman.Postman "Postman" postman postman optional ;;
        dbeaver) ensure_flatpak_app io.dbeaver.DBeaverCommunity "DBeaver" dbeaver-ce dbeaver optional ;;
      esac
    done
  fi
}
ensure_ghostty_linux() {
  if has_cmd ghostty; then
    return 0
  fi

  # Ghostty no Linux: compilar da fonte ou usar binário pré-compilado
  # Por enquanto, apenas avisar que não está disponível via gerenciadores comuns
  msg "  ℹ️  Ghostty para Linux: requer build manual ou binário pré-compilado"
  msg "      Visite: https://github.com/mitchellh/ghostty"

  # Opcionalmente, poderia tentar flatpak se houver
  # flatpak_install_or_update com.mitchellh.ghostty "Ghostty" optional
}

install_wezterm_linux() {
  if has_cmd wezterm; then
    return 0
  fi

  # WezTerm via Flatpak (recomendado)
  if has_cmd flatpak; then
    msg "  📦 Instalando WezTerm via Flatpak..."
    if flatpak install -y flathub org.wezfurlong.wezterm >/dev/null 2>&1; then
      INSTALLED_MISC+=("wezterm: flatpak")
      return 0
    fi
  fi

  # WezTerm via AppImage
  detect_linux_pkg_manager
  if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
    msg "  📦 Instalando WezTerm via repositório oficial..."
    # Adicionar repositório WezTerm
    curl -fsSL https://apt.fury.io/wez/gpg.key | run_with_sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg 2>/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | run_with_sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    LINUX_PKG_UPDATED=0
    install_linux_packages optional wezterm
    return 0
  fi

  # Fallback: instruções manuais
  msg "  ℹ️  WezTerm: visite https://wezfurlong.org/wezterm/install/linux.html"
}

# ═══════════════════════════════════════════════════════════
# Aplicação de configurações específicas do Linux
# ═══════════════════════════════════════════════════════════

apply_linux_configs() {
  local source_dir="$CONFIG_LINUX"
  [[ -d "$source_dir" ]] || source_dir="$CONFIG_UNIX_LEGACY"
  [[ -d "$source_dir" ]] || return
  msg "▶ Copiando configs Linux"
  copy_dir "$source_dir/ghostty" "$HOME/.config/ghostty"
}
