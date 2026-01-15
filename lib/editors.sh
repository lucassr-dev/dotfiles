#!/usr/bin/env bash
# Instalação de configurações Neovim e tmux
# As configs são copiadas de shared/ para o sistema

# ══════════════════════════════════════════════════════════════════════════════
# VARIÁVEIS GLOBAIS
# ══════════════════════════════════════════════════════════════════════════════
COPY_NVIM_CONFIG=0
COPY_TMUX_CONFIG=0

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

  # Verificar se há config para copiar
  if [[ ! -d "$CONFIG_SHARED/nvim" ]] || [[ -z "$(ls -A "$CONFIG_SHARED/nvim" 2>/dev/null)" ]]; then
    msg "  ⚠️  Nenhuma config encontrada em shared/nvim/"
    return 0
  fi

  # Instalar Neovim se não estiver instalado
  if ! has_cmd nvim; then
    msg "  📦 Instalando Neovim..."
    case "$TARGET_OS" in
      linux|wsl2)
        case "$LINUX_PKG_MANAGER" in
          apt)
            # Tentar PPA primeiro para versão mais recente
            if has_cmd add-apt-repository; then
              run_with_sudo add-apt-repository -y ppa:neovim-ppa/unstable >/dev/null 2>&1 || true
              run_with_sudo apt update >/dev/null 2>&1 || true
            fi
            run_with_sudo apt install -y neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
          dnf)
            run_with_sudo dnf install -y neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
          pacman)
            run_with_sudo pacman -S --noconfirm neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
          zypper)
            run_with_sudo zypper install -y neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
        esac
        ;;
      macos)
        brew install neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
        ;;
    esac
  fi

  if ! has_cmd nvim; then
    record_failure "optional" "Neovim não disponível; pulando configuração"
    return 0
  fi

  # Backup de config existente
  if [[ -d "$HOME/.config/nvim" ]]; then
    msg "  📦 Backup da configuração existente..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  fi

  # Copiar config salva
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

  # Verificar se há config para copiar
  if [[ ! -d "$CONFIG_SHARED/tmux" ]] || [[ -z "$(ls -A "$CONFIG_SHARED/tmux" 2>/dev/null)" ]]; then
    msg "  ⚠️  Nenhuma config encontrada em shared/tmux/"
    return 0
  fi

  # Instalar tmux se não estiver instalado
  if ! has_cmd tmux; then
    msg "  📦 Instalando tmux..."
    case "$TARGET_OS" in
      linux|wsl2)
        case "$LINUX_PKG_MANAGER" in
          apt) run_with_sudo apt install -y tmux >/dev/null 2>&1 ;;
          dnf) run_with_sudo dnf install -y tmux >/dev/null 2>&1 ;;
          pacman) run_with_sudo pacman -S --noconfirm tmux >/dev/null 2>&1 ;;
          zypper) run_with_sudo zypper install -y tmux >/dev/null 2>&1 ;;
        esac
        ;;
      macos)
        brew install tmux >/dev/null 2>&1
        ;;
    esac
  fi

  if ! has_cmd tmux; then
    record_failure "optional" "tmux não disponível; pulando configuração"
    return 0
  fi

  # Backup de config existente
  [[ -f "$HOME/.tmux.conf" ]] && mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

  # Copiar configs salvas
  local copied=0

  # Copiar .tmux.conf se existir
  if [[ -f "$CONFIG_SHARED/tmux/.tmux.conf" ]]; then
    cp "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf" 2>/dev/null && copied=1
  elif [[ -f "$CONFIG_SHARED/tmux/tmux.conf" ]]; then
    cp "$CONFIG_SHARED/tmux/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null && copied=1
  fi

  # Copiar diretório .tmux se existir
  if [[ -d "$CONFIG_SHARED/tmux/.tmux" ]]; then
    [[ -d "$HOME/.tmux" ]] && mv "$HOME/.tmux" "$HOME/.tmux.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    cp -r "$CONFIG_SHARED/tmux/.tmux" "$HOME/.tmux" 2>/dev/null && copied=1
  fi

  if [[ $copied -eq 1 ]]; then
    INSTALLED_MISC+=("tmux (config)")
    msg "  ✅ Configuração do tmux copiada"

    # Instalar TPM se a config usa plugins
    if grep -q "tmux-plugins/tpm" "$HOME/.tmux.conf" 2>/dev/null; then
      if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        msg "  📦 Instalando TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" >/dev/null 2>&1 || true
      fi
      # Instalar plugins
      if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
        msg "  🔄 Instalando plugins do tmux..."
        "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true
      fi
    fi
  else
    record_failure "optional" "Falha ao copiar configuração do tmux"
  fi
}
