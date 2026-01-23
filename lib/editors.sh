#!/usr/bin/env bash
# Instalação de configurações Neovim e tmux
# As configs são copiadas de shared/ para o sistema

# ══════════════════════════════════════════════════════════════════════════════
# VARIÁVEIS GLOBAIS (defaults definidos em install.sh)
# ══════════════════════════════════════════════════════════════════════════════
# COPY_NVIM_CONFIG e COPY_TMUX_CONFIG são definidos em install.sh
# Não redefinir aqui para não sobrescrever os valores padrão

# ══════════════════════════════════════════════════════════════════════════════
# INSTALAÇÃO DO NEOVIM (AppImage nightly - requerido pelo LazyVim >= 0.11)
# ══════════════════════════════════════════════════════════════════════════════
install_neovim_linux() {
  local arch
  arch=$(uname -m)
  local nvim_arch="x86_64"
  [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && nvim_arch="arm64"

  local nvim_url="https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-${nvim_arch}.appimage"
  local install_dir="$HOME/.local/bin"
  local nvim_path="$install_dir/nvim"

  mkdir -p "$install_dir"

  msg "  🔄 Baixando Neovim nightly (requerido pelo LazyVim)..."
  if curl -fsSL "$nvim_url" -o "$nvim_path" 2>/dev/null; then
    chmod +x "$nvim_path"
    if "$nvim_path" --version >/dev/null 2>&1; then
      local version
      version=$("$nvim_path" --version 2>/dev/null | head -1 | awk '{print $2}')
      msg "  ✅ Neovim $version instalado via AppImage"
      INSTALLED_MISC+=("neovim: appimage $version")
      return 0
    else
      msg "  ⚠️  AppImage não executável, tentando extrair..."
      cd "$install_dir" || return 1
      "$nvim_path" --appimage-extract >/dev/null 2>&1
      if [[ -d "squashfs-root" ]]; then
        rm -f "$nvim_path"
        mv squashfs-root neovim-extracted
        ln -sf "$install_dir/neovim-extracted/AppRun" "$nvim_path"
        if "$nvim_path" --version >/dev/null 2>&1; then
          local version
          version=$("$nvim_path" --version 2>/dev/null | head -1 | awk '{print $2}')
          msg "  ✅ Neovim $version instalado (extraído)"
          INSTALLED_MISC+=("neovim: appimage-extracted $version")
          return 0
        fi
      fi
    fi
  fi

  msg "  ⚠️  AppImage falhou, usando pacote da distro..."
  install_neovim_package
}

install_neovim_package() {
  case "$LINUX_PKG_MANAGER" in
    apt|apt-get)
      if has_cmd add-apt-repository; then
        run_with_sudo add-apt-repository -y ppa:neovim-ppa/unstable || true
        run_with_sudo apt update || true
      fi
      if run_with_sudo apt install -y neovim; then
        INSTALLED_MISC+=("neovim: apt")
      else
        record_failure "optional" "Falha ao instalar Neovim"
      fi
      ;;
    dnf)
      if run_with_sudo dnf install -y neovim; then
        INSTALLED_MISC+=("neovim: dnf")
      else
        record_failure "optional" "Falha ao instalar Neovim"
      fi
      ;;
    pacman)
      if run_with_sudo pacman -S --noconfirm neovim; then
        INSTALLED_MISC+=("neovim: pacman")
      else
        record_failure "optional" "Falha ao instalar Neovim"
      fi
      ;;
    zypper)
      if run_with_sudo zypper install -y neovim; then
        INSTALLED_MISC+=("neovim: zypper")
      else
        record_failure "optional" "Falha ao instalar Neovim"
      fi
      ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════════════
# INSTALAÇÃO - Cópia de Configurações Salvas
# ══════════════════════════════════════════════════════════════════════════════
install_selected_editors() {
  install_nvim_config
  install_tmux_config
}

