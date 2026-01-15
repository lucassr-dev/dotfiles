#!/usr/bin/env bash
set -uo pipefail
# shellcheck disable=SC2034,SC2329,SC1091

# Instalador & Exportador de Dotfiles
# Uso básico:
#   bash config/install.sh           # instala
#   bash config/install.sh export    # exporta
#   bash config/install.sh sync      # exporta + instala
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SHARED="$SCRIPT_DIR/shared"
CONFIG_LINUX="$SCRIPT_DIR/linux"
CONFIG_MACOS="$SCRIPT_DIR/macos"
CONFIG_WINDOWS="$SCRIPT_DIR/windows"
CONFIG_UNIX_LEGACY="$SCRIPT_DIR/mac-linux"
DATA_APPS="$SCRIPT_DIR/data/apps.sh"
DATA_RUNTIMES="$SCRIPT_DIR/data/runtimes.sh"
BACKUP_DIR="$HOME/.bkp-$(date +%Y%m%d-%H%M)"
TARGET_OS=""
LINUX_PKG_MANAGER=""
LINUX_PKG_UPDATED=0
MODE="install"  # install, export, or sync
FAIL_FAST=1
DRY_RUN="${DRY_RUN:-0}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"
INSTALL_FISH="${INSTALL_FISH:-1}"
INSTALL_NUSHELL="${INSTALL_NUSHELL:-0}"
INSTALL_BASE_DEPS=1  # Dependências base (pode ser desativado pelo usuário)
INSTALL_VSCODE_EXTENSIONS=0
BASE_DEPS_INSTALLED=0

# Controle de cópia de configurações (padrão: copiar se selecionado)
COPY_ZSH_CONFIG=1
COPY_FISH_CONFIG=1
COPY_NUSHELL_CONFIG=1
COPY_GIT_CONFIG=1
COPY_NVIM_CONFIG=1
COPY_TMUX_CONFIG=1
COPY_TERMINAL_CONFIG=1
COPY_MISE_CONFIG=1
COPY_SSH_KEYS=0  # SSH keys desabilitado por padrão (sensível)
COPY_VSCODE_SETTINGS=1

PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-}"
PRIVATE_SHARED=""

if [[ -z "$PRIVATE_DIR" ]]; then
  if [[ -d "$SCRIPT_DIR/../config-private" ]]; then
    PRIVATE_DIR="$SCRIPT_DIR/../config-private"
  elif [[ -d "$HOME/.dotfiles-private" ]]; then
    PRIVATE_DIR="$HOME/.dotfiles-private"
  fi
fi

if [[ -n "$PRIVATE_DIR" ]] && [[ -d "$PRIVATE_DIR/shared" ]]; then
  PRIVATE_SHARED="$PRIVATE_DIR/shared"
fi

declare -a CRITICAL_ERRORS=()
declare -a OPTIONAL_ERRORS=()
declare -a COPIED_PATHS=()
declare -a INSTALLED_PACKAGES=()
declare -a INSTALLED_MISC=()

for arg in "$@"; do
  case "$arg" in
    install|export|sync|help|--help|-h)
      MODE="$arg"
      ;;
    *)
      echo "❌ Argumento desconhecido: $arg" >&2
      echo "Uso: bash install.sh [install|export|sync]" >&2
      exit 1
      ;;
  esac
done

msg() {
  # Usar %b para interpretar escape sequences (cores ANSI)
  printf '%b\n' "$1"
}

warn() {
  msg "  ⚠️ $1"
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

should_ensure_latest() {
  return 0
}

snap_install_or_refresh() {
  local pkg="$1"
  local friendly="$2"
  local level="${3:-optional}"
  shift 3 || true
  local install_args=("$@")

  has_cmd snap || return 0

  if has_snap_pkg "$pkg"; then
    if should_ensure_latest; then
      msg "  🔄 Atualizando $friendly via snap..."
      if run_with_sudo snap refresh "$pkg" >/dev/null 2>&1; then
        INSTALLED_MISC+=("$friendly: snap refresh")
      else
        record_failure "$level" "Falha ao atualizar via snap: $friendly ($pkg)"
      fi
    fi
    return 0
  fi

  msg "  📦 Instalando $friendly via snap..."
  if run_with_sudo snap install "${install_args[@]}" "$pkg" >/dev/null 2>&1; then
    INSTALLED_MISC+=("$friendly: snap install")
  else
    record_failure "$level" "Falha ao instalar via snap: $friendly ($pkg)"
  fi
}

ensure_snap_app() {
  local pkg="$1"
  local friendly="$2"
  local flatpak_ref="${3:-}"
  local cmd="${4:-}"
  local level="${5:-optional}"

  has_cmd snap || return 0

  if [[ -n "$flatpak_ref" ]] && has_flatpak_ref "$flatpak_ref"; then
    msg "  ℹ️  $friendly já instalado via Flatpak ($flatpak_ref); pulando Snap."
    return 0
  fi

  if [[ -n "$cmd" ]] && has_cmd "$cmd"; then
    msg "  ℹ️  $friendly já está disponível no sistema ($cmd); pulando Snap."
    return 0
  fi

  snap_install_or_refresh "$pkg" "$friendly" "$level"
}

flatpak_install_or_update() {
  local ref="$1"
  local friendly="$2"
  local level="${3:-optional}"

  has_cmd flatpak || return 0
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true

  if flatpak info "$ref" >/dev/null 2>&1; then
    if should_ensure_latest; then
      msg "  🔄 Atualizando $friendly via flatpak..."
      if flatpak update -y "$ref" >/dev/null 2>&1; then
        INSTALLED_MISC+=("$friendly: flatpak update")
      else
        record_failure "$level" "Falha ao atualizar via flatpak: $friendly ($ref)"
      fi
    fi
    return 0
  fi

  msg "  📦 Instalando $friendly via flatpak..."
  if flatpak install -y flathub "$ref" >/dev/null 2>&1; then
    INSTALLED_MISC+=("$friendly: flatpak install")
  else
    record_failure "$level" "Falha ao instalar via flatpak: $friendly ($ref)"
  fi
}

ensure_flatpak_app() {
  local ref="$1"
  local friendly="$2"
  local snap_pkg="${3:-}"
  local cmd="${4:-}"
  local level="${5:-optional}"

  has_cmd flatpak || return 0

  if has_flatpak_ref "$ref"; then
    flatpak_install_or_update "$ref" "$friendly" "$level"
    return
  fi

  if [[ -n "$snap_pkg" ]] && has_snap_pkg "$snap_pkg"; then
    msg "  ℹ️  $friendly já instalado via snap ($snap_pkg); pulando Flatpak."
    return
  fi

  if [[ -n "$cmd" ]] && has_cmd "$cmd"; then
    msg "  ℹ️  $friendly já está disponível no sistema ($cmd); pulando Flatpak."
    return
  fi

  flatpak_install_or_update "$ref" "$friendly" "$level"
}

record_failure() {
  local level="$1"
  local message="$2"
  if [[ "$level" == "critical" ]]; then
    CRITICAL_ERRORS+=("$message")
    warn "❌ $message"
    if [[ "$FAIL_FAST" -eq 1 ]]; then
      print_final_summary 1
    fi
  else
    OPTIONAL_ERRORS+=("$message")
    warn "$message"
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_snap_pkg() {
  has_cmd snap || return 1
  snap list "$1" >/dev/null 2>&1
}

has_flatpak_ref() {
  has_cmd flatpak || return 1
  flatpak list | grep -q "$1"
}

run_with_sudo() {
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) sudo $*"
    return 0
  fi
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif has_cmd sudo; then
    sudo "$@"
  else
    warn "Comando '$*' requer sudo, mas sudo não está disponível."
    return 1
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]] && [[ "$MODE" == "install" ]]; then
    local base_name=""
    base_name="$(basename "$path")"
    local backup_path="$BACKUP_DIR/$base_name"
    mkdir -p "$BACKUP_DIR"
    msg "  💾 Backup: $path -> $backup_path"
    cp -a "$path" "$backup_path" 2>/dev/null || cp -R "$path" "$backup_path" 2>/dev/null || true
  fi
}

copy_dir() {
  local src="$1"
  local dest="$2"
  [[ -d "$src" ]] || return
  msg "  📁 $src -> $dest"
  backup_if_exists "$dest"
  mkdir -p "$dest"
  if ! cp -R "$src/." "$dest/"; then
    record_failure "critical" "Falha ao copiar diretório: $src -> $dest"
  elif [[ ! -d "$dest" ]]; then
    record_failure "critical" "Destino ausente após copiar diretório: $dest"
  else
    COPIED_PATHS+=("$dest")
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" ]] || return
  msg "  📄 $src -> $dest"
  backup_if_exists "$dest"
  mkdir -p "$(dirname "$dest")"
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) cp $src $dest"
    return
  fi
  if ! cp "$src" "$dest"; then
    record_failure "critical" "Falha ao copiar arquivo: $src -> $dest"
  elif [[ ! -f "$dest" ]]; then
    record_failure "critical" "Destino ausente após copiar arquivo: $dest"
  else
    COPIED_PATHS+=("$dest")
  fi
}

export_dir() {
  local src="$1"
  local dest="$2"
  [[ -d "$src" ]] || return
  msg "  📤 $src -> $dest"
  mkdir -p "$dest"
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) cp -R $src/. $dest/"
    return
  fi
  cp -R "$src/." "$dest/"
}

export_file() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" ]] || return
  msg "  📤 $src -> $dest"
  mkdir -p "$(dirname "$dest")"
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) cp $src $dest"
    return
  fi
  cp "$src" "$dest"
}

normalize_crlf_to_lf() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  [[ "${TARGET_OS:-}" == "windows" ]] && return 0

  if LC_ALL=C grep -q $'\r' "$file" 2>/dev/null; then
    local tmp
    if ! tmp="$(mktemp)"; then
      warn "Falha ao criar arquivo temporário para normalizar $file"
      return 1
    fi

    if tr -d '\r' <"$file" >"$tmp" && mv "$tmp" "$file"; then
      return 0
    else
      warn "Falha ao normalizar line endings em $file"
      rm -f "$tmp" 2>/dev/null || true
      return 1
    fi
  fi
  return 0
}

set_ssh_permissions() {
  if [[ -d "$HOME/.ssh" ]]; then
    chmod 700 "$HOME/.ssh"
    find "$HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
    find "$HOME/.ssh" -type d -exec chmod 700 {} + 2>/dev/null || true
  fi
}

download_file() {
  local url="$1"
  local output="$2"

  if has_cmd curl; then
    curl -fsSL "$url" -o "$output"
  elif has_cmd wget; then
    wget -qO "$output" "$url"
  elif [[ "${TARGET_OS:-}" == "windows" ]] && has_cmd powershell; then
    powershell -NoProfile -Command "Invoke-WebRequest -Uri '$url' -OutFile '$output'"
  else
    record_failure "critical" "Nenhuma ferramenta de download disponível (curl/wget/PowerShell)"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# Preservação de PATH e configurações existentes
# ═══════════════════════════════════════════════════════════

# Verifica se uma configuração de ferramenta já existe no arquivo
# Usa padrões semânticos para detectar a mesma ferramenta em formatos diferentes
tool_config_exists() {
  local file="$1"
  local line="$2"

  [[ ! -f "$file" ]] && return 1

  # Detectar qual ferramenta a linha configura e verificar se já existe
  case "$line" in
    *"NVM_DIR"*|*"nvm.sh"*|*'$NVM_DIR'*)
      grep -q "NVM_DIR\|nvm\.sh" "$file" 2>/dev/null && return 0
      ;;
    *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*)
      grep -q "ANDROID_HOME\|ANDROID_SDK_ROOT" "$file" 2>/dev/null && return 0
      ;;
    *"/Android/Sdk"*|*"/platform-tools"*)
      grep -q "Android/Sdk\|platform-tools" "$file" 2>/dev/null && return 0
      ;;
    *"SDKMAN_DIR"*|*"sdkman-init"*)
      grep -q "SDKMAN_DIR\|sdkman-init" "$file" 2>/dev/null && return 0
      ;;
    *"PYENV_ROOT"*|*"pyenv init"*)
      grep -q "PYENV_ROOT\|pyenv init" "$file" 2>/dev/null && return 0
      ;;
    *"RBENV_ROOT"*|*"rbenv init"*)
      grep -q "RBENV_ROOT\|rbenv init" "$file" 2>/dev/null && return 0
      ;;
    *"JAVA_HOME"*|*'$JAVA_HOME'*)
      grep -q "JAVA_HOME" "$file" 2>/dev/null && return 0
      ;;
    *"GOPATH"*|*"GOROOT"*|*'$GOPATH'*|*'$GOROOT'*)
      grep -q "GOPATH\|GOROOT" "$file" 2>/dev/null && return 0
      ;;
    *"/go/bin"*)
      grep -q "/go/bin" "$file" 2>/dev/null && return 0
      ;;
    *".yarn/bin"*|*".config/yarn"*)
      grep -q "\.yarn/bin\|\.config/yarn" "$file" 2>/dev/null && return 0
      ;;
    *"PNPM_HOME"*|*'$PNPM_HOME'*|*".local/share/pnpm"*)
      grep -q "PNPM_HOME\|\.local/share/pnpm" "$file" 2>/dev/null && return 0
      ;;
    *"BUN_INSTALL"*|*".bun/bin"*)
      grep -q "BUN_INSTALL\|\.bun/bin" "$file" 2>/dev/null && return 0
      ;;
    *"DENO_INSTALL"*|*".deno/bin"*)
      grep -q "DENO_INSTALL\|\.deno/bin" "$file" 2>/dev/null && return 0
      ;;
    *"FLUTTER_HOME"*|*"flutter/bin"*)
      grep -q "FLUTTER_HOME\|flutter/bin" "$file" 2>/dev/null && return 0
      ;;
    *"DOTNET_ROOT"*|*".dotnet"*)
      grep -q "DOTNET_ROOT\|\.dotnet" "$file" 2>/dev/null && return 0
      ;;
    *"mise"*"activate"*|*"mise/shims"*)
      grep -q "mise.*activate\|mise/shims" "$file" 2>/dev/null && return 0
      ;;
    *"HOMEBREW_PREFIX"*|*"/home/linuxbrew"*)
      grep -q "HOMEBREW_PREFIX\|/home/linuxbrew" "$file" 2>/dev/null && return 0
      ;;
    *"/snap/bin"*)
      grep -q "/snap/bin" "$file" 2>/dev/null && return 0
      ;;
  esac

  return 1  # Não encontrado
}

