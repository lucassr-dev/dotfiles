#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Detecção de gerenciador de pacotes
# ═══════════════════════════════════════════════════════════

detect_linux_pkg_manager() {
  [[ -n "${LINUX_PKG_MANAGER:-}" ]] && return 0
  for candidate in apt-get dnf pacman zypper; do
    if has_cmd "$candidate"; then
      LINUX_PKG_MANAGER="$candidate"
      return
    fi
  done
}

linux_pkg_update_cache() {
  [[ $LINUX_PKG_UPDATED -eq 1 ]] && return
  msg "  🔄 Atualizando cache de pacotes..."
  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if run_with_sudo apt-get update; then
        LINUX_PKG_UPDATED=1
      fi
      ;;
    dnf)
      if run_with_sudo dnf makecache --refresh; then
        LINUX_PKG_UPDATED=1
      fi
      ;;
    zypper)
      if run_with_sudo zypper refresh; then
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
      if ! run_with_sudo apt-get install -y "${packages[@]}"; then
        record_failure "$level" "Falha ao instalar (apt) ${packages[*]}"
      else
        INSTALLED_PACKAGES+=("apt: ${packages[*]}")
      fi
      ;;
    dnf)
      if ! run_with_sudo dnf install -y "${packages[@]}"; then
        record_failure "$level" "Falha ao instalar (dnf) ${packages[*]}"
      else
        INSTALLED_PACKAGES+=("dnf: ${packages[*]}")
      fi
      ;;
    pacman)
      if ! run_with_sudo pacman -Sy --noconfirm --needed "${packages[@]}"; then
        record_failure "$level" "Falha ao instalar (pacman) ${packages[*]}"
      else
        INSTALLED_PACKAGES+=("pacman: ${packages[*]}")
      fi
      ;;
    zypper)
      if ! run_with_sudo zypper install -y "${packages[@]}"; then
        record_failure "$level" "Falha ao instalar (zypper) ${packages[*]}"
      else
        INSTALLED_PACKAGES+=("zypper: ${packages[*]}")
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
        ca-certificates
        git
        curl
        wget
        gnupg
        unzip
        fontconfig
        imagemagick
        chafa
      )
      ;;
    dnf)
      base_packages=(
        ca-certificates
        git
        curl
        wget
        gnupg
        unzip
        fontconfig
        ImageMagick
        chafa
      )
      ;;
    pacman)
      base_packages=(
        ca-certificates
        git
        curl
        wget
        gnupg
        unzip
        fontconfig
        imagemagick
        chafa
      )
      ;;
    zypper)
      base_packages=(
        ca-certificates-mozilla
        git
        curl
        wget
        gpg2
        unzip
        fontconfig
        ImageMagick
        chafa
      )
      ;;
  esac

  if [[ ${#base_packages[@]} -gt 0 ]]; then
    msg "  📦 Instalando dependências base..."
    install_linux_packages "critical" "${base_packages[@]}"
  fi

  install_fzf_latest
  install_gum_fallback
}

# ═══════════════════════════════════════════════════════════
# Instalação do fzf (versão mais recente via git)
# ═══════════════════════════════════════════════════════════

install_fzf_latest() {
  local fzf_dir="$HOME/.fzf"
  local min_version="0.48"

  if has_cmd fzf; then
    local current_version
    current_version=$(fzf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$current_version" ]]; then
      if awk "BEGIN {exit !($current_version >= $min_version)}"; then
        msg "  ✅ fzf $current_version já instalado (>= $min_version)"
        return 0
      else
        msg "  🔄 fzf $current_version encontrado, atualizando para versão mais recente..."
      fi
    fi
  fi

  msg "  📦 Instalando fzf (versão mais recente via git)..."

  [[ -d "$fzf_dir" ]] && rm -rf "$fzf_dir"

  if ! git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"; then
    record_failure "optional" "Falha ao clonar repositório do fzf"
    msg "  ⚠️  Tentando fallback via package manager..."
    install_linux_packages "optional" fzf
    return 0
  fi

  if "$fzf_dir/install" --all --no-update-rc --no-bash --no-fish; then
    export PATH="$HOME/.fzf/bin:$PATH"
    INSTALLED_MISC+=("fzf (git): latest")
    local installed_version
    installed_version=$("$fzf_dir/bin/fzf" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    msg "  ✅ fzf $installed_version instalado com sucesso"
  else
    record_failure "optional" "Falha ao instalar fzf via git"
    msg "  ⚠️  Tentando fallback via package manager..."
    install_linux_packages "optional" fzf
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação do gum (fallback UI caso fzf não esteja disponível)
# ═══════════════════════════════════════════════════════════

install_gum_fallback() {
  has_cmd fzf && return 0
  has_cmd gum && return 0

  msg "  📦 Instalando gum (UI fallback)..."
  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if has_cmd gpg; then
        run_with_sudo mkdir -p /etc/apt/keyrings 2>/dev/null
        curl -fsSL https://repo.charm.sh/apt/gpg.key | run_with_sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg 2>/dev/null
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | run_with_sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
        LINUX_PKG_UPDATED=0
        install_linux_packages "optional" gum
      fi
      ;;
    dnf)
      run_with_sudo dnf install -y gum 2>/dev/null || true
      ;;
    pacman)
      run_with_sudo pacman -S --noconfirm gum 2>/dev/null || true
      ;;
  esac
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
  nu_version=$(curl -fsSL "https://api.github.com/repos/nushell/nushell/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' || echo "")

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
# Instalação de apps selecionados no Linux (usando prioridade)
# ═══════════════════════════════════════════════════════════

_install_app_with_catalog() {
  local app="$1"
  local cmd_check="${2:-$app}"

  if is_app_processed "$app"; then
    return 0
  fi
  mark_app_processed "$app"

  if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
    install_with_priority "$app" "$cmd_check" optional
  else
    return 1
  fi
}

install_linux_selected_apps() {
  msg "▶ Instalando apps GUI selecionados (Linux)"

  for terminal in "${SELECTED_TERMINALS[@]}"; do
    case "$terminal" in
      ghostty) ensure_ghostty_linux ;;
      kitty) install_linux_packages optional kitty ;;
      alacritty) install_linux_packages optional alacritty ;;
      wezterm) _install_app_with_catalog wezterm wezterm || install_wezterm_linux ;;
      gnome-terminal) install_linux_packages optional gnome-terminal ;;
    esac
  done

  for app in "${SELECTED_IDES[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      case "$app" in
        cursor) install_cursor ;;
        *) warn "IDE sem instalador automático no Linux: $app" ;;
      esac
    }
  done

  for app in "${SELECTED_BROWSERS[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      case "$app" in
        zen) install_zen_linux ;;
        *) warn "Navegador sem instalador automático no Linux: $app" ;;
      esac
    }
  done

  for app in "${SELECTED_DEV_TOOLS[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      case "$app" in
        redis-insight) install_redis_insight ;;
        *) warn "Dev tool sem instalador automático no Linux: $app" ;;
      esac
    }
  done

  for app in "${SELECTED_DATABASES[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      case "$app" in
        pgadmin) install_pgadmin_linux ;;
        mongodb) install_mongodb_linux ;;
        *) warn "Banco sem instalador automático no Linux: $app" ;;
      esac
    }
  done

  for app in "${SELECTED_PRODUCTIVITY[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      warn "Produtividade sem instalador automático no Linux: $app"
    }
  done

  for app in "${SELECTED_COMMUNICATION[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      warn "Comunicação sem instalador automático no Linux: $app"
    }
  done

  for app in "${SELECTED_MEDIA[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      warn "Mídia sem instalador automático no Linux: $app"
    }
  done

  for app in "${SELECTED_UTILITIES[@]}"; do
    _install_app_with_catalog "$app" "$app" || {
      case "$app" in
        screenkey) install_linux_packages optional screenkey ;;
        *) warn "Utilitário sem instalador automático no Linux: $app" ;;
      esac
    }
  done
}

install_wezterm_linux() {
  if has_cmd wezterm; then
    return 0
  fi

  if has_cmd flatpak; then
    msg "  📦 Instalando WezTerm via Flatpak..."
    if flatpak install -y flathub org.wezfurlong.wezterm; then
      INSTALLED_MISC+=("wezterm: flatpak")
      return 0
    else
      record_failure "optional" "Falha ao instalar WezTerm via Flatpak"
    fi
  fi

  detect_linux_pkg_manager
  if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
    msg "  📦 Instalando WezTerm via repositório oficial..."
    if curl -fsSL https://apt.fury.io/wez/gpg.key | run_with_sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg; then
      echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | run_with_sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null
      LINUX_PKG_UPDATED=0
      install_linux_packages optional wezterm
      return 0
    else
      record_failure "optional" "Falha ao baixar chave GPG do WezTerm"
    fi
  fi

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
