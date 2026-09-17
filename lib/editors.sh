#!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════════════════════
# INSTALAÇÃO DO NEOVIM
# ══════════════════════════════════════════════════════════════════════════════

# Versão mínima exigida pela configuração do LazyVim entregue neste repositório:
# usa vim.lsp.config, vim.diagnostic.jump e vim.lsp.inline_completion, APIs que
# não existem no Neovim 0.11. Atualizar esta constante junto com a config.
NVIM_VERSION="0.12.5"

install_neovim() {
  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) instalaria Neovim ${NVIM_VERSION} via mise (fallback: tarball oficial estável)"
    return 0
  fi

  if has_cmd mise; then
    msg "  🔄 Instalando Neovim ${NVIM_VERSION} via mise..."
    if mise use -g -y "neovim@${NVIM_VERSION}"; then
      _mise_add_shims_to_path
      INSTALLED_MISC+=("neovim: mise ${NVIM_VERSION}")
      _report_neovim_version "$NVIM_VERSION" mise exec "neovim@${NVIM_VERSION}" -- nvim
      return 0
    fi
    msg "  ⚠️  mise falhou ao instalar o Neovim, tentando tarball oficial..."
  fi

  install_neovim_tarball "$NVIM_VERSION"
}

# O `mise use -g` deixa o binario em .../mise/installs/..., alcancavel so
# pelos shims do mise. Os shims entram no PATH do usuario via .zshrc/config.fish,
# mas isso so vale no PROXIMO shell - o processo atual do instalador (e os
# testes de PATH logo em seguida, como o gate de install_nvim_config e o
# relatorio final) nao enxergam o binario recem-instalado sem isto.
_mise_add_shims_to_path() {
  local shims_dir="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"

  if ! [[ -x "$shims_dir/nvim" ]]; then
    has_cmd mise && mise reshim >/dev/null 2>&1
  fi

  [[ -d "$shims_dir" ]] || return 0

  case ":$PATH:" in
    *":$shims_dir:"*) ;;
    *) export PATH="$shims_dir:$PATH" ;;
  esac
}

install_neovim_tarball() {
  local nvim_version="$1"

  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) arch="$(uname -m)" ;;
  esac

  local os_slug="linux"
  [[ "$TARGET_OS" == "macos" ]] && os_slug="macos"

  local asset="nvim-${os_slug}-${arch}.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/v${nvim_version}/${asset}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  msg "  🔄 Baixando Neovim ${nvim_version} (tarball oficial estável)..."
  mkdir -p "$HOME/.local"

  if ! has_cmd tar; then
    record_failure "optional" "tar nao encontrado - necessario para extrair o pacote"
    return 1
  fi
  if curl -fsSL "$url" -o "$tmp_dir/$asset" && \
     tar -xzf "$tmp_dir/$asset" --strip-components=1 -C "$HOME/.local"; then
    rm -rf "$tmp_dir" 2>/dev/null || true
    INSTALLED_MISC+=("neovim: tarball ${nvim_version}")
    _report_neovim_version "$nvim_version" "$HOME/.local/bin/nvim"
    return 0
  fi

  rm -rf "$tmp_dir" 2>/dev/null || true
  record_failure "optional" "Falha ao instalar Neovim (mise e tarball oficial indisponíveis)"
  return 1
}

_report_neovim_version() {
  local expected="$1"
  shift
  local version
  version="$("$@" --version 2>/dev/null | head -1 | awk '{print $2}')"

  if [[ -z "$version" ]]; then
    msg "  ⚠️  Neovim instalado, mas não foi possível verificar a versão"
    return 0
  fi

  if [[ "$version" == "v${expected}" ]]; then
    msg "  ✅ Neovim $version instalado e verificado"
    return 0
  fi

  msg "  ⚠️  Neovim $version instalado (esperado v${expected})"
  return 1
}

# Verdadeiro quando existe um `nvim` no PATH em versão >= $NVIM_VERSION.
# Falha de forma segura (retorna falso) se `nvim` não existe ou se a saída de
# `--version` não bate com o formato esperado (major.minor.patch).
_nvim_meets_min_version() {
  has_cmd nvim || return 1

  local current
  current="$(nvim --version 2>/dev/null | head -1 | awk '{print $2}')"
  current="${current#v}"
  [[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1

  [[ "$(printf '%s\n%s\n' "$NVIM_VERSION" "$current" | sort -V | tail -1)" == "$current" ]]
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

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) sincronizaria shared/nvim -> ~/.config/nvim"
    return 0
  fi

  if [[ ! -d "$CONFIG_SHARED/nvim" ]] || [[ -z "$(ls -A "$CONFIG_SHARED/nvim" 2>/dev/null)" ]]; then
    msg "  ⚠️  Nenhuma config encontrada em shared/nvim/"
    return 0
  fi

  if ! _nvim_meets_min_version; then
    msg "  📦 Instalando/atualizando Neovim (mínimo ${NVIM_VERSION})..."
    case "$TARGET_OS" in
      linux|wsl2|macos)
        install_neovim
        ;;
      windows)
        if has_cmd winget && winget install -e --id Neovim.Neovim --silent --accept-package-agreements --accept-source-agreements >/dev/null 2>&1; then
          INSTALLED_MISC+=("neovim: winget")
        elif has_cmd choco && _choco_install_or_upgrade neovim; then
          INSTALLED_MISC+=("neovim: choco")
        else
          record_failure "optional" "Falha ao instalar Neovim no Windows"
        fi
        ;;
    esac
  fi

  if ! has_cmd nvim; then
    record_failure "optional" "Neovim não disponível; pulando configuração"
    return 0
  fi

  if ! _nvim_meets_min_version; then
    msg "  ⚠️  Neovim presente, mas abaixo de ${NVIM_VERSION} (mínimo exigido pela config LazyVim); copiando mesmo assim"
  fi

  mkdir -p "$HOME/.config"
  if copy_dir "$CONFIG_SHARED/nvim" "$HOME/.config/nvim"; then
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

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) sincronizaria shared/tmux -> ~/.tmux.conf e ~/.tmux/"
    return 0
  fi

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

  local copied=0

  if [[ -f "$CONFIG_SHARED/tmux/.tmux.conf" ]]; then
    copy_file "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf" && copied=1
  elif [[ -f "$CONFIG_SHARED/tmux/tmux.conf" ]]; then
    copy_file "$CONFIG_SHARED/tmux/tmux.conf" "$HOME/.tmux.conf" && copied=1
  fi

  if [[ -d "$CONFIG_SHARED/tmux/.tmux" ]]; then
    copy_dir "$CONFIG_SHARED/tmux/.tmux" "$HOME/.tmux" && copied=1
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