# Adiciona bloco de configurações preservadas, evitando duplicação semântica
append_preserved_config() {
  local file="$1"
  local preserved_config="$2"
  local added_count=0
  local skipped_count=0

  [[ -z "$preserved_config" ]] && return 0
  [[ ! -f "$file" ]] && return 1

  local lines_to_add=()

  # Primeira passagem: filtrar linhas que já existem semanticamente
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^#.*═ ]] && continue
    [[ "$line" =~ ^#.*[Pp]reservad ]] && continue

    # Verificar se a ferramenta já está configurada
    if tool_config_exists "$file" "$line"; then
      ((skipped_count++))
    else
      lines_to_add+=("$line")
      ((added_count++))
    fi
  done <<< "$preserved_config"

  # Se há linhas para adicionar, adicionar com cabeçalho
  if [[ ${#lines_to_add[@]} -gt 0 ]]; then
    {
      echo ""
      echo "# ═══════════════════════════════════════════════════════════"
      echo "# Configurações preservadas do arquivo anterior"
      echo "# (NVM, Android, SDKMAN, pyenv, Go, yarn, pnpm, etc.)"
      echo "# ═══════════════════════════════════════════════════════════"
      printf '%s\n' "${lines_to_add[@]}"
    } >> "$file"
    msg "    ✅ $added_count configurações preservadas"
    [[ $skipped_count -gt 0 ]] && msg "    ℹ️  $skipped_count já existiam (ignoradas)"
  else
    msg "    ℹ️  Todas as configurações já existem no novo arquivo"
  fi
}

# Extrai configurações de PATH do .zshrc existente que devem ser preservadas
# Captura: NVM, Android Studio, SDKMAN, pyenv, rbenv, yarn, JAVA_HOME, GOPATH, etc.
extract_user_path_config_zsh() {
  local zshrc="$HOME/.zshrc"
  [[ -f "$zshrc" ]] || return

  local preserved_lines=()
  local prev_line=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Pular linhas vazias e comentários simples (mas manter comentários de seção)
    [[ -z "$line" ]] && continue

    # Detectar configurações conhecidas que devem ser preservadas
    case "$line" in
      # NVM (Node Version Manager)
      *"NVM_DIR"*|*"nvm.sh"*|*"nvm bash_completion"*|*'$NVM_DIR'*)
        preserved_lines+=("$line")
        ;;
      # Android Studio / SDK
      *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*|*"/Android/Sdk"*|*"/android"*"/tools"*|*"/platform-tools"*)
        preserved_lines+=("$line")
        ;;
      # SDKMAN (Java/Kotlin/Gradle)
      *"SDKMAN_DIR"*|*"sdkman-init.sh"*|*".sdkman"*)
        preserved_lines+=("$line")
        ;;
      # pyenv (Python)
      *"PYENV_ROOT"*|*"pyenv init"*|*'$PYENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      # rbenv (Ruby)
      *"RBENV_ROOT"*|*"rbenv init"*|*'$RBENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      # Java
      *"JAVA_HOME"*|*"JDK_HOME"*|*'$JAVA_HOME'*)
        preserved_lines+=("$line")
        ;;
      # Go
      *"GOPATH"*|*"GOROOT"*|*"/go/bin"*|*'$GOPATH'*|*'$GOROOT'*)
        preserved_lines+=("$line")
        ;;
      # Yarn
      *".yarn/bin"*|*".config/yarn"*|*"yarn global"*)
        preserved_lines+=("$line")
        ;;
      # PNPM
      *"PNPM_HOME"*|*".local/share/pnpm"*|*'$PNPM_HOME'*)
        preserved_lines+=("$line")
        ;;
      # Bun
      *"BUN_INSTALL"*|*".bun/bin"*|*'$BUN_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      # Deno
      *"DENO_INSTALL"*|*".deno/bin"*|*'$DENO_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      # Flutter
      *"FLUTTER_HOME"*|*"flutter/bin"*|*'$FLUTTER_HOME'*)
        preserved_lines+=("$line")
        ;;
      # .NET
      *"DOTNET_ROOT"*|*".dotnet"*|*'$DOTNET_ROOT'*)
        preserved_lines+=("$line")
        ;;
      # Rust/Cargo - NÃO preservar (nosso script já configura via mise)
      *".cargo/env"*|*"CARGO_HOME"*|*"RUSTUP_HOME"*)
        # Ignorar - já configuramos Rust
        ;;
      # Homebrew (linuxbrew)
      *"/home/linuxbrew"*|*"HOMEBREW_PREFIX"*|*'$HOMEBREW_PREFIX'*)
        preserved_lines+=("$line")
        ;;
      # Snap
      *"/snap/bin"*)
        preserved_lines+=("$line")
        ;;
    esac
  done < "$zshrc"

  # Retornar linhas preservadas (se houver)
  if [[ ${#preserved_lines[@]} -gt 0 ]]; then
    printf '%s\n' ""
    printf '%s\n' "# ═══════════════════════════════════════════════════════════"
    printf '%s\n' "# Configurações preservadas do .zshrc anterior"
    printf '%s\n' "# (NVM, Android, SDKMAN, pyenv, Go, yarn, pnpm, etc.)"
    printf '%s\n' "# ═══════════════════════════════════════════════════════════"
    printf '%s\n' "${preserved_lines[@]}"
  fi
}

# Extrai configurações de PATH do config.fish existente que devem ser preservadas
extract_user_path_config_fish() {
  local fishrc="$HOME/.config/fish/config.fish"
  [[ -f "$fishrc" ]] || return

  local preserved_lines=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    case "$line" in
      # NVM (via nvm.fish ou bass)
      *"NVM_DIR"*|*"nvm.fish"*|*"bass"*"nvm"*|*'$NVM_DIR'*)
        preserved_lines+=("$line")
        ;;
      # Android Studio / SDK
      *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*|*"/Android/Sdk"*|*"/android"*"/tools"*|*"/platform-tools"*)
        preserved_lines+=("$line")
        ;;
      # SDKMAN
      *"SDKMAN_DIR"*|*"sdkman"*|*".sdkman"*)
        preserved_lines+=("$line")
        ;;
      # pyenv
      *"PYENV_ROOT"*|*"pyenv init"*|*'$PYENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      # rbenv
      *"RBENV_ROOT"*|*"rbenv init"*|*'$RBENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      # Java
      *"JAVA_HOME"*|*"JDK_HOME"*|*'$JAVA_HOME'*)
        preserved_lines+=("$line")
        ;;
      # Go
      *"GOPATH"*|*"GOROOT"*|*"/go/bin"*|*'$GOPATH'*|*'$GOROOT'*)
        preserved_lines+=("$line")
        ;;
      # Yarn
      *".yarn/bin"*|*".config/yarn"*|*"yarn global"*)
        preserved_lines+=("$line")
        ;;
      # PNPM
      *"PNPM_HOME"*|*".local/share/pnpm"*|*'$PNPM_HOME'*)
        preserved_lines+=("$line")
        ;;
      # Bun
      *"BUN_INSTALL"*|*".bun/bin"*|*'$BUN_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      # Deno
      *"DENO_INSTALL"*|*".deno/bin"*|*'$DENO_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      # Flutter
      *"FLUTTER_HOME"*|*"flutter/bin"*|*'$FLUTTER_HOME'*)
        preserved_lines+=("$line")
        ;;
      # .NET
      *"DOTNET_ROOT"*|*".dotnet"*|*'$DOTNET_ROOT'*)
        preserved_lines+=("$line")
        ;;
      # Homebrew (linuxbrew)
      *"/home/linuxbrew"*|*"HOMEBREW_PREFIX"*|*'$HOMEBREW_PREFIX'*)
        preserved_lines+=("$line")
        ;;
      # Snap
      *"/snap/bin"*)
        preserved_lines+=("$line")
        ;;
    esac
  done < "$fishrc"

  # Retornar linhas preservadas (se houver)
  if [[ ${#preserved_lines[@]} -gt 0 ]]; then
    printf '%s\n' ""
    printf '%s\n' "# ═══════════════════════════════════════════════════════════"
    printf '%s\n' "# Configurações preservadas do config.fish anterior"
    printf '%s\n' "# (NVM, Android, SDKMAN, pyenv, Go, yarn, pnpm, etc.)"
    printf '%s\n' "# ═══════════════════════════════════════════════════════════"
    printf '%s\n' "${preserved_lines[@]}"
  fi
}

# ═══════════════════════════════════════════════════════════
# Seleção Interativa de Apps GUI
# ═══════════════════════════════════════════════════════════

# Arrays para armazenar seleções do usuário no menu interativo.
# Estes arrays são populados pelos arquivos DATA_APPS e DATA_RUNTIMES
# e utilizados pelas funções de instalação de GUI apps.
declare -a SELECTED_IDES=()
declare -a SELECTED_BROWSERS=()
declare -a SELECTED_DEV_TOOLS=()
declare -a SELECTED_DATABASES=()
declare -a SELECTED_PRODUCTIVITY=()
declare -a SELECTED_COMMUNICATION=()
declare -a SELECTED_MEDIA=()
declare -a SELECTED_UTILITIES=()
declare -a SELECTED_RUNTIMES=()
INTERACTIVE_GUI_APPS=true
INSTALL_BREWFILE=true

[[ -f "$DATA_APPS" ]] && source "$DATA_APPS" || warn "Arquivo de dados de apps não encontrado: $DATA_APPS"
[[ -f "$DATA_RUNTIMES" ]] && source "$DATA_RUNTIMES" || warn "Arquivo de dados de runtimes não encontrado: $DATA_RUNTIMES"

[[ -f "$SCRIPT_DIR/lib/banner.sh" ]] && source "$SCRIPT_DIR/lib/banner.sh"
[[ -f "$SCRIPT_DIR/lib/ui.sh" ]] && source "$SCRIPT_DIR/lib/ui.sh"
[[ -f "$SCRIPT_DIR/lib/selections.sh" ]] && source "$SCRIPT_DIR/lib/selections.sh"
[[ -f "$SCRIPT_DIR/lib/nerd_fonts.sh" ]] && source "$SCRIPT_DIR/lib/nerd_fonts.sh"
[[ -f "$SCRIPT_DIR/lib/themes.sh" ]] && source "$SCRIPT_DIR/lib/themes.sh"
[[ -f "$SCRIPT_DIR/lib/os_linux.sh" ]] && source "$SCRIPT_DIR/lib/os_linux.sh"
[[ -f "$SCRIPT_DIR/lib/os_macos.sh" ]] && source "$SCRIPT_DIR/lib/os_macos.sh"
[[ -f "$SCRIPT_DIR/lib/os_windows.sh" ]] && source "$SCRIPT_DIR/lib/os_windows.sh"
[[ -f "$SCRIPT_DIR/lib/gui_apps.sh" ]] && source "$SCRIPT_DIR/lib/gui_apps.sh"
[[ -f "$SCRIPT_DIR/lib/app_installers.sh" ]] && source "$SCRIPT_DIR/lib/app_installers.sh"
[[ -f "$SCRIPT_DIR/lib/tools.sh" ]] && source "$SCRIPT_DIR/lib/tools.sh"
[[ -f "$SCRIPT_DIR/lib/git_config.sh" ]] && source "$SCRIPT_DIR/lib/git_config.sh"
[[ -f "$SCRIPT_DIR/lib/runtimes.sh" ]] && source "$SCRIPT_DIR/lib/runtimes.sh"
[[ -f "$SCRIPT_DIR/lib/editors.sh" ]] && source "$SCRIPT_DIR/lib/editors.sh"
[[ -f "$SCRIPT_DIR/lib/report.sh" ]] && source "$SCRIPT_DIR/lib/report.sh"

print_selection_summary() {
  local label="$1"
  shift
  local items=("$@")
  local list="${UI_DIM}(nenhum)${UI_RESET}"
  if [[ ${#items[@]} -gt 0 ]]; then
    list="$(printf "%s, " "${items[@]}")"
    list="${list%, }"
  fi
  # Título com cor cyan e bold, items em texto normal
  msg "  ${UI_CYAN}${UI_BOLD}$label${UI_RESET}: $list"
}

ask_vscode_extensions() {
  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"
  INSTALL_VSCODE_EXTENSIONS=0

  if [[ ! -f "$extensions_file" ]]; then
    return 0
  fi

  while true; do
    clear_screen
    show_section_header "🧩 VS Code - Extensões"
    msg "Este script pode aplicar automaticamente suas configurações do VS Code:"
    msg "  • Settings: shared/vscode/settings.json"
    msg "  • Extensões: shared/vscode/extensions.txt"
    msg ""
    msg "Se quiser usar suas próprias configs, edite esses arquivos antes de continuar."
    msg ""

    if confirm_action "instalar extensões do VS Code"; then
      INSTALL_VSCODE_EXTENSIONS=1
    fi

    local ext_status="não instalar"
    [[ $INSTALL_VSCODE_EXTENSIONS -eq 1 ]] && ext_status="instalar"

    if confirm_selection "🧩 VS Code Extensions" "$ext_status"; then
      break
    fi
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES AUXILIARES PARA RESUMO RESPONSIVO
# ══════════════════════════════════════════════════════════════════════════════

# Junta array com vírgula + espaço (padronizado)
_join_items() {
  local items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    echo "(nenhum)"
  else
    local result
    result=$(printf "%s, " "${items[@]}")
    echo "${result%, }"
  fi
}

# Trunca array para caber na largura especificada
_truncate_items() {
  local max_width="$1"
  shift
  local items=("$@")
  local result=""
  local count=0
  local remaining=0

  for item in "${items[@]}"; do
    local test_str
    if [[ -z "$result" ]]; then
      test_str="$item"
    else
      test_str="$result, $item"
    fi
    if [[ ${#test_str} -le $max_width ]]; then
      result="$test_str"
      ((count++))
    else
      remaining=$((${#items[@]} - count))
      break
    fi
  done

  if [[ $remaining -gt 0 ]]; then
    echo "$result +$remaining"
  elif [[ -n "$result" ]]; then
    echo "$result"
  else
    echo "(nenhum)"
  fi
}

# Imprime linha formatada com label colorido e valor
_print_row() {
  local label="$1"
  local value="$2"
  local label_width="${3:-14}"
  local value_color="${4:-}"

  # Label em cyan, valor em cor especificada ou padrão
  printf "  ${BANNER_CYAN}%-${label_width}s${BANNER_RESET} ${value_color}%s${BANNER_RESET}\n" "$label" "$value"
}

# Formata array com contagem: "item1, item2 (3)"
_format_with_count() {
  local -n arr_ref=$1
  local max_show="${2:-5}"

  if [[ ${#arr_ref[@]} -eq 0 ]]; then
    echo "${BANNER_DIM}(nenhum)${BANNER_RESET}"
    return
  fi

  local result=""
  local shown=0
  for item in "${arr_ref[@]}"; do
    [[ $shown -ge $max_show ]] && break
    [[ -n "$result" ]] && result+=", "
    result+="$item"
    ((shown++))
  done

  local remaining=$((${#arr_ref[@]} - shown))
  if [[ $remaining -gt 0 ]]; then
    echo "$result ${BANNER_DIM}+$remaining${BANNER_RESET}"
  else
    echo "$result"
  fi
}

# Imprime cabeçalho de seção
_print_section() {
  local title="$1"
  local icon="$2"
  local width="${3:-60}"

  echo ""
  echo -e "  ${BANNER_CYAN}${BANNER_BOLD}${icon} ${title}${BANNER_RESET}"
  local line_len=$((width > 50 ? 50 : width - 10))
  printf "  ${BANNER_DIM}"
  printf '─%.0s' $(seq 1 "$line_len")
  printf "${BANNER_RESET}\n"
}

# Desenha caixa responsiva
_draw_box() {
  local title="$1"
  local width="$2"
  local box_width=$((width > 70 ? 70 : width - 4))

  local line
  line=$(printf '═%.0s' $(seq 1 $((box_width - 2))))

  echo -e "${BANNER_CYAN}╔${line}╗${BANNER_RESET}"
  local title_pad=$(( (box_width - 2 - ${#title}) / 2 ))
  printf "${BANNER_CYAN}║${BANNER_RESET}"
  printf "%${title_pad}s" ""
  printf "${BANNER_BOLD}%s${BANNER_RESET}" "$title"
  printf "%$((box_width - 2 - title_pad - ${#title}))s" ""
  printf "${BANNER_CYAN}║${BANNER_RESET}\n"
  echo -e "${BANNER_CYAN}╚${line}╝${BANNER_RESET}"
}

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES PARA TABELAS COM BORDAS
# ══════════════════════════════════════════════════════════════════════════════

# Desenha linha de tabela com duas colunas
_table_row() {
  local label="$1"
  local value="$2"
  local label_w="${3:-20}"
  local value_w="${4:-40}"
  local C="${BANNER_CYAN}"
  local R="${BANNER_RESET}"

  printf "${C}│${R} ${C}%-${label_w}s${R} ${C}│${R} %-${value_w}s ${C}│${R}\n" "$label" "$value"
}

# Desenha separador de tabela
_table_sep() {
  local label_w="${1:-20}"
  local value_w="${2:-40}"
  local left="$3"
  local mid="$4"
  local right="$5"
  local C="${BANNER_CYAN}"
  local R="${BANNER_RESET}"

  local label_line value_line
  label_line=$(printf '─%.0s' $(seq 1 $((label_w + 2))))
  value_line=$(printf '─%.0s' $(seq 1 $((value_w + 2))))
  printf "${C}${left}${label_line}${mid}${value_line}${right}${R}\n"
}

# Desenha cabeçalho de seção com ícone
_section_header() {
  local icon="$1"
  local title="$2"
  echo ""
  echo -e "${BANNER_CYAN}${BANNER_BOLD}${icon} ${title}${BANNER_RESET}"
}

# Formata contagem: "Label (N)"
_with_count() {
  local label="$1"
  local count="$2"
  echo "${label} (${count})"
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO DE SELEÇÕES - LAYOUT COM BORDAS
# ══════════════════════════════════════════════════════════════════════════════

review_selections() {
  local choice=""
  while true; do
    if declare -F clear_screen >/dev/null; then
      clear_screen
    else
      clear
    fi

    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)

    # Dimensões das tabelas
    local label_w=20
    local value_w=$((term_width > 80 ? 42 : term_width - 30))
    [[ $value_w -lt 25 ]] && value_w=25

    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # TÍTULO PRINCIPAL
    # ═══════════════════════════════════════════════════════════════════════════
    local title_w=$((label_w + value_w + 5))
    local title_line
    title_line=$(printf '─%.0s' $(seq 1 $((title_w - 2))))
    echo -e "${BANNER_CYAN}┌${title_line}┐${BANNER_RESET}"
    local title="📋 RESUMO FINAL DAS SELEÇÕES"
    local title_pad=$(( (title_w - 2 - ${#title} - 2) / 2 ))  # -2 para emoji
    printf "${BANNER_CYAN}│${BANNER_RESET}"
    printf "%${title_pad}s" ""
    printf "${BANNER_BOLD}%s${BANNER_RESET}" "$title"
    printf "%$((title_w - 2 - title_pad - ${#title} - 2))s" ""
    printf "${BANNER_CYAN}│${BANNER_RESET}\n"
    echo -e "${BANNER_CYAN}└${title_line}┘${BANNER_RESET}"

    # Coleta dados
    local selected_shells=()
    [[ ${INSTALL_ZSH:-0} -eq 1 ]] && selected_shells+=("zsh")
    [[ ${INSTALL_FISH:-0} -eq 1 ]] && selected_shells+=("fish")
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && selected_shells+=("nushell")

    local themes_selected=()
    [[ ${INSTALL_OH_MY_ZSH:-0} -eq 1 ]] && themes_selected+=("OMZ+P10k")
    [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && themes_selected+=("Starship")
    [[ ${INSTALL_OH_MY_POSH:-0} -eq 1 ]] && themes_selected+=("OMP")

    local gui_total=0
    gui_total=$((${#SELECTED_IDES[@]} + ${#SELECTED_BROWSERS[@]} + ${#SELECTED_DEV_TOOLS[@]} + \
                 ${#SELECTED_DATABASES[@]} + ${#SELECTED_PRODUCTIVITY[@]} + \
                 ${#SELECTED_COMMUNICATION[@]} + ${#SELECTED_MEDIA[@]} + ${#SELECTED_UTILITIES[@]}))

    # ═══════════════════════════════════════════════════════════════════════════
    # SEÇÃO 1: AMBIENTE DE DESENVOLVIMENTO
    # ═══════════════════════════════════════════════════════════════════════════
    _section_header "🐚" "AMBIENTE DE DESENVOLVIMENTO"
    _table_sep "$label_w" "$value_w" "┌" "┬" "┐"

    local shells_str; shells_str=$(_truncate_items "$value_w" "${selected_shells[@]}")
    _table_row "$(_with_count "Shells" "${#selected_shells[@]}")" "$shells_str" "$label_w" "$value_w"

    local themes_str; themes_str=$(_truncate_items "$value_w" "${themes_selected[@]}")
    _table_row "$(_with_count "Temas" "${#themes_selected[@]}")" "$themes_str" "$label_w" "$value_w"

    local term_str
    if [[ ${#SELECTED_TERMINALS[@]} -gt 0 ]]; then
      term_str=$(_truncate_items "$value_w" "${SELECTED_TERMINALS[@]}")
    else
      term_str="(nenhum)"
    fi
    _table_row "$(_with_count "Terminal" "${#SELECTED_TERMINALS[@]}")" "$term_str" "$label_w" "$value_w"

    local fonts_str
    if [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]]; then
      fonts_str=$(_truncate_items "$value_w" "${SELECTED_NERD_FONTS[@]}")
    else
      fonts_str="(nenhuma)"
    fi
    _table_row "$(_with_count "Nerd Fonts" "${#SELECTED_NERD_FONTS[@]}")" "$fonts_str" "$label_w" "$value_w"

    _table_sep "$label_w" "$value_w" "└" "┴" "┘"

    # ═══════════════════════════════════════════════════════════════════════════
    # SEÇÃO 2: FERRAMENTAS & RUNTIMES
    # ═══════════════════════════════════════════════════════════════════════════
    _section_header "🔧" "FERRAMENTAS & RUNTIMES"
    _table_sep "$label_w" "$value_w" "┌" "┬" "┐"

    local cli_str
    if [[ ${#SELECTED_CLI_TOOLS[@]} -gt 0 ]]; then
      cli_str=$(_truncate_items "$value_w" "${SELECTED_CLI_TOOLS[@]}")
    else
      cli_str="(nenhuma)"
    fi
    _table_row "$(_with_count "CLI Tools" "${#SELECTED_CLI_TOOLS[@]}")" "$cli_str" "$label_w" "$value_w"

    local ia_str
    if [[ ${#SELECTED_IA_TOOLS[@]} -gt 0 ]]; then
      ia_str=$(_truncate_items "$value_w" "${SELECTED_IA_TOOLS[@]}")
    else
      ia_str="(nenhuma)"
    fi
    _table_row "$(_with_count "IA Tools" "${#SELECTED_IA_TOOLS[@]}")" "$ia_str" "$label_w" "$value_w"

    local rt_str
    if [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]]; then
      rt_str=$(_truncate_items "$value_w" "${SELECTED_RUNTIMES[@]}")
    else
      rt_str="(nenhum)"
    fi
    _table_row "$(_with_count "Runtimes" "${#SELECTED_RUNTIMES[@]}")" "$rt_str" "$label_w" "$value_w"

    _table_sep "$label_w" "$value_w" "└" "┴" "┘"

    # ═══════════════════════════════════════════════════════════════════════════
    # SEÇÃO 3: APLICATIVOS GUI
    # ═══════════════════════════════════════════════════════════════════════════
    if [[ $gui_total -gt 0 ]]; then
      _section_header "📦" "APLICATIVOS GUI ($gui_total apps)"
      _table_sep "$label_w" "$value_w" "┌" "┬" "┐"

      [[ ${#SELECTED_IDES[@]} -gt 0 ]] && _table_row "IDEs" "$(_truncate_items "$value_w" "${SELECTED_IDES[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_BROWSERS[@]} -gt 0 ]] && _table_row "Navegadores" "$(_truncate_items "$value_w" "${SELECTED_BROWSERS[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_DEV_TOOLS[@]} -gt 0 ]] && _table_row "Dev Tools" "$(_truncate_items "$value_w" "${SELECTED_DEV_TOOLS[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_DATABASES[@]} -gt 0 ]] && _table_row "Bancos" "$(_truncate_items "$value_w" "${SELECTED_DATABASES[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_PRODUCTIVITY[@]} -gt 0 ]] && _table_row "Produtividade" "$(_truncate_items "$value_w" "${SELECTED_PRODUCTIVITY[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_COMMUNICATION[@]} -gt 0 ]] && _table_row "Comunicação" "$(_truncate_items "$value_w" "${SELECTED_COMMUNICATION[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_MEDIA[@]} -gt 0 ]] && _table_row "Mídia" "$(_truncate_items "$value_w" "${SELECTED_MEDIA[@]}")" "$label_w" "$value_w"
      [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]] && _table_row "Utilitários" "$(_truncate_items "$value_w" "${SELECTED_UTILITIES[@]}")" "$label_w" "$value_w"

      _table_sep "$label_w" "$value_w" "└" "┴" "┘"
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # SEÇÃO 4: CONFIGURAÇÕES A COPIAR
    # ═══════════════════════════════════════════════════════════════════════════
    _section_header "📋" "CONFIGURAÇÕES A COPIAR"

    local cfg_w=$((label_w + value_w + 5))
    local cfg_line
    cfg_line=$(printf '─%.0s' $(seq 1 $((cfg_w - 2))))
    echo -e "${BANNER_CYAN}┌${cfg_line}┐${BANNER_RESET}"

    # Grid horizontal de configs
    local cfg_items=()

    # Shells
    [[ ${INSTALL_ZSH:-0} -eq 1 ]] && {
      [[ ${COPY_ZSH_CONFIG:-0} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} Zsh") || cfg_items+=("${BANNER_DIM}✗ Zsh${BANNER_RESET}")
    }
    [[ ${INSTALL_FISH:-0} -eq 1 ]] && {
      [[ ${COPY_FISH_CONFIG:-0} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} Fish") || cfg_items+=("${BANNER_DIM}✗ Fish${BANNER_RESET}")
    }
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && {
      [[ ${COPY_NUSHELL_CONFIG:-0} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} Nushell") || cfg_items+=("${BANNER_DIM}✗ Nushell${BANNER_RESET}")
    }

    # Git
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]] && {
      [[ ${COPY_GIT_CONFIG:-0} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} Git") || cfg_items+=("${BANNER_DIM}✗ Git${BANNER_RESET}")
    }

    # Neovim (se selecionado em IDEs)
    local has_neovim=0
    for ide in "${SELECTED_IDES[@]}"; do [[ "$ide" == "neovim" ]] && has_neovim=1 && break; done
    [[ $has_neovim -eq 1 ]] && {
      [[ ${COPY_NVIM_CONFIG:-0} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} Neovim") || cfg_items+=("${BANNER_DIM}✗ Neovim${BANNER_RESET}")
    }

    # tmux (se selecionado em CLI Tools)
    local has_tmux=0
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do [[ "$tool" == "tmux" ]] && has_tmux=1 && break; done
    [[ $has_tmux -eq 1 ]] && {
      [[ ${COPY_TMUX_CONFIG:-0} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} tmux") || cfg_items+=("${BANNER_DIM}✗ tmux${BANNER_RESET}")
    }

    # VS Code
    if [[ -f "$CONFIG_SHARED/vscode/settings.json" ]] || [[ -f "$CONFIG_SHARED/vscode/extensions.txt" ]]; then
      [[ ${COPY_VSCODE_SETTINGS:-1} -eq 1 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} VS Code") || cfg_items+=("${BANNER_DIM}✗ VS Code${BANNER_RESET}")
    fi

    # Mise
    [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && cfg_items+=("${BANNER_GREEN}✓${BANNER_RESET} Mise")

    # Imprimir configs em grid (3-4 por linha)
    local line_content=""
    local item_count=0
    local items_per_line=4
    [[ $term_width -lt 80 ]] && items_per_line=3

    for cfg in "${cfg_items[@]}"; do
      if [[ -n "$line_content" ]]; then
        line_content+="   "
      fi
      line_content+="$cfg"
      ((item_count++))

      if [[ $item_count -ge $items_per_line ]]; then
        printf "${BANNER_CYAN}│${BANNER_RESET} %-$((cfg_w - 3))b ${BANNER_CYAN}│${BANNER_RESET}\n" "$line_content"
        line_content=""
        item_count=0
      fi
    done

    # Imprimir linha restante
    [[ -n "$line_content" ]] && printf "${BANNER_CYAN}│${BANNER_RESET} %-$((cfg_w - 3))b ${BANNER_CYAN}│${BANNER_RESET}\n" "$line_content"

    # Se não houver configs
    [[ ${#cfg_items[@]} -eq 0 ]] && printf "${BANNER_CYAN}│${BANNER_RESET} ${BANNER_DIM}(nenhuma configuração selecionada)${BANNER_RESET}%*s${BANNER_CYAN}│${BANNER_RESET}\n" $((cfg_w - 37)) ""

    echo -e "${BANNER_CYAN}└${cfg_line}┘${BANNER_RESET}"
    echo -e "${BANNER_DIM}💾 Backup automático em ~/.bkp-YYYYMMDD-HHMM/${BANNER_RESET}"

    # ═══════════════════════════════════════════════════════════════════════════
    # MENU SIMPLIFICADO
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    local menu_line
    menu_line=$(printf '═%.0s' $(seq 1 $((cfg_w))))
    echo -e "${BANNER_CYAN}${menu_line}${BANNER_RESET}"
    echo -e "${BANNER_GREEN}[Enter/C]${BANNER_RESET} Instalar   ${BANNER_YELLOW}[S]${BANNER_RESET} Sair   ${BANNER_DIM}[1-8]${BANNER_RESET} Editar seção   ${BANNER_DIM}[0]${BANNER_RESET} Configs"
    echo -e "${BANNER_CYAN}${menu_line}${BANNER_RESET}"
    echo ""
    read -r -p "Escolha: " choice
    case "$choice" in
      ""|c|C)
        break
        ;;
      s|S)
        msg ""
        msg "⏹️  Instalação cancelada pelo usuário."
        msg ""
        exit 0
        ;;
      1)
        ask_shells
        ask_themes
        [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && ask_oh_my_zsh_plugins
        [[ $INSTALL_STARSHIP -eq 1 ]] && ask_starship_preset
        [[ $INSTALL_OH_MY_POSH -eq 1 ]] && ask_oh_my_posh_theme
        [[ $INSTALL_FISH -eq 1 ]] && ask_fish_plugins
        ;;
      2)
        ask_nerd_fonts
        ;;
      3)
        ask_terminals
        ;;
      4)
        ask_cli_tools
        ;;
      5)
        ask_ia_tools
        ;;
      6)
        ask_gui_apps
        ;;
      7)
        ask_runtimes
        ;;
      8)
        ask_git_configuration
        ;;
      0)
        ask_configs_to_copy
        ;;
      *)
        msg "  ⚠️ Opção inválida."
        sleep 1
        ;;
    esac
  done
}

ask_yes_no() {
  local prompt="$1"
  local response
  while true; do
    read -r -p "$prompt (s/n): " response
    case "$response" in
      [SsYy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) msg "  ⚠️ Responda 's' para sim ou 'n' para não" ;;
    esac
  done
}

# Confirmação moderna com Enter/P (Pular)
# Retorna 0 se confirmar (Enter), 1 se pular (P)
confirm_action() {
  local prompt="$1"
  echo ""
  echo -e "  ${UI_CYAN}Enter${UI_RESET} para $prompt  │  ${UI_YELLOW}P${UI_RESET} para pular"
  echo ""
  local choice
  read -r -p "  → " choice
  case "${choice,,}" in
    p|pular|skip) return 1 ;;
    *) return 0 ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════════════
# SELEÇÃO DE CONFIGURAÇÕES A COPIAR
# ══════════════════════════════════════════════════════════════════════════════
ask_configs_to_copy() {
  local config_options=()
  local config_keys=()

  # Construir lista de opções disponíveis
  if [[ ${INSTALL_ZSH:-0} -eq 1 ]]; then
    config_options+=("zsh-config      - Zsh (~/.zshrc, .p10k.zsh)")
    config_keys+=("COPY_ZSH_CONFIG")
  fi

  if [[ ${INSTALL_FISH:-0} -eq 1 ]]; then
    config_options+=("fish-config     - Fish (~/.config/fish/)")
    config_keys+=("COPY_FISH_CONFIG")
  fi

  if [[ ${INSTALL_NUSHELL:-0} -eq 1 ]]; then
    config_options+=("nushell-config  - Nushell (~/.config/nushell/)")
    config_keys+=("COPY_NUSHELL_CONFIG")
  fi

  if [[ ${GIT_CONFIGURE:-0} -eq 1 ]]; then
    config_options+=("git-config      - Git (~/.gitconfig)")
    config_keys+=("COPY_GIT_CONFIG")
  fi

  # Neovim config - mostrar se tem config salva E neovim selecionado em IDEs
  if [[ -d "$CONFIG_SHARED/nvim" ]] && [[ -n "$(ls -A "$CONFIG_SHARED/nvim" 2>/dev/null)" ]]; then
    local has_neovim=0
    for ide in "${SELECTED_IDES[@]}"; do
      [[ "$ide" == "neovim" ]] && has_neovim=1 && break
    done
    if [[ $has_neovim -eq 1 ]]; then
      config_options+=("nvim-config     - Neovim (~/.config/nvim/)")
      config_keys+=("COPY_NVIM_CONFIG")
    fi
  fi

  # Tmux config - mostrar se tem config salva E tmux selecionado em CLI Tools
  if [[ -d "$CONFIG_SHARED/tmux" ]] && [[ -n "$(ls -A "$CONFIG_SHARED/tmux" 2>/dev/null)" ]]; then
    local has_tmux=0
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do
      [[ "$tool" == "tmux" ]] && has_tmux=1 && break
    done
    if [[ $has_tmux -eq 1 ]]; then
      config_options+=("tmux-config     - Tmux (~/.tmux.conf)")
      config_keys+=("COPY_TMUX_CONFIG")
    fi
  fi

  if [[ ${#SELECTED_TERMINALS[@]} -gt 0 ]]; then
    config_options+=("terminal-config - Terminal (ghostty, kitty, etc)")
    config_keys+=("COPY_TERMINAL_CONFIG")
  fi

  if [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]]; then
    config_options+=("mise-config     - Mise (~/.config/mise/)")
    config_keys+=("COPY_MISE_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/vscode/settings.json" ]] || [[ -f "$CONFIG_SHARED/vscode/extensions.txt" ]]; then
    config_options+=("vscode-config   - VS Code (settings + extensões)")
    config_keys+=("COPY_VSCODE_SETTINGS")
  fi

  # SSH Keys - sempre mostrar se existir
  local ssh_source=""
  if [[ -n "$PRIVATE_SHARED" ]] && [[ -d "$PRIVATE_SHARED/.ssh" ]]; then
    ssh_source="$PRIVATE_SHARED/.ssh"
  elif [[ -d "$CONFIG_SHARED/.ssh" ]]; then
    ssh_source="$CONFIG_SHARED/.ssh"
  fi
  if [[ -n "$ssh_source" ]]; then
    config_options+=("ssh-keys        - SSH Keys (~/.ssh/) ⚠️ SENSÍVEL")
    config_keys+=("COPY_SSH_KEYS")
  fi

  if [[ ${#config_options[@]} -eq 0 ]]; then
    msg "  ℹ️  Nenhuma configuração disponível para copiar."
    msg ""
    return 0
  fi

  # Resetar todas as variáveis COPY_* para 0 antes da seleção
  for key in "${config_keys[@]}"; do
    eval "$key=0"
  done

  clear_screen
  show_section_header "📋 CONFIGURAÇÕES A COPIAR"

  msg "Selecione quais configurações do repositório serão copiadas."
  msg "💾 Um backup será criado automaticamente antes de sobrescrever."
  msg ""

  local selected_configs=()
  select_multiple_items "📋 Selecione as Configs a Copiar" selected_configs "${config_options[@]}"

  # Mapear seleções para variáveis COPY_*
  for item in "${selected_configs[@]}"; do
    local config_id
    config_id="$(echo "$item" | awk '{print $1}')"
    case "$config_id" in
      "zsh-config")      COPY_ZSH_CONFIG=1 ;;
      "fish-config")     COPY_FISH_CONFIG=1 ;;
      "nushell-config")  COPY_NUSHELL_CONFIG=1 ;;
      "git-config")      COPY_GIT_CONFIG=1 ;;
      "nvim-config")     COPY_NVIM_CONFIG=1 ;;
      "tmux-config")     COPY_TMUX_CONFIG=1 ;;
      "terminal-config") COPY_TERMINAL_CONFIG=1 ;;
      "mise-config")     COPY_MISE_CONFIG=1 ;;
      "vscode-config")   COPY_VSCODE_SETTINGS=1 ;;
      "ssh-keys")        COPY_SSH_KEYS=1 ;;
    esac
  done
}

print_error_block() {
  local title="$1"
  shift
  local items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    return
  fi
  msg "  $title"
  for item in "${items[@]}"; do
    msg "   - $item"
  done
  msg ""
}

print_final_summary() {
  local force_exit="${1:-}"
  local exit_code=0
  if [[ ${#CRITICAL_ERRORS[@]} -gt 0 ]]; then
    exit_code=1
  fi
  if [[ -n "$force_exit" ]]; then
    exit_code="$force_exit"
  fi

  if [[ ${#CRITICAL_ERRORS[@]} -gt 0 || ${#OPTIONAL_ERRORS[@]} -gt 0 ]]; then
    msg ""
    msg "⚠️  Falhas durante a execução (${MODE}):"
    msg "────────────────────────────────────────────────────────────"
    print_error_block "❌ Falhas críticas:" "${CRITICAL_ERRORS[@]}"
    print_error_block "⚠️  Falhas opcionais:" "${OPTIONAL_ERRORS[@]}"

    if [[ ${#CRITICAL_ERRORS[@]} -eq 0 ]]; then
      msg "  ✅ Execução concluída sem falhas críticas."
    else
      msg "  ❌ Execução finalizada com falhas críticas."
    fi

    msg ""
  fi
  exit "$exit_code"
}

detect_os() {
  case "${OSTYPE:-}" in
    linux*)
      if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        echo "wsl2"
      else
        echo "linux"
      fi
      ;;
    darwin*) echo "macos" ;;
    msys*|cygwin*|win32*) echo "windows" ;;
    *) echo "linux" ;;
  esac
}

is_wsl2() {
  [[ "$TARGET_OS" == "wsl2" ]]
}

get_distro_codename() {
  local default_codename="${1:-stable}"
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${VERSION_CODENAME:-$default_codename}"
  else
    echo "$default_codename"
  fi
}

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

install_chrome_linux() {
  detect_linux_pkg_manager
  if has_cmd google-chrome || command -v google-chrome-stable >/dev/null 2>&1 || has_flatpak_ref "com.google.Chrome"; then
    local chrome_version
    chrome_version="$(google-chrome --version 2>/dev/null || google-chrome-stable --version 2>/dev/null || echo '')"
    if [[ -n "$chrome_version" ]]; then
      msg "  ✅ Google Chrome já instalado ($chrome_version)"
    fi
    return 0
  fi
  if [[ "$LINUX_PKG_MANAGER" != "apt-get" ]]; then
    record_failure "optional" "Google Chrome (Linux) suportado automaticamente apenas em distros apt; instale manualmente."
    return 0
  fi
  local deb=""
  deb="$(mktemp)" || {
    record_failure "optional" "Falha ao criar arquivo temporário para Google Chrome"
    return 1
  }
  trap 'rm -f "$deb"' RETURN

  msg "  📦 Baixando Google Chrome para Linux..."
  if curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$deb"; then
    if run_with_sudo dpkg -i "$deb"; then
      msg "  ✅ Google Chrome instalado"
      INSTALLED_MISC+=("google-chrome: deb")
      run_with_sudo apt-get install -f -y >/dev/null 2>&1 || true
    else
      record_failure "optional" "Falha ao instalar Google Chrome via dpkg"
    fi
  else
    record_failure "optional" "Falha ao baixar Google Chrome"
  fi
}

install_via_flatpak_or_snap() {
  local cmd="$1"
  local friendly="$2"
  local flatpak_ref="$3"
  local snap_pkg="${4:-}"

  if has_cmd "$cmd"; then
    local version=""
    version="$($cmd --version 2>/dev/null | head -n 1 || echo '')"
    if [[ -n "$version" ]]; then
      msg "  ✅ $friendly já instalado ($version)"
    else
      msg "  ✅ $friendly já instalado"
    fi
    return 0
  fi

  if has_cmd flatpak; then
    flatpak_install_or_update "$flatpak_ref" "$friendly" optional
    return 0
  fi

  if [[ -n "$snap_pkg" ]] && has_cmd snap; then
    snap_install_or_refresh "$snap_pkg" "$friendly" optional
    return 0
  fi

  if [[ -n "$snap_pkg" ]]; then
    record_failure "optional" "$friendly não instalado: Flatpak/Snap indisponíveis nesta distro."
  else
    record_failure "optional" "$friendly não instalado: Flatpak indisponível nesta distro."
  fi
  return 1
}

install_brave_linux() {
  install_via_flatpak_or_snap "brave-browser" "Brave" "com.brave.Browser" "brave"
}

install_zen_linux() {
  install_via_flatpak_or_snap "zen-browser" "Zen Browser" "io.github.ranfdev.Zen"
}

install_pgadmin_linux() {
  install_via_flatpak_or_snap "pgadmin4" "pgAdmin" "org.pgadmin.pgadmin4"
}

install_mongodb_linux() {
  if has_cmd mongod || has_cmd mongodb-compass; then
    local mongo_version
    mongo_version="$(mongod --version 2>/dev/null | head -n 1 || echo '')"
    if [[ -n "$mongo_version" ]]; then
      msg "  ✅ MongoDB já instalado ($mongo_version)"
    fi
    return 0
  fi
  if has_cmd flatpak; then
    flatpak_install_or_update com.mongodb.Compass "MongoDB Compass" optional
    return 0
  fi
  install_linux_packages optional mongodb 2>/dev/null
}

install_vscode_linux() {
  if has_snap_pkg code; then
    msg "  🔄 Atualizando VS Code via snap (stable)..."
    if run_with_sudo snap refresh code --channel=stable >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: snap refresh (stable)")
    else
      record_failure "optional" "Falha ao atualizar VS Code via snap"
    fi
    return 0
  fi

  if has_flatpak_ref "com.visualstudio.code"; then
    msg "  🔄 Atualizando VS Code via flatpak..."
    if flatpak update -y com.visualstudio.code >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: flatpak update")
    else
      record_failure "optional" "Falha ao atualizar VS Code via flatpak"
    fi
    return 0
  fi

  detect_linux_pkg_manager

  if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
    if has_cmd code; then
      local installed_version
      installed_version="$(code --version 2>/dev/null | head -n 1 || echo '')"
      if [[ -n "$installed_version" ]]; then
        msg "  ✅ VS Code já instalado (versão: $installed_version)"
        return 0
      fi
    fi

    msg "  📦 Instalando VS Code (deb oficial)..."

    local deb=""
    deb="$(mktemp)" || {
      record_failure "optional" "Falha ao criar arquivo temporário para VS Code"
      return 1
    }
    trap 'rm -f "$deb"' RETURN

    if curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o "$deb"; then
      if run_with_sudo dpkg -i "$deb" >/dev/null 2>&1; then
        INSTALLED_MISC+=("vscode: deb oficial (stable)")
      else
        run_with_sudo apt-get install -f -y >/dev/null 2>&1 || true
        if run_with_sudo dpkg -i "$deb" >/dev/null 2>&1; then
          INSTALLED_MISC+=("vscode: deb oficial (stable)")
        else
          record_failure "optional" "Falha ao instalar VS Code (deb)"
        fi
      fi
      return 0
    fi
    record_failure "optional" "Falha ao baixar VS Code (deb oficial)"
  fi

  if [[ "$LINUX_PKG_MANAGER" == "dnf" ]]; then
    if has_cmd code; then
      local installed_version
      installed_version="$(code --version 2>/dev/null | head -n 1 || echo '')"
      if [[ -n "$installed_version" ]]; then
        msg "  ✅ VS Code já instalado (versão: $installed_version)"
        return 0
      fi
    fi

    msg "  📦 Instalando VS Code (rpm oficial via dnf)..."
    if run_with_sudo dnf install -y "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: rpm oficial (stable)")
    else
      record_failure "optional" "Falha ao instalar VS Code via dnf (rpm oficial)"
    fi
    return 0
  fi

  if [[ "$LINUX_PKG_MANAGER" == "zypper" ]]; then
    if has_cmd code; then
      local installed_version
      installed_version="$(code --version 2>/dev/null | head -n 1 || echo '')"
      if [[ -n "$installed_version" ]]; then
        msg "  ✅ VS Code já instalado (versão: $installed_version)"
        return 0
      fi
    fi

    msg "  📦 Instalando VS Code (rpm oficial via zypper)..."
    if run_with_sudo zypper install -y "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: rpm oficial (stable)")
    else
      record_failure "optional" "Falha ao instalar VS Code via zypper (rpm oficial)"
    fi
    return 0
  fi

  if has_cmd snap; then
    msg "  📦 Instalando VS Code via snap (stable)..."
    if run_with_sudo snap install code --classic --channel=stable >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: snap install (stable)")
    else
      record_failure "optional" "Falha ao instalar VS Code via snap"
    fi
    return 0
  fi

  if has_cmd flatpak; then
    msg "  📦 Instalando VS Code via flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    if flatpak install -y flathub com.visualstudio.code >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: flatpak install")
    else
      record_failure "optional" "Falha ao instalar VS Code via flatpak"
    fi
    return 0
  fi

  record_failure "optional" "VS Code não instalado: apt/dnf/zypper/snap/flatpak indisponíveis nesta distro."
  return 0
}

install_vscode_macos() {
  # Objetivo: garantir VS Code Stable o mais recente possível no macOS.
  if has_cmd brew; then
    msg "  🍺 VS Code via Homebrew..."
    if brew list --cask visual-studio-code >/dev/null 2>&1; then
      # Show version if already installed
      if has_cmd code; then
        local version=""
        version="$(code --version 2>/dev/null | head -n 1 || echo '')"
        if [[ -n "$version" ]]; then
          msg "  ✅ VS Code já instalado (versão: $version)"
        fi
      fi
      if should_ensure_latest; then
        if brew upgrade --cask visual-studio-code >/dev/null 2>&1; then
          INSTALLED_PACKAGES+=("brew cask: visual-studio-code (upgrade)")
        else
          record_failure "optional" "Falha ao atualizar VS Code via Homebrew cask"
        fi
      fi
      return 0
    fi

    if brew install --cask visual-studio-code >/dev/null 2>&1; then
      INSTALLED_PACKAGES+=("brew cask: visual-studio-code (install)")
      return 0
    fi

    record_failure "optional" "Falha ao instalar VS Code via Homebrew cask"
    return 0
  fi

  record_failure "optional" "Homebrew não disponível: não foi possível instalar VS Code automaticamente no macOS"
  return 0
}

install_vscode_windows() {
  # Objetivo: garantir VS Code Stable o mais recente possível no Windows.
  if has_cmd winget; then
    local id="Microsoft.VisualStudioCode"
    local result=""
    result="$(winget list --id "$id" 2>/dev/null || true)"
    if [[ "$result" == *"$id"* ]]; then
      # Show version if already installed
      if has_cmd code; then
        local version=""
        version="$(code --version 2>/dev/null | head -n 1 || echo '')"
        if [[ -n "$version" ]]; then
          msg "  ✅ VS Code já instalado (versão: $version)"
        fi
      fi
      if should_ensure_latest; then
        if winget upgrade --id "$id" -e --accept-package-agreements --accept-source-agreements >/dev/null 2>&1; then
          INSTALLED_PACKAGES+=("winget: VS Code (upgrade)")
        else
          record_failure "optional" "Falha ao atualizar VS Code via winget"
        fi
      fi
      return 0
    fi

    if winget install --id "$id" -e --accept-package-agreements --accept-source-agreements >/dev/null 2>&1; then
      INSTALLED_PACKAGES+=("winget: VS Code (install)")
    else
      record_failure "optional" "Falha ao instalar VS Code via winget"
    fi
    return 0
  fi

  if has_cmd choco; then
    local package="vscode"
    local result=""
    result="$(choco list --local-only "$package" 2>/dev/null || true)"
    if [[ "$result" == *"$package"* ]]; then
      # Show version if already installed
      if has_cmd code; then
        local version=""
        version="$(code --version 2>/dev/null | head -n 1 || echo '')"
        if [[ -n "$version" ]]; then
          msg "  ✅ VS Code já instalado (versão: $version)"
        fi
      fi
      if should_ensure_latest; then
        if choco upgrade -y "$package" >/dev/null 2>&1; then
          INSTALLED_PACKAGES+=("choco: vscode (upgrade)")
        else
          record_failure "optional" "Falha ao atualizar VS Code via Chocolatey"
        fi
      fi
      return 0
    fi

    if choco install -y "$package" >/dev/null 2>&1; then
      INSTALLED_PACKAGES+=("choco: vscode (install)")
    else
      record_failure "optional" "Falha ao instalar VS Code via Chocolatey"
    fi
    return 0
  fi

  record_failure "optional" "VS Code não instalado: winget/Chocolatey não disponíveis"
  return 0
}

install_vscode() {
  case "${TARGET_OS:-}" in
    linux|wsl2) install_vscode_linux ;;
    macos) install_vscode_macos ;;
    windows) install_vscode_windows ;;
  esac
}

install_docker_linux() {
  # Objetivo: garantir Docker Engine + compose plugin pelo gerenciador nativo.
  if has_cmd docker; then
    local docker_version
    docker_version="$(docker --version 2>/dev/null | head -n 1 || echo '')"
    if [[ -n "$docker_version" ]]; then
      msg "  ✅ Docker já instalado ($docker_version)"
    fi
    return 0
  fi

  detect_linux_pkg_manager
  case "$LINUX_PKG_MANAGER" in
    apt-get)
      install_linux_packages optional docker.io docker-compose-plugin
      ;;
    dnf)
      install_linux_packages optional docker docker-compose
      ;;
    pacman)
      install_linux_packages optional docker docker-compose
      ;;
    zypper)
      install_linux_packages optional docker docker-compose
      ;;
    *)
      record_failure "optional" "Docker não instalado: gerenciador não suportado para Docker Engine."
      ;;
  esac
}

install_php_build_deps_linux() {
  detect_linux_pkg_manager
  case "$LINUX_PKG_MANAGER" in
    apt-get)
      install_linux_packages optional \
        autoconf bison build-essential pkg-config re2c plocate \
        libgd-dev libcurl4-openssl-dev libedit-dev libicu-dev libjpeg-dev \
        libmysqlclient-dev libonig-dev libpng-dev libpq-dev libreadline-dev \
        libsqlite3-dev libssl-dev libxml2-dev libxslt-dev libzip-dev \
        gettext git curl openssl
      ;;
    dnf)
      install_linux_packages optional \
        autoconf bison gcc gcc-c++ make pkg-config re2c mlocate \
        gd-devel libzip-devel libxml2-devel libxslt-devel libcurl-devel \
        libedit-devel libicu-devel libjpeg-turbo-devel libpng-devel \
        libpq-devel readline-devel sqlite-devel openssl-devel oniguruma-devel \
        gettext-devel git curl openssl mysql-devel
      ;;
    pacman)
      install_linux_packages optional \
        autoconf bison base-devel pkgconf re2c mlocate \
        gd libzip libxml2 libxslt curl libedit icu libjpeg-turbo libpng \
        libpq readline sqlite openssl oniguruma gettext git mariadb-libs
      ;;
    zypper)
      install_linux_packages optional \
        autoconf bison gcc gcc-c++ make pkg-config re2c mlocate \
        gd-devel libzip-devel libxml2-devel libxslt-devel libcurl-devel \
        libedit-devel libicu-devel libjpeg8-devel libpng16-devel libpq-devel \
        readline-devel sqlite3-devel libopenssl-devel oniguruma-devel \
        gettext-tools git curl libmysqlclient-devel
      ;;
  esac
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

install_php_windows() {
  local installed=0
  if has_cmd winget; then
    winget_install PHP.PHP "PHP" optional
    if has_cmd php; then
      installed=1
    else
      winget_install PHP.PHP.8.3 "PHP 8.3" optional
      has_cmd php && installed=1
    fi
  fi

  if [[ $installed -eq 0 ]] && has_cmd choco; then
    choco_install php "PHP (latest)" optional
    has_cmd php && installed=1
  fi

  if [[ $installed -eq 1 ]]; then
    msg "  ✅ PHP (latest) instalado/atualizado no Windows (winget/choco)"
    return 0
  fi

  record_failure "optional" "PHP não instalado no Windows: winget/choco indisponíveis ou falharam"
  return 1
}

install_composer_and_laravel() {
  if ! has_cmd composer; then
    if has_cmd mise; then
      msg "  📦 Composer (latest) via mise..."
      if ! mise use -g -y composer@latest >/dev/null 2>&1; then
        record_failure "optional" "Falha ao instalar Composer via mise"
        return
      fi
    else
      record_failure "optional" "Composer não instalado: mise ausente"
      return
    fi
  fi

  if ! has_cmd laravel; then
    msg "  📦 Laravel installer via Composer..."
    if composer global require laravel/installer >/dev/null 2>&1; then
      local bin_dir
      bin_dir="$(composer global config bin-dir --absolute 2>/dev/null || true)"
      if [[ -n "$bin_dir" && -x "$bin_dir/laravel" ]]; then
        mkdir -p "$HOME/.local/bin"
        if [[ ! -e "$HOME/.local/bin/laravel" ]]; then
          ln -s "$bin_dir/laravel" "$HOME/.local/bin/laravel" 2>/dev/null || true
        fi
      fi
    else
      record_failure "optional" "Falha ao instalar Laravel installer via Composer"
    fi
  fi
}

# Helper: Download and execute installer script
# Usage: download_and_run_script <url> <friendly_name> [shell] [curl_extra_flags] [script_args]
# Returns: 0 on success, 1 on failure (sets INSTALLER_ERROR with details)
download_and_run_script() {
  local url="$1"
  local friendly="$2"
  local shell="${3:-sh}"
  local curl_extra="${4:-}"
  local script_args="${5:-}"

  if ! has_cmd curl; then
    record_failure "critical" "curl não encontrado. Instale curl primeiro para continuar."
    return 1
  fi

  local temp_script=""
  temp_script="$(mktemp)" || {
    record_failure "critical" "Falha ao criar arquivo temporário para instalador $friendly"
    return 1
  }
  trap 'rm -f "$temp_script"' RETURN

  # shellcheck disable=SC2086
  if ! curl -fsSL $curl_extra "$url" -o "$temp_script"; then
    record_failure "critical" "Falha ao baixar instalador $friendly"
    return 1
  fi

  # shellcheck disable=SC2086
  if $shell "$temp_script" $script_args >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

ensure_rust_cargo() {
  if has_cmd cargo; then
    return 0
  fi

  msg "▶ Rust/Cargo não encontrado. Instalando..."

  if download_and_run_script "https://sh.rustup.rs" "Rust" "bash" "" "-y --no-modify-path"; then
    export PATH="$HOME/.cargo/bin:$PATH"
    INSTALLED_MISC+=("rustup: installer script")
    msg "  ✅ Rust/Cargo instalado com sucesso"
    return 0
  else
    record_failure "critical" "Falha ao instalar Rust/Cargo. Algumas ferramentas não estarão disponíveis."
    return 1
  fi
}

ensure_ghostty_linux() {
  if has_cmd ghostty; then
    return 0
  fi

  msg "▶ Ghostty não encontrado. Tentando instalar..."

  local distro=""
  if [[ -f /etc/os-release ]]; then
    distro="$(. /etc/os-release && echo "$ID")"
  fi

  case "$distro" in
    ubuntu|pop|neon)
      msg "  📦 Ubuntu/derivados detectado. Instalando via script mkasberg..."
      if bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)" >/dev/null 2>&1; then
        msg "  ✅ Ghostty instalado com sucesso"
        INSTALLED_MISC+=("ghostty: mkasberg script")
        return 0
      fi
      ;;
    debian)
      msg "  📦 Debian detectado. Instalando via repositório griffo.io..."
      if curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | run_with_sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg 2>/dev/null; then
        local codename
        codename="$(get_distro_codename "bookworm")"
        echo "deb https://debian.griffo.io/apt $codename main" | run_with_sudo tee /etc/apt/sources.list.d/debian.griffo.io.list >/dev/null
        run_with_sudo apt-get update >/dev/null 2>&1
        if run_with_sudo apt-get install -y ghostty >/dev/null 2>&1; then
          msg "  ✅ Ghostty instalado com sucesso"
          INSTALLED_MISC+=("ghostty: apt")
          return 0
        fi
      fi
      ;;
    arch|manjaro|endeavouros)
      msg "  📦 Arch/derivados detectado. Instalando via pacman..."
      if run_with_sudo pacman -Sy --noconfirm --needed ghostty >/dev/null 2>&1; then
        msg "  ✅ Ghostty instalado com sucesso"
        INSTALLED_MISC+=("ghostty: pacman")
        return 0
      fi
      ;;
    fedora|rhel|centos|rocky|almalinux)
      msg "  📦 Fedora/RHEL detectado. Tentando via snap..."
      if has_cmd snap; then
        snap_install_or_refresh ghostty "Ghostty" optional --classic
        if has_cmd ghostty; then
          msg "  ✅ Ghostty instalado via snap"
          return 0
        fi
      fi
      ;;
    opensuse*|suse)
      msg "  📦 openSUSE detectado. Instalando via zypper..."
      if run_with_sudo zypper install -y ghostty >/dev/null 2>&1; then
        msg "  ✅ Ghostty instalado com sucesso"
        INSTALLED_MISC+=("ghostty: zypper")
        return 0
      fi
      ;;
  esac

  if has_cmd flatpak; then
    if ! flatpak info com.mitchellh.ghostty >/dev/null 2>&1; then
      msg "  📦 Tentando instalar via Flatpak..."
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
      if flatpak install -y flathub com.mitchellh.ghostty >/dev/null 2>&1; then
        msg "  ✅ Ghostty instalado via Flatpak"
        INSTALLED_MISC+=("ghostty: flatpak")
        return 0
      fi
    fi
  fi

  if has_cmd snap; then
    if run_with_sudo snap install ghostty --classic >/dev/null 2>&1; then
      msg "  ✅ Ghostty instalado via snap"
      INSTALLED_MISC+=("ghostty: snap")
      return 0
    fi
  fi

  record_failure "critical" "Não foi possível instalar Ghostty automaticamente."
  msg "  ℹ️  Visite https://ghostty.org para instruções de instalação manual."
  return 1
}

ensure_uv() {
  if has_cmd uv; then
    return 0
  fi

  msg "▶ uv (Python Package Manager) não encontrado. Instalando..."

  if download_and_run_script "https://astral.sh/uv/install.sh" "uv"; then
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("uv: installer script")
    msg "  ✅ uv instalado com sucesso"

    # Generate shell completions
    if has_cmd fish && [[ -d "$HOME/.config/fish/completions" ]]; then
      uv generate-shell-completion fish > "$HOME/.config/fish/completions/uv.fish" 2>/dev/null
    fi
    if has_cmd zsh && [[ -d "$HOME/.oh-my-zsh/completions" ]]; then
      uv generate-shell-completion zsh > "$HOME/.oh-my-zsh/completions/_uv" 2>/dev/null
    fi

    return 0
  else
    record_failure "critical" "Falha ao instalar uv. Python packages precisarão ser instalados manualmente."
    return 1
  fi
}

ensure_mise() {
  if has_cmd mise; then
    return 0
  fi

  msg "▶ mise (runtime manager) não encontrado. Instalando..."

  # Try Homebrew first on macOS
  if [[ "${TARGET_OS:-}" == "macos" ]] && has_cmd brew; then
    if brew install mise >/dev/null 2>&1; then
      INSTALLED_PACKAGES+=("brew: mise (install)")
      msg "  ✅ mise instalado via Homebrew"
      return 0
    fi
  fi

  # Fall back to installer script
  if download_and_run_script "https://mise.run" "mise"; then
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("mise: installer script")
    msg "  ✅ mise instalado com sucesso"
    return 0
  fi

  record_failure "critical" "Falha ao instalar mise. Instale manualmente (https://mise.jdx.dev/installing-mise.html)."
  return 1
}

ensure_spec_kit() {
  if ! has_cmd uv; then
    record_failure "optional" "uv não encontrado. spec-kit precisa de uv instalado."
    msg "  💡 Execute: curl -LsSf https://astral.sh/uv/install.sh | sh"
    return 1
  fi

  if has_cmd specify; then
    local spec_version
    spec_version="$(specify --version 2>/dev/null | head -n1 || echo 'unknown')"
    msg "  ℹ️  spec-kit já instalado: $spec_version"
    if uv tool list 2>/dev/null | grep -q "specify-cli"; then
      msg "  💡 Para atualizar: uv tool upgrade specify-cli"
    fi
    return 0
  fi

  msg "▶ spec-kit (Spec-Driven Development) não encontrado. Instalando..."
  msg "  📚 Spec-Kit: Toolkit do GitHub para desenvolvimento guiado por especificações"
  msg "  🤖 Integra com Claude para gerar especificações e implementações"

  local install_output
  install_output="$(uv tool install specify-cli --from git+https://github.com/github/spec-kit.git 2>&1)"
  local install_status=$?

  if [[ $install_status -eq 0 ]]; then
    export PATH="$HOME/.local/bin:$PATH"
    if has_cmd specify; then
      local installed_version
      installed_version="$(specify --version 2>/dev/null | head -n1 || echo 'instalado')"
      msg "  ✅ spec-kit instalado com sucesso: $installed_version"
      INSTALLED_MISC+=("spec-kit: uv tool install")
      msg ""
      msg "  📖 Como usar o spec-kit:"
      msg "     • specify init <projeto> --ai claude  # Inicializar com Claude"
      msg "     • specify generate                     # Gerar implementação"
      msg "     • specify validate                     # Validar especificação"
      msg "     • specify --help                       # Ver todos os comandos"
      msg ""
      return 0
    else
      record_failure "optional" "spec-kit instalado mas comando 'specify' não encontrado no PATH"
      msg "  💡 Reinicie o shell ou adicione ~/.local/bin ao PATH"
      return 1
    fi
  else
    record_failure "optional" "Falha ao instalar spec-kit"
    msg "  📋 Saída do erro:"
    echo "$install_output" | head -n5 | sed 's/^/     /'
    msg ""
    msg "  🔧 Tente instalar manualmente:"
    msg "     uv tool install specify-cli --from git+https://github.com/github/spec-kit.git"
    msg ""
    msg "  📚 Mais informações: https://github.com/github/spec-kit"
    return 1
  fi
}

ensure_atuin() {
  if has_cmd atuin; then
    return 0
  fi

  msg "▶ Atuin (Better Shell History) não encontrado. Instalando..."

  if download_and_run_script "https://setup.atuin.sh" "Atuin" "sh" "" "--yes"; then
    export PATH="$HOME/.atuin/bin:$PATH"
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("atuin: installer script")
    msg "  ✅ Atuin instalado com sucesso"
    msg "  💡 Atuin sincroniza histórico de comandos entre máquinas"
    msg "  💡 Use 'atuin register' para criar conta e sincronizar"
    msg "  💡 Use 'atuin login' se já tiver conta"

    # Configure fish shell integration
    if has_cmd fish && [[ -d "$HOME/.config/fish" ]]; then
      local fish_config="$HOME/.config/fish/config.fish"
      if [[ -f "$fish_config" ]] && ! grep -q "atuin init fish" "$fish_config"; then
        {
          echo ""
          echo "# Atuin - Better Shell History"
          echo "if type -q atuin"
          echo "  atuin init fish | source"
          echo "end"
        } >> "$fish_config"
      fi
    fi

    # Configure zsh shell integration
    if has_cmd zsh && [[ -f "$HOME/.zshrc" ]]; then
      if ! grep -q "atuin init zsh" "$HOME/.zshrc"; then
        {
          echo ""
          echo "# Atuin - Better Shell History"
          # shellcheck disable=SC2016
          echo 'eval "$(atuin init zsh)"'
        } >> "$HOME/.zshrc"
      fi
    fi

    return 0
  else
    record_failure "critical" "Falha ao instalar Atuin. Tente manualmente: curl -fsSL https://setup.atuin.sh | sh"
    return 1
  fi
}









install_prerequisites() {
  if [[ "${INSTALL_BASE_DEPS:-1}" -ne 1 ]]; then
    msg "  ⏭️  Dependências base desativadas (INSTALL_BASE_DEPS=0)"
    BASE_DEPS_INSTALLED=1
    return 0
  fi
  if [[ "${BASE_DEPS_INSTALLED:-0}" -eq 1 ]]; then
    return 0
  fi
  BASE_DEPS_INSTALLED=1
  case "$TARGET_OS" in
    linux|wsl2)
      install_linux_base_dependencies
      if is_wsl2; then
        msg "  ℹ️  WSL2 detectado - usando configurações Linux com ajustes para Windows"
      fi
      ;;
    macos)
      install_macos_base_dependencies
      ;;
    windows)
      install_windows_base_dependencies
      ;;
  esac
}

install_selected_shells() {
  case "$TARGET_OS" in
    linux|wsl2)
      install_linux_shells
      ;;
    macos)
      install_macos_shells
      ;;
  esac
}

install_selected_gui_apps() {
  case "$TARGET_OS" in
    linux|wsl2)
      install_linux_selected_apps
      ;;
    macos)
      if [[ "${INSTALL_BREWFILE:-true}" == "true" ]]; then
        generate_dynamic_brewfile
        install_from_brewfile
      else
        msg "  ⏭️  Pulando Brewfile conforme solicitado"
      fi
      install_macos_selected_apps
      ;;
    windows)
      install_windows_selected_apps
      ;;
  esac
}
apply_shared_configs() {
  msg "▶ Copiando configs compartilhadas"

  # Fish config
  if is_truthy "$INSTALL_FISH" && has_cmd fish && [[ ${COPY_FISH_CONFIG:-1} -eq 1 ]]; then
    # Preservar configurações de PATH do config.fish existente
    local preserved_fish_config=""
    preserved_fish_config="$(extract_user_path_config_fish)"

    copy_dir "$CONFIG_SHARED/fish" "$HOME/.config/fish"
    normalize_crlf_to_lf "$HOME/.config/fish/config.fish"

    # Append configurações preservadas ao novo config.fish (sem duplicação)
    if [[ -n "$preserved_fish_config" ]]; then
      msg "  🔄 Verificando configurações de PATH para preservar..."
      append_preserved_config "$HOME/.config/fish/config.fish" "$preserved_fish_config"
    fi
  elif is_truthy "$INSTALL_FISH" && [[ ${COPY_FISH_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Fish config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_FISH" && ! has_cmd fish; then
    msg "  ⚠️ Fish não encontrado, pulando config."
  fi

  # Zsh config
  if is_truthy "$INSTALL_ZSH" && has_cmd zsh && [[ ${COPY_ZSH_CONFIG:-1} -eq 1 ]]; then
    # Preservar configurações de PATH do .zshrc existente
    local preserved_zsh_config=""
    preserved_zsh_config="$(extract_user_path_config_zsh)"

    copy_file "$CONFIG_SHARED/zsh/.zshrc" "$HOME/.zshrc"
    normalize_crlf_to_lf "$HOME/.zshrc"

    # Append configurações preservadas ao novo .zshrc (sem duplicação)
    if [[ -n "$preserved_zsh_config" ]]; then
      msg "  🔄 Verificando configurações de PATH para preservar..."
      append_preserved_config "$HOME/.zshrc" "$preserved_zsh_config"
    fi

    if [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]]; then
      copy_file "$CONFIG_SHARED/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
    else
      msg "  ⚠️ Powerlevel10k não encontrado em ~/.oh-my-zsh, pulando .p10k.zsh."
    fi
  elif is_truthy "$INSTALL_ZSH" && [[ ${COPY_ZSH_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Zsh config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_ZSH" && ! has_cmd zsh; then
    msg "  ⚠️ Zsh não encontrado, pulando .zshrc."
  fi

  # Nushell config
  if is_truthy "$INSTALL_NUSHELL" && has_cmd nu && [[ ${COPY_NUSHELL_CONFIG:-1} -eq 1 ]]; then
    mkdir -p "$HOME/.config/nushell"
    copy_file "$CONFIG_SHARED/nushell/config.nu" "$HOME/.config/nushell/config.nu"
    copy_file "$CONFIG_SHARED/nushell/env.nu" "$HOME/.config/nushell/env.nu"
    mkdir -p "$HOME/.config/nushell/scripts"
  elif is_truthy "$INSTALL_NUSHELL" && [[ ${COPY_NUSHELL_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Nushell config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_NUSHELL" && ! has_cmd nu; then
    msg "  ⚠️ Nushell não encontrado após instalação, pulando config."
  fi

  # Git config
  if has_cmd git && [[ ${COPY_GIT_CONFIG:-1} -eq 1 ]]; then
    local git_base="$CONFIG_SHARED/git/.gitconfig"
    local git_personal="$CONFIG_SHARED/git/.gitconfig-personal"
    local git_work="$CONFIG_SHARED/git/.gitconfig-work"

    if [[ -n "$PRIVATE_SHARED" ]]; then
      [[ -f "$PRIVATE_SHARED/git/.gitconfig" ]] && git_base="$PRIVATE_SHARED/git/.gitconfig"
      [[ -f "$PRIVATE_SHARED/git/.gitconfig-personal" ]] && git_personal="$PRIVATE_SHARED/git/.gitconfig-personal"
      [[ -f "$PRIVATE_SHARED/git/.gitconfig-work" ]] && git_work="$PRIVATE_SHARED/git/.gitconfig-work"
    fi

    copy_file "$git_base" "$HOME/.gitconfig"
    [[ -f "$git_personal" ]] && copy_file "$git_personal" "$HOME/.gitconfig-personal"
    [[ -f "$git_work" ]] && copy_file "$git_work" "$HOME/.gitconfig-work"
  elif [[ ${COPY_GIT_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Git config: usuário optou por não copiar"
  elif ! has_cmd git; then
    msg "  ⚠️ Git não encontrado, pulando .gitconfig."
  fi

  # Mise config
  if has_cmd mise && [[ ${COPY_MISE_CONFIG:-1} -eq 1 ]]; then
    copy_dir "$CONFIG_SHARED/mise" "$HOME/.config/mise"
  elif [[ ${COPY_MISE_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Mise config: usuário optou por não copiar"
  elif ! has_cmd mise; then
    msg "  ⚠️ Mise não encontrado, pulando config."
  fi

  # Neovim config
  if has_cmd nvim && [[ ${COPY_NVIM_CONFIG:-1} -eq 1 ]]; then
    copy_dir "$CONFIG_SHARED/nvim" "$HOME/.config/nvim"
  elif [[ ${COPY_NVIM_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Neovim config: usuário optou por não copiar"
  elif ! has_cmd nvim; then
    msg "  ⚠️ Neovim não encontrado, pulando config."
  fi

  # Tmux config
  if has_cmd tmux && [[ ${COPY_TMUX_CONFIG:-1} -eq 1 ]]; then
    copy_file "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf"
  elif [[ ${COPY_TMUX_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Tmux config: usuário optou por não copiar"
  elif ! has_cmd tmux; then
    msg "  ⚠️ tmux não encontrado, pulando .tmux.conf."
  fi

  # VS Code settings
  if [[ ${COPY_VSCODE_SETTINGS:-1} -eq 1 ]]; then
    copy_vscode_settings
  else
    msg "  ⏭️  VS Code settings: usuário optou por não copiar"
  fi

  # SSH Keys
  if [[ ${COPY_SSH_KEYS:-0} -eq 1 ]]; then
    local ssh_source=""
    if [[ -n "$PRIVATE_SHARED" ]] && [[ -d "$PRIVATE_SHARED/.ssh" ]]; then
      ssh_source="$PRIVATE_SHARED/.ssh"
    elif [[ -d "$CONFIG_SHARED/.ssh" ]]; then
      ssh_source="$CONFIG_SHARED/.ssh"
    fi
    if [[ -n "$ssh_source" ]]; then
      msg "  🔐 Copiando chaves SSH..."
      copy_dir "$ssh_source" "$HOME/.ssh"
      set_ssh_permissions
      msg "  ✓ Chaves SSH copiadas com permissões corretas (700/600)"
    fi
  else
    msg "  ⏭️  SSH Keys: usuário optou por não copiar (padrão por segurança)"
  fi
}



copy_vscode_settings() {
  # COPY_VSCODE_SETTINGS já foi verificado pelo chamador (apply_shared_configs)
  local settings_file="$CONFIG_SHARED/vscode/settings.json"
  [[ -f "$settings_file" ]] || return

  local dest=""
  case "$TARGET_OS" in
    macos)
      dest="$HOME/Library/Application Support/Code/User/settings.json"
      if [[ -d "$(dirname "$dest")" ]] || has_cmd code; then
        copy_file "$settings_file" "$dest"
      else
        msg "  ⚠️ VS Code não encontrado em macOS, pulando settings."
      fi
      ;;
    linux)
      dest="$HOME/.config/Code/User/settings.json"
      if [[ -d "$(dirname "$dest")" ]] || has_cmd code; then
        copy_file "$settings_file" "$dest"
      else
        msg "  ⚠️ VS Code não encontrado em Linux, pulando settings."
      fi
      ;;
    windows)
      local base="${APPDATA:-}"
      if [[ -z "$base" ]]; then
        base="$HOME/AppData/Roaming"
      fi
      if [[ -n "$base" ]]; then
        copy_file "$settings_file" "$base/Code/User/settings.json"
        if [[ -d "$base/Code - Insiders/User" ]]; then
          copy_file "$settings_file" "$base/Code - Insiders/User/settings.json"
        fi
      else
        msg "  ⚠️ APPDATA não definido, não foi possível instalar settings do VS Code."
      fi
      ;;
  esac
}

apply_linux_configs() {
  local source_dir="$CONFIG_LINUX"
  [[ -d "$source_dir" ]] || source_dir="$CONFIG_UNIX_LEGACY"
  [[ -d "$source_dir" ]] || return
  msg "▶ Copiando configs Linux"
  if [[ ${COPY_TERMINAL_CONFIG:-1} -eq 1 ]]; then
    copy_dir "$source_dir/ghostty" "$HOME/.config/ghostty"
  else
    msg "  ⏭️  Terminal config: usuário optou por não copiar"
  fi
}

apply_macos_configs() {
  local source_dir="$CONFIG_MACOS"
  [[ -d "$source_dir" ]] || source_dir="$CONFIG_UNIX_LEGACY"
  [[ -d "$source_dir" ]] || return
  msg "▶ Copiando configs macOS"

  # Ghostty terminal
  if [[ ${COPY_TERMINAL_CONFIG:-1} -eq 1 ]]; then
    copy_dir "$source_dir/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty"
  else
    msg "  ⏭️  Terminal config (Ghostty): usuário optou por não copiar"
  fi

  # Rectangle window manager
  if [[ -f "$source_dir/rectangle/com.knollsoft.Rectangle.plist" ]]; then
    copy_file "$source_dir/rectangle/com.knollsoft.Rectangle.plist" "$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
    msg "  ✅ Rectangle configurado (reinicie o app para aplicar)"
  fi

  # Stats system monitor
  if [[ -f "$source_dir/stats/com.exelban.Stats.plist" ]]; then
    copy_file "$source_dir/stats/com.exelban.Stats.plist" "$HOME/Library/Preferences/com.exelban.Stats.plist"
    msg "  ✅ Stats configurado (reinicie o app para aplicar)"
  fi

  # KeyCastr (nota: configuração manual necessária para permissões)
  if [[ -f "$source_dir/keycastr/keycastr.json" ]]; then
    msg "  📋 KeyCastr: configuração disponível em $source_dir/keycastr/keycastr.json"
    msg "     Lembre-se de dar permissão de Acessibilidade nas Preferências do Sistema"
  fi
}

apply_windows_configs() {
  [[ -d "$CONFIG_WINDOWS" ]] || return
  msg "▶ Copiando configs Windows"
  if [[ ${COPY_TERMINAL_CONFIG:-1} -eq 1 ]]; then
    copy_windows_terminal_settings
    copy_windows_powershell_profiles
  else
    msg "  ⏭️  Terminal config: usuário optou por não copiar"
  fi
}

copy_windows_terminal_settings() {
  local wt_settings="$CONFIG_WINDOWS/windows-terminal-settings.json"
  [[ -f "$wt_settings" ]] || return 0
  local base="${LOCALAPPDATA:-$HOME/AppData/Local}"

  local stable="$base/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  local preview="$base/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
  local unpackaged="$base/Microsoft/Windows Terminal/settings.json"
  copy_file "$wt_settings" "$stable"
  if [[ -d "$(dirname "$preview")" ]]; then
    copy_file "$wt_settings" "$preview"
  fi
  if [[ -d "$(dirname "$unpackaged")" ]]; then
    copy_file "$wt_settings" "$unpackaged"
  fi
}

copy_windows_powershell_profiles() {
  local profile_src="$CONFIG_WINDOWS/powershell/profile.ps1"
  [[ -f "$profile_src" ]] || return

  local user_home="${USERPROFILE:-$HOME}"
  local docs="$user_home/Documents"
  if [[ ! -d "$docs" ]] && has_cmd powershell.exe; then
    local docs_win
    docs_win="$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("MyDocuments")' 2>/dev/null | tr -d '\r' || true)"
    if [[ -n "$docs_win" ]]; then
      if has_cmd wslpath; then
        docs="$(wslpath -u "$docs_win" 2>/dev/null || echo "$docs")"
      elif has_cmd cygpath; then
        docs="$(cygpath -u "$docs_win" 2>/dev/null || echo "$docs")"
      fi
    fi
  fi

  copy_file "$profile_src" "$docs/PowerShell/Microsoft.PowerShell_profile.ps1"
  copy_file "$profile_src" "$docs/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
}


# ════════════════════════════════════════════════════════════════
# VS Code Extensions - Export/Import
# ════════════════════════════════════════════════════════════════

export_vscode_extensions() {
  if ! has_cmd code; then
    return
  fi

  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"
  msg "  📦 Exportando extensões VS Code..."

  mkdir -p "$(dirname "$extensions_file")"
  code --list-extensions > "$extensions_file" 2>/dev/null || warn "Falha ao exportar extensões VS Code"
}

install_vscode_extensions() {
  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"

  # Instalar extensões se COPY_VSCODE_SETTINGS estiver habilitado
  if [[ ${COPY_VSCODE_SETTINGS:-1} -ne 1 ]]; then
    msg "  ⏭️  VS Code extensions: usuário optou por não copiar/instalar"
    return
  fi

  if ! has_cmd code; then
    warn "VS Code não encontrado; pulando instalação de extensões."
    return
  fi

  if [[ ! -f "$extensions_file" ]]; then
    return
  fi

  msg "▶ Instalando extensões VS Code"

  local installed_count=0

  local installed_extensions
  installed_extensions="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

  while IFS= read -r extension; do
    [[ -z "$extension" ]] && continue
    [[ "$extension" =~ ^# ]] && continue

    local ext_lower
    ext_lower="$(echo "$extension" | tr '[:upper:]' '[:lower:]')"

    if echo "$installed_extensions" | grep -qi "^${ext_lower}$"; then
      continue
    fi

    msg "  🔌 Instalando: $extension"
    if ! code --install-extension "$extension" --force >/dev/null 2>&1; then
      warn "Falha ao instalar extensão: $extension"
    else
      installed_count=$((installed_count + 1))
    fi
  done < "$extensions_file"

  if [[ $installed_count -gt 0 ]]; then
    INSTALLED_MISC+=("vscode extensions: $installed_count")
  fi
}

# ════════════════════════════════════════════════════════════════
# Brewfile (macOS) - Export/Import
# ════════════════════════════════════════════════════════════════

export_brewfile() {
  if [[ "$TARGET_OS" != "macos" ]] || ! has_cmd brew; then
    return
  fi

  local brewfile="$CONFIG_MACOS/Brewfile"
  msg "  🍺 Exportando Brewfile..."

  mkdir -p "$(dirname "$brewfile")"
  brew bundle dump --describe --force --file="$brewfile" 2>/dev/null || warn "Falha ao exportar Brewfile"
}


# ════════════════════════════════════════════════════════════════
# Export Configs
# ════════════════════════════════════════════════════════════════

export_configs() {
  msg ""
  msg "╔══════════════════════════════════════╗"
  msg "║   Exportando configs do sistema      ║"
  msg "╚══════════════════════════════════════╝"
  msg "Sistema -> Repositório: $SCRIPT_DIR"

  # Exportar configs compartilhadas
  msg "▶ Exportando configs compartilhadas"

  if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    export_file "$HOME/.config/fish/config.fish" "$CONFIG_SHARED/fish/config.fish"
    normalize_crlf_to_lf "$CONFIG_SHARED/fish/config.fish"
  fi

  if [[ -f "$HOME/.zshrc" ]]; then
    export_file "$HOME/.zshrc" "$CONFIG_SHARED/zsh/.zshrc"
    normalize_crlf_to_lf "$CONFIG_SHARED/zsh/.zshrc"
    if [[ -f "$HOME/.p10k.zsh" ]]; then
      export_file "$HOME/.p10k.zsh" "$CONFIG_SHARED/zsh/.p10k.zsh"
      normalize_crlf_to_lf "$CONFIG_SHARED/zsh/.p10k.zsh"
    fi
  fi

  if [[ -f "$HOME/.config/starship.toml" ]]; then
    export_file "$HOME/.config/starship.toml" "$CONFIG_SHARED/starship.toml"
  fi

  local export_git_dir="$CONFIG_SHARED/git"
  local export_ssh_dir="$CONFIG_SHARED/.ssh"
  if [[ -n "$PRIVATE_SHARED" ]]; then
    export_git_dir="$PRIVATE_SHARED/git"
    export_ssh_dir="$PRIVATE_SHARED/.ssh"
  fi

  if [[ -f "$HOME/.gitconfig" ]]; then
    export_file "$HOME/.gitconfig" "$CONFIG_SHARED/git/.gitconfig"
    [[ -f "$HOME/.gitconfig-personal" ]] && export_file "$HOME/.gitconfig-personal" "$export_git_dir/.gitconfig-personal"
    [[ -f "$HOME/.gitconfig-work" ]] && export_file "$HOME/.gitconfig-work" "$export_git_dir/.gitconfig-work"
  fi

  if [[ -d "$HOME/.config/nvim" ]]; then
    export_dir "$HOME/.config/nvim" "$CONFIG_SHARED/nvim"
  fi

  if [[ -f "$HOME/.tmux.conf" ]]; then
    export_file "$HOME/.tmux.conf" "$CONFIG_SHARED/tmux/.tmux.conf"
  fi

  if [[ -d "$HOME/.ssh" ]]; then
    export_dir "$HOME/.ssh" "$export_ssh_dir"
  fi

  # Exportar VS Code settings e extensões
  export_vscode_settings
  export_vscode_extensions

  # Exportar Brewfile (macOS)
  export_brewfile

  # Exportar configs específicas do OS
  case "$TARGET_OS" in
    linux)
      msg "▶ Exportando configs Linux"
      if [[ -d "$HOME/.config/ghostty" ]]; then
        export_dir "$HOME/.config/ghostty" "$CONFIG_LINUX/ghostty"
      fi
      ;;
    macos)
      msg "▶ Exportando configs macOS"
      if [[ -d "$HOME/Library/Application Support/com.mitchellh.ghostty" ]]; then
        export_dir "$HOME/Library/Application Support/com.mitchellh.ghostty" "$CONFIG_MACOS/ghostty"
      fi
      ;;
    windows)
      msg "▶ Exportando configs Windows"
      export_windows_configs_back
      ;;
  esac

  msg ""
  msg "✅ Configs exportadas com sucesso para: $SCRIPT_DIR"
  msg "💡 Execute 'git status' para ver as mudanças"
}

export_vscode_settings() {
  local src=""
  case "$TARGET_OS" in
    macos)
      src="$HOME/Library/Application Support/Code/User/settings.json"
      ;;
    linux)
      src="$HOME/.config/Code/User/settings.json"
      ;;
    windows)
      local base="${APPDATA:-$HOME/AppData/Roaming}"
      src="$base/Code/User/settings.json"
      ;;
  esac

  if [[ -f "$src" ]]; then
    export_file "$src" "$CONFIG_SHARED/vscode/settings.json"
  fi
}

export_windows_configs_back() {
  local base="${LOCALAPPDATA:-$HOME/AppData/Local}"

  # Windows Terminal settings
  local wt_stable="$base/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -f "$wt_stable" ]]; then
    export_file "$wt_stable" "$CONFIG_WINDOWS/windows-terminal-settings.json"
  fi

  # PowerShell profile
  local ps_profile="${USERPROFILE:-$HOME}/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
  if [[ -f "$ps_profile" ]]; then
    export_file "$ps_profile" "$CONFIG_WINDOWS/powershell/profile.ps1"
  fi
}

show_usage() {
  cat <<EOF
╔══════════════════════════════════════════════════════════╗
║   Dotfiles Manager - Instalação e Sincronização         ║
╚══════════════════════════════════════════════════════════╝

Uso: bash config/install.sh [COMANDO] [OPÇÕES]

COMANDOS:
  (nenhum)    Instala configs do repositório -> sistema (padrão)
  export      Exporta configs do sistema -> repositório
  sync        Sincroniza (exporta + instala)
  help        Mostra esta ajuda

EXEMPLOS:
  bash config/install.sh                  # Primeira instalação
  bash config/install.sh export           # Salvar mudanças atuais
  bash config/install.sh sync             # Sincronizar bidirecional

NOTAS:
  • Backups automáticos são criados em ~/.bkp-*
  • Seleção interativa de apps GUI (evita instalar tudo automaticamente)
  • CLI Tools modernas são opcionais e selecionadas no menu
  • Oh My Zsh e plugins são configurados automaticamente
  • Fontes Nerd Fonts são instaladas no local correto do sistema

EOF
}

main() {
  # Mostrar ajuda
  if [[ "$MODE" == "help" || "$MODE" == "--help" || "$MODE" == "-h" ]]; then
    show_usage
    exit 0
  fi

  # Validar que a pasta shared existe
  if [[ ! -d "$CONFIG_SHARED" ]]; then
    echo "❌ Pasta shared/ não encontrada em $CONFIG_SHARED" >&2
    exit 1
  fi

  TARGET_OS="$(detect_os)"

  # Modo EXPORT - Sistema -> Repositório
  if [[ "$MODE" == "export" ]]; then
    export_configs
    exit 0
  fi

  # Modo SYNC - Exporta e depois instala
  if [[ "$MODE" == "sync" ]]; then
    export_configs
    msg ""
    msg "╔══════════════════════════════════════╗"
    msg "║   Agora instalando configs...        ║"
    msg "╚══════════════════════════════════════╝"
    sleep 1
  fi

  # Mostrar banner de boas-vindas (apenas no modo install/sync)
  if [[ "$MODE" == "install" || "$MODE" == "sync" ]]; then
    show_banner
    pause_before_next_section "Pressione Enter para começar a configuração..." "true"
  fi

  # Modo INSTALL (padrão) - Repositório -> Sistema
  clear_screen

  # ══════════════════════════════════════════════════════════════
  # ETAPA 1: Seleções Essenciais
  # ══════════════════════════════════════════════════════════════

  # Tela de dependências base (informativa - apenas Enter)
  ask_base_dependencies
  pause_before_next_section
  install_prerequisites

  # Shells (obrigatório - Zsh/Fish/Ambos)
  ask_shells

  # Temas (baseado nos shells) + Plugins/Presets (SEM pause entre eles)
  ask_themes

  # Plugins e Presets
  [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && ask_oh_my_zsh_plugins
  [[ $INSTALL_STARSHIP -eq 1 ]] && ask_starship_preset
  [[ $INSTALL_OH_MY_POSH -eq 1 ]] && ask_oh_my_posh_theme
  [[ $INSTALL_FISH -eq 1 ]] && ask_fish_plugins

  # Nerd Fonts (essenciais para temas funcionarem corretamente)
  ask_nerd_fonts

  # ══════════════════════════════════════════════════════════════
  # ETAPA 2: Apps e Ferramentas
  # ══════════════════════════════════════════════════════════════

  # Terminais
  ask_terminals

  # CLI Tools (ferramentas modernas de linha de comando)
  ask_cli_tools

  # IA Tools
  ask_ia_tools

  # GUI Apps
  ask_gui_apps

  # Runtimes (Node/Python/PHP/etc via mise)
  ask_runtimes

  # Git Configuration
  ask_git_configuration

  # ══════════════════════════════════════════════════════════════
  # Confirmação Final
  # ══════════════════════════════════════════════════════════════
  review_selections

  # Limpar tela antes de iniciar instalação
  clear_screen

  # Instalar dependências base (sempre necessário)
  install_prerequisites

  # Instalar shells selecionados
  install_selected_shells

  # Instalar CLI Tools PRIMEIRO (antes de tudo)
  install_selected_cli_tools

  # Instalar apps GUI selecionados
  install_selected_gui_apps

  # Instalar IA Tools selecionadas
  install_selected_ia_tools

  # Instalar extensões VS Code após a instalação do editor
  install_vscode_extensions

  apply_shared_configs
  install_git_configuration

  case "$TARGET_OS" in
    linux|wsl2) apply_linux_configs ;;
    macos) apply_macos_configs ;;
    windows) apply_windows_configs ;;
  esac

  # Instalar runtimes selecionados após pré-requisitos + configs
  install_selected_runtimes

  # Instalar Editor/IDE (Neovim + tmux)
  install_selected_editors

  # Instalar Nerd Fonts selecionadas
  install_nerd_fonts

  # Instalar temas selecionados
  install_selected_themes

  # Limpar tela antes de mostrar resumo final
  clear_screen

  print_post_install_report

  print_final_summary
}

main "$@"