install_nvim_config() {
  [[ $COPY_NVIM_CONFIG -eq 0 ]] && return 0

  msg ""
  msg "▶ Copiando configuração do Neovim"

  if [[ ! -d "$CONFIG_SHARED/nvim" ]] || [[ -z "$(ls -A "$CONFIG_SHARED/nvim" 2>/dev/null)" ]]; then
    msg "  ⚠️  Nenhuma config encontrada em shared/nvim/"
    return 0
  fi

  if ! has_cmd nvim; then
    msg "  📦 Instalando Neovim..."
    case "$TARGET_OS" in
      linux|wsl2)
        install_neovim_linux
        ;;
      macos)
        if brew install neovim; then
          INSTALLED_MISC+=("neovim: brew")
        else
          record_failure "optional" "Falha ao instalar Neovim"
        fi
        ;;
    esac
  fi

  if ! has_cmd nvim; then
    record_failure "optional" "Neovim não disponível; pulando configuração"
    return 0
  fi

  if [[ -d "$HOME/.config/nvim" ]]; then
    msg "  📦 Backup da configuração existente..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  fi

  mkdir -p "$HOME/.config"
  if cp -r "$CONFIG_SHARED/nvim" "$HOME/.config/nvim" 2>/dev/null; then
    INSTALLED_MISC+=("Neovim (config)")
    msg "  ✅ Configuração do Neovim copiada"
  else
    record_failure "optional" "Falha ao copiar configuração do Neovim"
  fi
}

install_tmux_config() {
  [[ $COPY_TMUX_CONFIG -eq 0 ]] && return 0

  msg ""
  msg "▶ Copiando configuração do tmux"

  if [[ ! -d "$CONFIG_SHARED/tmux" ]] || [[ -z "$(ls -A "$CONFIG_SHARED/tmux" 2>/dev/null)" ]]; then
    msg "  ⚠️  Nenhuma config encontrada em shared/tmux/"
    return 0
  fi

  if ! has_cmd tmux; then
    msg "  📦 Instalando tmux..."
    case "$TARGET_OS" in
      linux|wsl2)
        case "$LINUX_PKG_MANAGER" in
          apt)
            if run_with_sudo apt install -y tmux; then
              INSTALLED_MISC+=("tmux: apt")
            else
              record_failure "optional" "Falha ao instalar tmux"
            fi
            ;;
          dnf)
            if run_with_sudo dnf install -y tmux; then
              INSTALLED_MISC+=("tmux: dnf")
            else
              record_failure "optional" "Falha ao instalar tmux"
            fi
            ;;
          pacman)
            if run_with_sudo pacman -S --noconfirm tmux; then
              INSTALLED_MISC+=("tmux: pacman")
            else
              record_failure "optional" "Falha ao instalar tmux"
            fi
            ;;
          zypper)
            if run_with_sudo zypper install -y tmux; then
              INSTALLED_MISC+=("tmux: zypper")
            else
              record_failure "optional" "Falha ao instalar tmux"
            fi
            ;;
        esac
        ;;
      macos)
        if brew install tmux; then
          INSTALLED_MISC+=("tmux: brew")
        else
          record_failure "optional" "Falha ao instalar tmux"
        fi
        ;;
    esac
  fi

  if ! has_cmd tmux; then
    record_failure "optional" "tmux não disponível; pulando configuração"
    return 0
  fi

  [[ -f "$HOME/.tmux.conf" ]] && mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

  local copied=0

  if [[ -f "$CONFIG_SHARED/tmux/.tmux.conf" ]]; then
    cp "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf" 2>/dev/null && copied=1
  elif [[ -f "$CONFIG_SHARED/tmux/tmux.conf" ]]; then
    cp "$CONFIG_SHARED/tmux/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null && copied=1
  fi

  if [[ -d "$CONFIG_SHARED/tmux/.tmux" ]]; then
    [[ -d "$HOME/.tmux" ]] && mv "$HOME/.tmux" "$HOME/.tmux.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    cp -r "$CONFIG_SHARED/tmux/.tmux" "$HOME/.tmux" 2>/dev/null && copied=1
  fi

  if [[ $copied -eq 1 ]]; then
    INSTALLED_MISC+=("tmux (config)")
    msg "  ✅ Configuração do tmux copiada"

    if grep -q "tmux-plugins/tpm" "$HOME/.tmux.conf" 2>/dev/null; then
      if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        msg "  📦 Instalando TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" >/dev/null 2>&1 || true
      fi
      if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
        msg "  🔄 Instalando plugins do tmux..."
        "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true
      fi
    fi
  else
    record_failure "optional" "Falha ao copiar configuração do tmux"
  fi
}
