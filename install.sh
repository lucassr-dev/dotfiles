#!/usr/bin/env bash
set -uo pipefail
# shellcheck disable=SC2034,SC2329,SC1091

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -lt 3 ]]; }; then
  echo "bash 4.3+ necessario. Versao atual: ${BASH_VERSION}" >&2
  if [[ "$OSTYPE" == darwin* ]]; then
    echo "macOS: instale via 'brew install bash' e use '/opt/homebrew/bin/bash install.sh'" >&2
  fi
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SHARED="$SCRIPT_DIR/shared"
CONFIG_LINUX="$SCRIPT_DIR/linux"
CONFIG_MACOS="$SCRIPT_DIR/macos"
CONFIG_WINDOWS="$SCRIPT_DIR/windows"
DATA_APPS="$SCRIPT_DIR/data/apps.sh"
DATA_RUNTIMES="$SCRIPT_DIR/data/runtimes.sh"
# lib/core.sh define msg/warn/is_truthy/has_cmd/record_failure/run_with_sudo/
# run_mutating/_ensure_backup_dir (+ BACKUP_DIR). Precisa ser o primeiro
# source: o bloco de dados de apps/runtimes mais abaixo (~linha 940) ja chama
# warn() no nivel superior do script, antes de qualquer outro source.
source "$SCRIPT_DIR/lib/core.sh"
TARGET_OS=""
ARCH=""
LINUX_PKG_MANAGER=""
LINUX_PKG_UPDATED=0
MODE="install"
FAIL_FAST="${FAIL_FAST:-0}"
DRY_RUN="${DRY_RUN:-0}"
SCRIPT_VERSION="1.0.0"
VERBOSE="${VERBOSE:-0}"
CONFIRM_OVERWRITE="${CONFIRM_OVERWRITE:-0}"
REMOTE_SCRIPT_STRICT="${REMOTE_SCRIPT_STRICT:-1}"
REMOTE_SCRIPT_REQUIRE_CHECKSUM="${REMOTE_SCRIPT_REQUIRE_CHECKSUM:-0}"
REMOTE_SCRIPT_ALLOWLIST="${REMOTE_SCRIPT_ALLOWLIST:-astral.sh,mise.run,sh.rustup.rs,raw.githubusercontent.com,starship.rs,setup.atuin.sh,get.docker.com,ohmyposh.dev,claude.ai}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"
INSTALL_FISH="${INSTALL_FISH:-1}"
INSTALL_NUSHELL="${INSTALL_NUSHELL:-0}"
INSTALL_BASE_DEPS=1
BASE_DEPS_INSTALLED=0

COPY_ZSH_CONFIG=0
COPY_FISH_CONFIG=0
COPY_NUSHELL_CONFIG=0
COPY_GIT_CONFIG=0
COPY_NVIM_CONFIG=0
COPY_TMUX_CONFIG=0
COPY_TERMINAL_CONFIG=0
COPY_MISE_CONFIG=0
COPY_STARSHIP_CONFIG=0
COPY_SSH_KEYS=0
COPY_VSCODE_SETTINGS=0
COPY_LAZYGIT_CONFIG=0
COPY_YAZI_CONFIG=0
COPY_BTOP_CONFIG=0
COPY_BAT_CONFIG=0
COPY_KITTY_CONFIG=0
COPY_ALACRITTY_CONFIG=0
COPY_WEZTERM_CONFIG=0
COPY_RIPGREP_CONFIG=0
COPY_NPM_CONFIG=0
COPY_PNPM_CONFIG=0
COPY_YARN_CONFIG=0
COPY_PIP_CONFIG=0
COPY_CARGO_CONFIG=0
COPY_ZED_CONFIG=0
COPY_HELIX_CONFIG=0
COPY_AIDER_CONFIG=0
COPY_CLAUDE_CONFIG=0
COPY_DOCKER_CONFIG=0
COPY_DIRENV_CONFIG=0

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
POST_INSTALL_REPORT_SHOWN=0

# ═══════════════════════════════════════════════════════════
# Trap para cleanup em caso de interrupção (Ctrl+C)
# ═══════════════════════════════════════════════════════════
cleanup_on_exit() {
  local exit_code=$?
  rm -f /tmp/dotfiles-install-*.tmp 2>/dev/null || true
  if [[ $exit_code -ne 0 ]] && [[ -f "$HOME/.dotfiles-checkpoint" ]]; then
    echo ""
    echo "⚠️  Instalação interrompida. Execute novamente para retomar."
  fi
  exit $exit_code
}
trap cleanup_on_exit EXIT
trap 'echo ""; echo "⚠️  Interrupção detectada (Ctrl+C)"; exit 130' INT TERM

source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/checkpoint.sh"

show_version() {
  echo "dotfiles-installer v${SCRIPT_VERSION}"
}

show_usage() {
  local c="" b="" r=""
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    c="${UI_SKY:-\033[0;36m}" b="${UI_BOLD:-\033[1m}" r="${UI_RESET:-\033[0m}"
  fi
  echo -e "${b}dotfiles-installer${r} v${SCRIPT_VERSION}"
  echo ""
  echo -e "${b}Uso:${r} bash install.sh [COMANDO] [OPCOES]"
  echo ""
  echo -e "${b}Comandos:${r}"
  echo -e "  ${c}install${r}     Instalar dotfiles no sistema (padrao)"
  echo -e "  ${c}export${r}      Exportar configs do sistema para o repo"
  echo -e "  ${c}sync${r}        Sincronizacao bidirecional"
  echo ""
  echo -e "${b}Opcoes:${r}"
  echo -e "  ${c}-h${r}, ${c}--help${r}          Mostrar esta ajuda"
  echo -e "  ${c}-v${r}, ${c}--version${r}       Mostrar versao"
  echo -e "  ${c}-n${r}, ${c}--dry-run${r}       Simular sem alterar o sistema"
  echo -e "  ${c}--verbose${r}           Saida detalhada"
  echo -e "  ${c}--confirm-overwrite${r} Perguntar antes de sobrescrever configs"
  echo -e "  ${c}--no-color${r}          Desativar cores (equivale a NO_COLOR=1)"
  echo ""
  echo -e "${b}Variaveis de ambiente:${r}"
  echo -e "  DRY_RUN=1                    Mesmo que --dry-run"
  echo -e "  CONFIRM_OVERWRITE=1          Mesmo que --confirm-overwrite"
  echo -e "  NO_COLOR=1                   Mesmo que --no-color"
  echo -e "  FORCE_UI_MODE=bash           Forcar modo de UI (fzf/gum/bash)"
  echo -e "  REMOTE_SCRIPT_STRICT=0       Permitir hosts fora da allowlist"
  echo -e "  REMOTE_SCRIPT_REQUIRE_CHECKSUM=1  Exigir SHA256 para scripts remotos"
  echo -e "  REMOTE_SCRIPT_ALLOWLIST=...  Lista CSV de hosts confiaveis"
  echo ""
  echo -e "${b}Exemplos:${r}"
  echo -e "  bash install.sh                    Instalacao interativa"
  echo -e "  bash install.sh --dry-run          Simular instalacao"
  echo -e "  bash install.sh export             Exportar configs atuais"
  echo -e "  bash install.sh sync --verbose     Sync com saida detalhada"
}

for arg in "$@"; do
  case "$arg" in
    install|export|sync) MODE="$arg" ;;
    -h|--help) show_usage; exit 0 ;;
    -v|--version) show_version; exit 0 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    --confirm-overwrite) CONFIRM_OVERWRITE=1 ;;
    --verbose) VERBOSE=1 ;;
    --no-color) export NO_COLOR=1 ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      echo "" >&2
      show_usage >&2
      exit 1
      ;;
  esac
done

snap_install_or_refresh() {
  local pkg="$1"
  local friendly="$2"
  local level="${3:-optional}"
  shift 3 || true
  local install_args=("$@")

  has_cmd snap || return 0

  if has_snap_pkg "$pkg"; then
    msg "  🔄 Atualizando $friendly via snap..."
    if run_with_sudo snap refresh "$pkg"; then
      INSTALLED_MISC+=("$friendly: snap refresh")
    else
      record_failure "$level" "Falha ao atualizar via snap: $friendly ($pkg)"
    fi
    return 0
  fi

  msg "  📦 Instalando $friendly via snap..."
  if run_with_sudo snap install "${install_args[@]}" "$pkg"; then
    INSTALLED_MISC+=("$friendly: snap install")
  else
    record_failure "$level" "Falha ao instalar via snap: $friendly ($pkg)"
  fi
}

flatpak_install_or_update() {
  local ref="$1"
  local friendly="$2"
  local level="${3:-optional}"

  has_cmd flatpak || return 0
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

  if flatpak info "$ref" >/dev/null 2>&1; then
    msg "  🔄 Atualizando $friendly via flatpak..."
    if flatpak update -y "$ref"; then
      INSTALLED_MISC+=("$friendly: flatpak update")
    else
      record_failure "$level" "Falha ao atualizar via flatpak: $friendly ($ref)"
    fi
    return 0
  fi

  msg "  📦 Instalando $friendly via flatpak..."
  if flatpak install -y flathub "$ref"; then
    INSTALLED_MISC+=("$friendly: flatpak install")
  else
    record_failure "$level" "Falha ao instalar via flatpak: $friendly ($ref)"
  fi
}

has_snap_pkg() {
  has_cmd snap || return 1
  snap list "$1" >/dev/null 2>&1
}

has_flatpak_ref() {
  has_cmd flatpak || return 1
  flatpak info "$1" >/dev/null 2>&1
}

_source_field_value() {
  local sources="$1"
  local field="$2"
  local token
  local -a _src_tokens=()
  IFS=',' read -ra _src_tokens <<< "$sources"
  for token in "${_src_tokens[@]}"; do
    if [[ "$token" == "$field:"* ]]; then
      printf '%s\n' "${token#"$field:"}"
      return 0
    fi
  done
  return 1
}

# Verifica se app está instalado em QUALQUER fonte (cmd, dpkg/rpm, snap, flatpak, brew, winget, choco, scoop)
is_app_installed() {
  local app="$1"
  local cmd_check="${2:-$app}"

  has_cmd "$cmd_check" && return 0

  # Lazy-load catálogo se necessário
  declare -F _ensure_catalog_loaded >/dev/null 2>&1 && _ensure_catalog_loaded

  local sources="${APP_SOURCES[$app]:-}"
  [[ -z "$sources" ]] && return 1

  local apt_pkg snap_pkg flatpak_ref brew_pkg winget_pkg choco_pkg scoop_pkg
  apt_pkg=$(_source_field_value "$sources" "apt" || true)
  snap_pkg=$(_source_field_value "$sources" "snap" || true)
  flatpak_ref=$(_source_field_value "$sources" "flatpak" || true)
  brew_pkg=$(_source_field_value "$sources" "brew" || true)
  winget_pkg=$(_source_field_value "$sources" "winget" || true)
  choco_pkg=$(_source_field_value "$sources" "choco" || true)
  scoop_pkg=$(_source_field_value "$sources" "scoop" || true)

  # Snap entries podem conter argumentos (ex.: "code --classic")
  [[ -n "$snap_pkg" ]] && snap_pkg="${snap_pkg%% *}"

  # Linux: dpkg, rpm, snap, flatpak
  if [[ "${TARGET_OS:-}" == "linux" ]] || [[ "${TARGET_OS:-}" == "wsl2" ]]; then
    [[ -n "$apt_pkg" ]] && has_cmd dpkg && dpkg -l "$apt_pkg" 2>/dev/null | grep -q '^ii' && return 0
    [[ -n "$apt_pkg" ]] && has_cmd rpm && rpm -q "$apt_pkg" >/dev/null 2>&1 && return 0
  fi
  [[ -n "$snap_pkg" ]] && has_snap_pkg "$snap_pkg" && return 0
  [[ -n "$flatpak_ref" ]] && has_flatpak_ref "$flatpak_ref" && return 0

  # macOS: brew (cask + formula)
  if [[ -n "$brew_pkg" ]] && has_cmd brew; then
    brew list --cask "$brew_pkg" &>/dev/null && return 0
    brew list "$brew_pkg" &>/dev/null && return 0
  fi

  # Windows: winget, choco, scoop
  if [[ -n "$winget_pkg" ]] && has_cmd winget; then
    winget list --id "$winget_pkg" -e --source winget 2>/dev/null | tr -d '\r' | grep -Fq "$winget_pkg" && return 0
  fi
  if [[ -n "$choco_pkg" ]] && has_cmd choco; then
    choco list --local-only --exact "$choco_pkg" --limit-output 2>/dev/null | grep -Fq "${choco_pkg}|" && return 0
  fi
  if [[ -n "$scoop_pkg" ]] && has_cmd scoop; then
    scoop list "$scoop_pkg" 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$scoop_pkg" && return 0
  fi

  return 1
}

source "$SCRIPT_DIR/lib/fileops.sh"

# ═══════════════════════════════════════════════════════════
# Preservação de PATH e configurações existentes
# ═══════════════════════════════════════════════════════════

tool_config_exists() {
  local file="$1"
  local line="$2"

  [[ ! -f "$file" ]] && return 1
  case "$line" in
    *"NVM_DIR"*|*"nvm.sh"*)
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
    *"JAVA_HOME"*)
      grep -q "JAVA_HOME" "$file" 2>/dev/null && return 0
      ;;
    *"GOPATH"*|*"GOROOT"*)
      grep -q "GOPATH\|GOROOT" "$file" 2>/dev/null && return 0
      ;;
    *"/go/bin"*)
      grep -q "/go/bin" "$file" 2>/dev/null && return 0
      ;;
    *".yarn/bin"*|*".config/yarn"*)
      grep -q "\.yarn/bin\|\.config/yarn" "$file" 2>/dev/null && return 0
      ;;
    *"PNPM_HOME"*|*".local/share/pnpm"*)
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

  return 1
}
append_preserved_config() {
  local file="$1"
  local preserved_config="$2"
  local added_count=0
  local skipped_count=0

  [[ -z "$preserved_config" ]] && return 0
  [[ ! -f "$file" ]] && return 1

  local lines_to_add=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^#.*═ ]] && continue
    [[ "$line" =~ ^#.*[Pp]reservad ]] && continue

    if tool_config_exists "$file" "$line"; then
      ((skipped_count++))
    else
      lines_to_add+=("$line")
      ((added_count++))
    fi
  done <<< "$preserved_config"

  if [[ ${#lines_to_add[@]} -gt 0 ]]; then
    append_block_to_file "$file" \
      "" \
      "# ═══════════════════════════════════════════════════════════" \
      "# Configurações preservadas do arquivo anterior" \
      "# (NVM, Android, SDKMAN, pyenv, Go, yarn, pnpm, etc.)" \
      "# ═══════════════════════════════════════════════════════════" \
      "${lines_to_add[@]}"
    msg "    ✅ $added_count configurações preservadas"
    [[ $skipped_count -gt 0 ]] && msg "    ℹ️  $skipped_count já existiam (ignoradas)"
  else
    msg "    ℹ️  Todas as configurações já existem no novo arquivo"
  fi
}

extract_user_path_config_zsh() {
  local zshrc="$HOME/.zshrc"
  [[ -f "$zshrc" ]] || return

  local preserved_lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    case "$line" in
      *"NVM_DIR"*|*"nvm.sh"*|*"nvm bash_completion"*)
        preserved_lines+=("$line")
        ;;
      *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*|*"/Android/Sdk"*|*"/android"*"/tools"*|*"/platform-tools"*)
        preserved_lines+=("$line")
        ;;
      *"SDKMAN_DIR"*|*"sdkman-init.sh"*|*".sdkman"*)
        preserved_lines+=("$line")
        ;;
      *"PYENV_ROOT"*|*"pyenv init"*)
        preserved_lines+=("$line")
        ;;
      *"RBENV_ROOT"*|*"rbenv init"*)
        preserved_lines+=("$line")
        ;;
      *"JAVA_HOME"*|*"JDK_HOME"*)
        preserved_lines+=("$line")
        ;;
      *"GOPATH"*|*"GOROOT"*|*"/go/bin"*)
        preserved_lines+=("$line")
        ;;
      *".yarn/bin"*|*".config/yarn"*|*"yarn global"*)
        preserved_lines+=("$line")
        ;;
      *"PNPM_HOME"*|*".local/share/pnpm"*)
        preserved_lines+=("$line")
        ;;
      *"BUN_INSTALL"*|*".bun/bin"*)
        preserved_lines+=("$line")
        ;;
      *"DENO_INSTALL"*|*".deno/bin"*)
        preserved_lines+=("$line")
        ;;
      *"FLUTTER_HOME"*|*"flutter/bin"*)
        preserved_lines+=("$line")
        ;;
      *"DOTNET_ROOT"*|*".dotnet"*)
        preserved_lines+=("$line")
        ;;
      *".cargo/env"*|*"CARGO_HOME"*|*"RUSTUP_HOME"*)
        ;;
      *"/home/linuxbrew"*|*"HOMEBREW_PREFIX"*)
        preserved_lines+=("$line")
        ;;
      *"/snap/bin"*)
        preserved_lines+=("$line")
        ;;
    esac
  done < "$zshrc"

  if [[ ${#preserved_lines[@]} -gt 0 ]]; then
    printf '%s\n' ""
    printf '%s\n' "# ═══════════════════════════════════════════════════════════"
    printf '%s\n' "# Configurações preservadas do .zshrc anterior"
    printf '%s\n' "# (NVM, Android, SDKMAN, pyenv, Go, yarn, pnpm, etc.)"
    printf '%s\n' "# ═══════════════════════════════════════════════════════════"
    printf '%s\n' "${preserved_lines[@]}"
  fi
}

extract_user_path_config_fish() {
  local fishrc="$HOME/.config/fish/config.fish"
  [[ -f "$fishrc" ]] || return

  local preserved_lines=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    case "$line" in
      *"NVM_DIR"*|*"nvm.fish"*|*"bass"*"nvm"*)
        preserved_lines+=("$line")
        ;;
      *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*|*"/Android/Sdk"*|*"/android"*"/tools"*|*"/platform-tools"*)
        preserved_lines+=("$line")
        ;;
      *"SDKMAN_DIR"*|*".sdkman"*)
        preserved_lines+=("$line")
        ;;
      *"PYENV_ROOT"*|*"pyenv init"*)
        preserved_lines+=("$line")
        ;;
      *"RBENV_ROOT"*|*"rbenv init"*)
        preserved_lines+=("$line")
        ;;
      *"JAVA_HOME"*|*"JDK_HOME"*)
        preserved_lines+=("$line")
        ;;
      *"GOPATH"*|*"GOROOT"*|*"/go/bin"*)
        preserved_lines+=("$line")
        ;;
      *".yarn/bin"*|*".config/yarn"*|*"yarn global"*)
        preserved_lines+=("$line")
        ;;
      *"PNPM_HOME"*|*".local/share/pnpm"*)
        preserved_lines+=("$line")
        ;;
      *"BUN_INSTALL"*|*".bun/bin"*)
        preserved_lines+=("$line")
        ;;
      *"DENO_INSTALL"*|*".deno/bin"*)
        preserved_lines+=("$line")
        ;;
      *"FLUTTER_HOME"*|*"flutter/bin"*)
        preserved_lines+=("$line")
        ;;
      *"DOTNET_ROOT"*|*".dotnet"*)
        preserved_lines+=("$line")
        ;;
      *"/home/linuxbrew"*|*"HOMEBREW_PREFIX"*)
        preserved_lines+=("$line")
        ;;
      *"/snap/bin"*)
        preserved_lines+=("$line")
        ;;
    esac
  done < "$fishrc"

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

# shellcheck disable=SC1090
if [[ -f "$DATA_APPS" ]]; then
  source "$DATA_APPS"
else
  warn "Arquivo de dados de apps não encontrado: $DATA_APPS"
fi
# shellcheck disable=SC1090
if [[ -f "$DATA_RUNTIMES" ]]; then
  source "$DATA_RUNTIMES"
else
  warn "Arquivo de dados de runtimes não encontrado: $DATA_RUNTIMES"
fi

[[ -f "$SCRIPT_DIR/lib/colors.sh" ]] && source "$SCRIPT_DIR/lib/colors.sh"
[[ -f "$SCRIPT_DIR/lib/utils.sh" ]] && source "$SCRIPT_DIR/lib/utils.sh"
[[ -f "$SCRIPT_DIR/lib/components.sh" ]] && source "$SCRIPT_DIR/lib/components.sh"
[[ -f "$SCRIPT_DIR/lib/ui.sh" ]] && source "$SCRIPT_DIR/lib/ui.sh"
detect_terminal_capabilities
detect_ui_mode
[[ -f "$SCRIPT_DIR/lib/banner.sh" ]] && source "$SCRIPT_DIR/lib/banner.sh"
[[ -f "$SCRIPT_DIR/lib/selections.sh" ]] && source "$SCRIPT_DIR/lib/selections.sh"
[[ -f "$SCRIPT_DIR/lib/nerd_fonts.sh" ]] && source "$SCRIPT_DIR/lib/nerd_fonts.sh"
[[ -f "$SCRIPT_DIR/lib/theme_preview.sh" ]] && source "$SCRIPT_DIR/lib/theme_preview.sh"
[[ -f "$SCRIPT_DIR/lib/theme_select.sh" ]] && source "$SCRIPT_DIR/lib/theme_select.sh"
[[ -f "$SCRIPT_DIR/lib/themes.sh" ]] && source "$SCRIPT_DIR/lib/themes.sh"

declare -A APPS_PROCESSED

mark_app_processed() {
  local app="$1"
  APPS_PROCESSED["$app"]=1
}

is_app_processed() {
  local app="$1"
  [[ "${APPS_PROCESSED[$app]:-0}" == "1" ]]
}

[[ -f "$SCRIPT_DIR/lib/install_priority.sh" ]] && source "$SCRIPT_DIR/lib/install_priority.sh"
[[ -f "$SCRIPT_DIR/lib/os_linux.sh" ]] && source "$SCRIPT_DIR/lib/os_linux.sh"
[[ -f "$SCRIPT_DIR/lib/os_macos.sh" ]] && source "$SCRIPT_DIR/lib/os_macos.sh"
[[ -f "$SCRIPT_DIR/lib/os_windows.sh" ]] && source "$SCRIPT_DIR/lib/os_windows.sh"
[[ -f "$SCRIPT_DIR/lib/gui_apps.sh" ]] && source "$SCRIPT_DIR/lib/gui_apps.sh"
[[ -f "$SCRIPT_DIR/lib/app_installers.sh" ]] && source "$SCRIPT_DIR/lib/app_installers.sh"
[[ -f "$SCRIPT_DIR/lib/tools.sh" ]] && source "$SCRIPT_DIR/lib/tools.sh"
[[ -f "$SCRIPT_DIR/lib/git_config.sh" ]] && source "$SCRIPT_DIR/lib/git_config.sh"
[[ -f "$SCRIPT_DIR/lib/ssh.sh" ]] && source "$SCRIPT_DIR/lib/ssh.sh"
[[ -f "$SCRIPT_DIR/lib/runtimes.sh" ]] && source "$SCRIPT_DIR/lib/runtimes.sh"
[[ -f "$SCRIPT_DIR/lib/editors.sh" ]] && source "$SCRIPT_DIR/lib/editors.sh"
[[ -f "$SCRIPT_DIR/lib/report.sh" ]] && source "$SCRIPT_DIR/lib/report.sh"
[[ -f "$SCRIPT_DIR/lib/export.sh" ]] && source "$SCRIPT_DIR/lib/export.sh"
# data/themes.sh e lib/theme_assets.sh: o instalador copia configs que pedem um
# tema por NOME (btop.conf pede "catppuccin_mocha"). Quando esse tema nao vem no
# pacote da ferramenta, o nome sozinho nao faz nada — ela cai no padrao, em
# silencio. theme_assets.sh sabe instalar o que falta e ja traz a guarda do btop
# em snap confinado.
[[ -f "$SCRIPT_DIR/data/themes.sh" ]] && source "$SCRIPT_DIR/data/themes.sh"
[[ -f "$SCRIPT_DIR/lib/theme_assets.sh" ]] && source "$SCRIPT_DIR/lib/theme_assets.sh"

print_selection_summary() {
  local label="$1"
  shift
  local items=("$@")
  local list="${UI_DIM}(nenhum)${UI_RESET}"
  if [[ ${#items[@]} -gt 0 ]]; then
    list="$(printf "%s, " "${items[@]}")"
    list="${list%, }"
  fi
  msg "  ${UI_CYAN}${UI_BOLD}$label${UI_RESET}: $list"
}

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES AUXILIARES PARA RESUMO RESPONSIVO
# ══════════════════════════════════════════════════════════════════════════════

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


# ══════════════════════════════════════════════════════════════════════════════
# RESUMO DE SELEÇÕES INTERATIVAS
# ══════════════════════════════════════════════════════════════════════════════

_rv_div() {
  local w="$1" title="$2" count="${3:-}"
  local pad_left="${left_pad:-0}"
  local divider_color="${rv_divider_color:-$UI_BORDER}"
  local section_color="${rv_section_color:-${UI_LAVENDER:-$UI_ACCENT}}"
  local count_suffix=""
  [[ -n "$count" ]] && count_suffix=" ($count)"
  local title_vis fill fill_str
  title_vis=$(_visible_len "${title}${count_suffix}")
  fill=$(( w - title_vis - 4 ))
  [[ $fill -lt 0 ]] && fill=0
  printf -v fill_str '%*s' "$fill" ''
  if [[ -n "$count" ]]; then
    printf "%*s%b\n" "$pad_left" "" "${divider_color}── ${section_color}${UI_BOLD}${title}${UI_RESET} ${UI_SUBTEXT0}(${count})${UI_RESET}${divider_color} ${fill_str// /─}${UI_RESET}"
  else
    printf "%*s%b\n" "$pad_left" "" "${divider_color}── ${section_color}${UI_BOLD}${title}${UI_RESET}${divider_color} ${fill_str// /─}${UI_RESET}"
  fi
}

_rv_hbar() {
  local w="$1" bar
  local pad_left="${left_pad:-0}"
  local divider_color="${rv_divider_color:-$UI_BORDER}"
  printf -v bar '%*s' "$w" ''
  printf "%*s%b\n" "$pad_left" "" "${divider_color}${bar// /─}${UI_RESET}"
}

_rv_measure_label_width() {
  local min_width="$1"
  shift
  local max_width="$min_width"
  local label label_vis
  for label in "$@"; do
    label_vis=$(_visible_len "${label}:")
    [[ $label_vis -gt $max_width ]] && max_width="$label_vis"
  done
  echo $((max_width + 1))
}

_count_total_packages() {
  local total=0
  total=$((total + ${#SELECTED_CLI_TOOLS[@]}))
  total=$((total + ${#SELECTED_IA_TOOLS[@]}))
  total=$((total + ${#SELECTED_TERMINALS[@]}))
  total=$((total + ${#SELECTED_RUNTIMES[@]}))
  total=$((total + ${#SELECTED_NERD_FONTS[@]}))
  total=$((total + ${#SELECTED_IDES[@]}))
  total=$((total + ${#SELECTED_BROWSERS[@]}))
  total=$((total + ${#SELECTED_DEV_TOOLS[@]}))
  total=$((total + ${#SELECTED_DATABASES[@]}))
  total=$((total + ${#SELECTED_PRODUCTIVITY[@]}))
  total=$((total + ${#SELECTED_COMMUNICATION[@]}))
  total=$((total + ${#SELECTED_MEDIA[@]}))
  total=$((total + ${#SELECTED_UTILITIES[@]}))
  [[ ${INSTALL_ZSH:-0} -eq 1 ]] && ((total++))
  [[ ${INSTALL_FISH:-0} -eq 1 ]] && ((total++))
  [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && ((total++))
  [[ ${INSTALL_OH_MY_ZSH:-0} -eq 1 ]] && ((total++))
  [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && ((total++))
  [[ ${INSTALL_OH_MY_POSH:-0} -eq 1 ]] && ((total++))
  echo "$total"
}

_count_configs_to_copy() {
  local total=0

  [[ ${COPY_ZSH_CONFIG:-0} -eq 1 ]] && [[ ${INSTALL_ZSH:-0} -eq 1 ]] && ((total++))
  [[ ${COPY_FISH_CONFIG:-0} -eq 1 ]] && [[ ${INSTALL_FISH:-0} -eq 1 ]] && ((total++))
  [[ ${COPY_NUSHELL_CONFIG:-0} -eq 1 ]] && [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && ((total++))

  [[ ${COPY_GIT_CONFIG:-0} -eq 1 ]] && [[ ${GIT_CONFIGURE:-0} -eq 1 ]] && ((total++))
  [[ ${COPY_SSH_KEYS:-0} -eq 1 ]] && ((total++))

  local has_neovim=0 has_vscode=0 has_zed=0 has_helix=0
  for ide in "${SELECTED_IDES[@]}"; do
    case "$ide" in
      neovim) has_neovim=1 ;;
      vscode) has_vscode=1 ;;
      zed) has_zed=1 ;;
      helix) has_helix=1 ;;
    esac
  done
  [[ ${COPY_NVIM_CONFIG:-0} -eq 1 ]] && [[ $has_neovim -eq 1 ]] && ((total++))
  [[ ${COPY_VSCODE_SETTINGS:-0} -eq 1 ]] && [[ $has_vscode -eq 1 ]] && ((total++))
  [[ ${COPY_ZED_CONFIG:-0} -eq 1 ]] && [[ $has_zed -eq 1 ]] && ((total++))
  [[ ${COPY_HELIX_CONFIG:-0} -eq 1 ]] && [[ $has_helix -eq 1 ]] && ((total++))

  local has_tmux=0 has_lazygit=0 has_yazi=0 has_btop=0 has_direnv=0
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      tmux) has_tmux=1 ;;
      lazygit) has_lazygit=1 ;;
      yazi) has_yazi=1 ;;
      btop) has_btop=1 ;;
      direnv) has_direnv=1 ;;
    esac
  done
  [[ ${COPY_TMUX_CONFIG:-0} -eq 1 ]] && [[ $has_tmux -eq 1 ]] && ((total++))
  [[ ${COPY_LAZYGIT_CONFIG:-0} -eq 1 ]] && [[ $has_lazygit -eq 1 ]] && ((total++))
  [[ ${COPY_YAZI_CONFIG:-0} -eq 1 ]] && [[ $has_yazi -eq 1 ]] && ((total++))
  [[ ${COPY_BTOP_CONFIG:-0} -eq 1 ]] && [[ $has_btop -eq 1 ]] && ((total++))
  [[ ${COPY_DIRENV_CONFIG:-0} -eq 1 ]] && [[ $has_direnv -eq 1 ]] && ((total++))

  [[ ${COPY_STARSHIP_CONFIG:-0} -eq 1 ]] && [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && ((total++))
  [[ ${COPY_MISE_CONFIG:-0} -eq 1 ]] && [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && ((total++))

  local has_ghostty=0 has_kitty=0 has_alacritty=0 has_wezterm=0
  for term in "${SELECTED_TERMINALS[@]}"; do
    case "$term" in
      ghostty) has_ghostty=1 ;;
      kitty) has_kitty=1 ;;
      alacritty) has_alacritty=1 ;;
      wezterm) has_wezterm=1 ;;
    esac
  done
  [[ ${COPY_TERMINAL_CONFIG:-0} -eq 1 ]] && [[ $has_ghostty -eq 1 ]] && ((total++))
  [[ ${COPY_KITTY_CONFIG:-0} -eq 1 ]] && [[ $has_kitty -eq 1 ]] && ((total++))
  [[ ${COPY_ALACRITTY_CONFIG:-0} -eq 1 ]] && [[ $has_alacritty -eq 1 ]] && ((total++))
  [[ ${COPY_WEZTERM_CONFIG:-0} -eq 1 ]] && [[ $has_wezterm -eq 1 ]] && ((total++))

  echo "$total"
}

confirm_action() {
  local prompt="$1"
  echo ""
  echo -e "  ${UI_BOLD}${UI_BLUE}Enter${UI_RESET} para $prompt  │  ${UI_BOLD}${UI_YELLOW}P${UI_RESET} para pular"
  echo ""
  local choice
  read -r -p "  → " choice
  case "${choice,,}" in
    p|pular|skip) return 1 ;;
    *) return 0 ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════════════
# AUTO-ENABLE CONFIGS — habilita COPY_* para apps selecionados com config no repo
# ══════════════════════════════════════════════════════════════════════════════
_auto_enable_configs() {
  [[ ${INSTALL_ZSH:-0} -eq 1 ]]     && COPY_ZSH_CONFIG=1
  [[ ${INSTALL_FISH:-0} -eq 1 ]]    && COPY_FISH_CONFIG=1
  [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && COPY_NUSHELL_CONFIG=1
  [[ ${GIT_CONFIGURE:-0} -eq 1 ]]   && COPY_GIT_CONFIG=1
  [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]] && COPY_STARSHIP_CONFIG=1
  [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && COPY_MISE_CONFIG=1
  [[ ${#SELECTED_TERMINALS[@]} -gt 0 ]] && COPY_TERMINAL_CONFIG=1

  local _ide _tool _ia _term _rt _dt
  for _ide in "${SELECTED_IDES[@]}"; do
    case "$_ide" in
      neovim)  [[ -d "$CONFIG_SHARED/nvim" ]]                 && COPY_NVIM_CONFIG=1 ;;
      vscode|cursor)  [[ -f "$CONFIG_SHARED/vscode/settings.json" ]] && COPY_VSCODE_SETTINGS=1 ;;
      zed)     [[ -f "$CONFIG_SHARED/zed/settings.json" ]]    && COPY_ZED_CONFIG=1 ;;
      helix)   [[ -f "$CONFIG_SHARED/helix/config.toml" ]]    && COPY_HELIX_CONFIG=1 ;;
    esac
  done

  for _tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$_tool" in
      tmux)    [[ -d "$CONFIG_SHARED/tmux" ]]                  && COPY_TMUX_CONFIG=1 ;;
      lazygit) [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]    && COPY_LAZYGIT_CONFIG=1 ;;
      yazi)    [[ -d "$CONFIG_SHARED/yazi" ]]                   && COPY_YAZI_CONFIG=1 ;;
      btop)    [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]         && COPY_BTOP_CONFIG=1 ;;
      bat)     [[ -f "$CONFIG_SHARED/bat/config" ]]             && COPY_BAT_CONFIG=1 ;;
      ripgrep) [[ -f "$CONFIG_SHARED/.ripgreprc" ]]             && COPY_RIPGREP_CONFIG=1 ;;
      direnv)  [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]       && COPY_DIRENV_CONFIG=1 ;;
    esac
  done

  for _ia in "${SELECTED_IA_TOOLS[@]}"; do
    [[ "$_ia" == "aider" ]] && [[ -f "$CONFIG_SHARED/aider/.aider.conf.yml" ]] && COPY_AIDER_CONFIG=1
    [[ "$_ia" == "claude-code" ]] && [[ -f "$CONFIG_SHARED/claude/CLAUDE.md" ]] && COPY_CLAUDE_CONFIG=1
  done

  for _term in "${SELECTED_TERMINALS[@]}"; do
    case "$_term" in
      kitty)     [[ -f "$CONFIG_SHARED/kitty/kitty.conf" ]]       && COPY_KITTY_CONFIG=1 ;;
      alacritty) [[ -f "$CONFIG_SHARED/alacritty/alacritty.toml" ]] && COPY_ALACRITTY_CONFIG=1 ;;
      wezterm)   [[ -f "$CONFIG_SHARED/wezterm/wezterm.lua" ]]     && COPY_WEZTERM_CONFIG=1 ;;
    esac
  done

  for _rt in "${SELECTED_RUNTIMES[@]}"; do
    case "$_rt" in
      node)   [[ -f "$CONFIG_SHARED/npm/.npmrc" ]]        && COPY_NPM_CONFIG=1
              [[ -f "$CONFIG_SHARED/pnpm/.pnpmrc" ]]      && COPY_PNPM_CONFIG=1
              [[ -f "$CONFIG_SHARED/yarn/.yarnrc" ]]       && COPY_YARN_CONFIG=1 ;;
      python) [[ -f "$CONFIG_SHARED/pip/pip.conf" ]]       && COPY_PIP_CONFIG=1 ;;
      rust)   [[ -f "$CONFIG_SHARED/cargo/config.toml" ]]  && COPY_CARGO_CONFIG=1 ;;
    esac
  done

  for _dt in "${SELECTED_DEV_TOOLS[@]}"; do
    [[ "$_dt" == "docker" ]] && [[ -f "$CONFIG_SHARED/docker/config.json" ]] && COPY_DOCKER_CONFIG=1
  done
}

print_error_block() {
  local pad="$1" title="$2"
  shift 2
  local items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    return
  fi
  printf "%*s  %b\n" "$pad" "" "$title"
  for item in "${items[@]}"; do
    printf "%*s   - %s\n" "$pad" "" "$item"
  done
  echo ""
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
    local term_w
    term_w=$(tput cols 2>/dev/null || echo 80)
    local width=$((term_w > 100 ? 94 : term_w - 6))
    [[ $width -lt 50 ]] && width=50
    local lp=2
    local fs_divider="${UI_OVERLAY1:-$UI_BORDER}"
    local fs_section="${UI_MAUVE:-$UI_ACCENT}"
    local bar
    printf -v bar '%*s' "$width" ''

    echo ""
    printf "%*s%b\n" "$lp" "" "${fs_divider}── ${fs_section}${UI_BOLD}⚠ FALHAS (${MODE})${UI_RESET}${fs_divider} ${bar:0:$((width - 22))}${UI_RESET}"
    print_error_block "$lp" "${UI_RED}${UI_BOLD}❌ Falhas críticas:${UI_RESET}" "${CRITICAL_ERRORS[@]}"
    print_error_block "$lp" "${UI_WARNING}⚠️  Falhas opcionais:${UI_RESET}" "${OPTIONAL_ERRORS[@]}"

    if [[ ${#CRITICAL_ERRORS[@]} -eq 0 ]]; then
      printf "%*s  %b\n" "$lp" "" "${UI_GREEN}✅ Execução concluída sem falhas críticas.${UI_RESET}"
    else
      printf "%*s  %b\n" "$lp" "" "${UI_RED}❌ Execução finalizada com falhas críticas.${UI_RESET}"
    fi

    echo ""
  fi

  if [[ "${POST_INSTALL_REPORT_SHOWN:-0}" -ne 1 ]] && [[ -n "${INSTALL_LOG:-}" ]] && [[ -f "${INSTALL_LOG:-}" ]]; then
    msg "  📄 Log completo: ${INSTALL_LOG}"
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

  # Detectar arquitetura
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    armv7l) ARCH="armv7" ;;
    *) ARCH="$ARCH" ;;
  esac
  state_set "system.arch" "$ARCH"
}

is_wsl2() {
  [[ "$TARGET_OS" == "wsl2" ]]
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

install_zen_linux() {
  install_via_flatpak_or_snap "zen-browser" "Zen Browser" "io.github.ranfdev.Zen"
}

install_pgadmin_linux() {
  install_via_flatpak_or_snap "pgadmin4" "pgAdmin" "org.pgadmin.pgadmin4"
}

install_mongodb_linux() {
  if has_cmd mongod; then
    local mongo_version
    mongo_version="$(mongod --version 2>/dev/null | head -n 1 || echo '')"
    if [[ -n "$mongo_version" ]]; then
      msg "  ✅ MongoDB já instalado ($mongo_version)"
    fi
    return 0
  fi

  detect_linux_pkg_manager
  case "${LINUX_PKG_MANAGER:-}" in
    apt-get)
      # Desde a licença SSPL (2018), Debian/Ubuntu removeram mongodb-org dos
      # repos padrão -- "apt-get install mongodb" falha com "pacote não
      # encontrado" em distros atuais (achado de auditoria). Tenta adicionar
      # o repo oficial primeiro; best-effort (codename pode nao ser suportado
      # ainda pelo MongoDB) -- se falhar, cai no aviso final com link da doc.
      _add_mongodb_apt_repo_linux
      install_linux_packages optional mongodb-org || \
      install_linux_packages optional mongodb || true
      ;;
    dnf)
      install_linux_packages optional mongodb-org-server || \
      install_linux_packages optional mongodb-server || true
      ;;
    pacman)
      install_linux_packages optional mongodb || true
      ;;
    zypper)
      install_linux_packages optional mongodb || true
      ;;
  esac

  if has_cmd mongod; then
    msg "  ✅ MongoDB Server instalado"
    return 0
  fi

  record_failure "optional" "MongoDB Server não instalado automaticamente no Linux" "Repo oficial pode não suportar sua distro/versão ainda -- veja https://www.mongodb.com/docs/manual/administration/install-on-linux/"
  return 1
}

# Adiciona o repo apt oficial do MongoDB (best-effort). So roda se
# mongodb-org ainda não estiver disponível via repo já configurado.
_add_mongodb_apt_repo_linux() {
  is_truthy "$DRY_RUN" && { msg "  🔎 (dry-run) adicionaria repo apt oficial do MongoDB"; return 0; }
  [[ -f /etc/apt/sources.list.d/mongodb-org.list ]] && return 0
  ! has_cmd curl && return 1

  local distro_id="" codename=""
  if [[ -f /etc/os-release ]]; then
    distro_id="$(. /etc/os-release && echo "$ID")"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  fi
  [[ -z "$distro_id" || -z "$codename" ]] && return 1

  local repo_os=""
  case "$distro_id" in
    ubuntu) repo_os="ubuntu" ;;
    debian) repo_os="debian" ;;
    *) return 1 ;; # derivadas (Mint, Pop!_OS, etc.) tem codename proprio que nao bate com o repo do Mongo
  esac

  local keyring="/usr/share/keyrings/mongodb-server-7.0.gpg"
  if curl -fsSL "https://pgp.mongodb.com/server-7.0.asc" | run_with_sudo gpg -o "$keyring" --dearmor 2>/dev/null; then
    echo "deb [ arch=amd64,arm64 signed-by=$keyring ] https://repo.mongodb.org/apt/$repo_os $codename/mongodb-org/7.0 multiverse" \
      | run_with_sudo tee /etc/apt/sources.list.d/mongodb-org.list > /dev/null
    LINUX_PKG_UPDATED=0
    return 0
  fi
  return 1
}

# install_php_build_deps_linux() → Movido para lib/os_linux.sh
# install_php_build_deps_macos() → Movido para lib/os_macos.sh
# install_php_windows() → Movido para lib/os_windows.sh

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

_extract_url_host() {
  local url="$1"
  url="${url#*://}"
  url="${url%%/*}"
  url="${url%%\?*}"
  url="${url%%#*}"
  url="${url%%:*}"
  printf '%s\n' "$url"
}

_is_trusted_remote_host() {
  local host="$1"
  local allowed
  local -a allowlist=()
  IFS=',' read -r -a allowlist <<< "$REMOTE_SCRIPT_ALLOWLIST"

  for allowed in "${allowlist[@]}"; do
    allowed="${allowed// /}"
    [[ -z "$allowed" ]] && continue
    if [[ "$host" == "$allowed" || "$host" == *."$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

_sha256_file() {
  local file="$1"
  if has_cmd sha256sum; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  if has_cmd shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi
  return 1
}

_verify_remote_script_checksum() {
  local file="$1"
  local friendly="$2"
  local expected="${3:-}"

  if [[ -z "$expected" ]]; then
    if is_truthy "$REMOTE_SCRIPT_REQUIRE_CHECKSUM"; then
      record_failure "critical" "Checksum SHA256 obrigatório e ausente para $friendly"
      return 1
    fi
    warn "Script remoto sem checksum SHA256: $friendly (use REMOTE_SCRIPT_REQUIRE_CHECKSUM=1 para bloquear)"
    return 0
  fi

  local current=""
  current="$(_sha256_file "$file" 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    record_failure "critical" "Ferramenta SHA256 indisponível para validar script de $friendly"
    return 1
  fi
  if [[ "$current" != "$expected" ]]; then
    record_failure "critical" "Checksum SHA256 inválido para $friendly (esperado $expected, obtido $current)"
    return 1
  fi

  return 0
}

download_and_run_script() {
  local url="$1"
  local friendly="$2"
  local shell_bin="${3:-sh}"
  local curl_extra="${4:-}"
  local script_args="${5:-}"
  local expected_sha256="${6:-}"
  local host=""

  host="$(_extract_url_host "$url")"
  if [[ -z "$host" ]]; then
    record_failure "critical" "URL inválida para instalador remoto ($friendly): $url"
    return 1
  fi

  if ! _is_trusted_remote_host "$host"; then
    local trust_msg="Host remoto não permitido para $friendly: $host (ajuste REMOTE_SCRIPT_ALLOWLIST)"
    if is_truthy "$REMOTE_SCRIPT_STRICT"; then
      record_failure "critical" "$trust_msg"
      return 1
    fi
    warn "$trust_msg"
  fi

  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) script remoto: $friendly ($url)"
    return 0
  fi

  if ! has_cmd curl; then
    record_failure "critical" "curl não encontrado. Instale curl primeiro para continuar."
    return 1
  fi
  if ! has_cmd "$shell_bin"; then
    record_failure "critical" "Shell '$shell_bin' não encontrada para executar script de $friendly"
    return 1
  fi

  local temp_script=""
  temp_script="$(mktemp)" || {
    record_failure "critical" "Falha ao criar arquivo temporário para instalador $friendly"
    return 1
  }

  local -a curl_args=(-fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_TIMEOUT_LONG")
  if [[ -n "$curl_extra" ]]; then
    local -a extra_args=()
    read -r -a extra_args <<< "$curl_extra"
    curl_args+=("${extra_args[@]}")
  fi

  if ! curl "${curl_args[@]}" "$url" -o "$temp_script"; then
    rm -f "$temp_script"
    record_failure "critical" "Falha ao baixar instalador $friendly"
    return 1
  fi

  chmod 700 "$temp_script" 2>/dev/null || true
  if ! _verify_remote_script_checksum "$temp_script" "$friendly" "$expected_sha256"; then
    rm -f "$temp_script"
    return 1
  fi

  local rc=0
  local -a exec_args=()
  if [[ -n "$script_args" ]]; then
    read -r -a exec_args <<< "$script_args"
  fi

  # < /dev/null evita que scripts interativos travem esperando input
  if is_truthy "$VERBOSE"; then
    "$shell_bin" "$temp_script" "${exec_args[@]}" < /dev/null || rc=$?
  else
    "$shell_bin" "$temp_script" "${exec_args[@]}" < /dev/null >/dev/null 2>&1 || rc=$?
  fi
  rm -f "$temp_script"

  [[ $rc -eq 0 ]]
}

# ensure_rust_cargo() → Movido para lib/tools.sh

ensure_ghostty_linux() {
  if has_cmd ghostty; then
    return 0
  fi

  msg "▶ Ghostty não encontrado. Tentando instalar..."

  detect_linux_pkg_manager
  case "${LINUX_PKG_MANAGER:-}" in
    apt-get)
      msg "  📦 Tentando instalar Ghostty via apt..."
      install_linux_packages optional ghostty || true
      ;;
    dnf)
      msg "  📦 Tentando instalar Ghostty via dnf..."
      install_linux_packages optional ghostty || true
      ;;
    pacman)
      msg "  📦 Tentando instalar Ghostty via pacman..."
      install_linux_packages optional ghostty || true
      ;;
    zypper)
      msg "  📦 Tentando instalar Ghostty via zypper..."
      install_linux_packages optional ghostty || true
      ;;
  esac

  if has_cmd ghostty; then
    msg "  ✅ Ghostty instalado via gerenciador da distro"
    INSTALLED_MISC+=("ghostty: distro package")
    return 0
  fi

  if has_cmd snap; then
    snap_install_or_refresh ghostty "Ghostty" optional --classic
    if has_cmd ghostty; then
      msg "  ✅ Ghostty instalado via snap"
      INSTALLED_MISC+=("ghostty: snap")
      return 0
    fi
  fi

  if has_cmd flatpak; then
    msg "  📦 Tentando instalar Ghostty via Flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    if flatpak info com.mitchellh.ghostty >/dev/null 2>&1 || flatpak install -y flathub com.mitchellh.ghostty >/dev/null 2>&1; then
      msg "  ✅ Ghostty instalado via Flatpak"
      INSTALLED_MISC+=("ghostty: flatpak")
      return 0
    fi
  fi

  record_failure "optional" "Não foi possível instalar Ghostty automaticamente."
  msg "  ℹ️  Visite https://ghostty.org para instruções oficiais de instalação."
  return 1
}

# ═══════════════════════════════════════════════════════════
# Pós-configuração: shell e terminal padrão
# ═══════════════════════════════════════════════════════════

apply_post_install_defaults() {
  local changed=0

  # ── Fish como shell padrão ──
  if is_truthy "${INSTALL_FISH:-0}" && has_cmd fish; then
    local current_shell
    current_shell="$(basename "${SHELL:-}")"
    if [[ "$current_shell" != "fish" ]]; then
      local fish_path
      fish_path="$(command -v fish)"
      msg ""
      msg "  🐟 Fish está instalado mas não é o shell padrão (atual: $current_shell)"
      if ui_confirm "Definir Fish como shell padrão?"; then
        if is_truthy "${DRY_RUN:-0}"; then
          msg "  🔎 (dry-run) executaria: chsh -s $fish_path"
        else
          # Garantir que fish está em /etc/shells
          if ! grep -qx "$fish_path" /etc/shells 2>/dev/null; then
            msg "  📝 Adicionando $fish_path a /etc/shells..."
            echo "$fish_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
          fi
          if chsh -s "$fish_path" 2>/dev/null; then
            msg "  ✅ Fish definido como shell padrão"
            msg "  💡 Abra um novo terminal para usar o Fish"
            changed=1
          else
            msg "  ⚠️  chsh falhou — defina manualmente com: chsh -s $fish_path"
          fi
        fi
      else
        msg "  ⏭️  Mantendo shell padrão: $current_shell"
      fi
    else
      msg "  ✅ Fish já é o shell padrão"
    fi
  fi

  # ── Terminal padrão (Linux/WSL2) ──
  if [[ "$TARGET_OS" == "linux" || "$TARGET_OS" == "wsl2" ]]; then
    local has_ghostty=0
    for term in "${SELECTED_TERMINALS[@]}"; do
      [[ "$term" == "ghostty" ]] && has_ghostty=1
    done

    if [[ $has_ghostty -eq 1 ]] && has_cmd ghostty; then
      local ghostty_path
      ghostty_path="$(command -v ghostty)"

      msg ""
      msg "  👻 Ghostty está instalado"
      if ui_confirm "Definir Ghostty como terminal padrão?"; then
        if is_truthy "${DRY_RUN:-0}"; then
          msg "  🔎 (dry-run) definiria Ghostty como terminal padrão"
        else
          local set_ok=0

          # Método 1: update-alternatives (Debian/Ubuntu)
          if has_cmd update-alternatives; then
            if sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$ghostty_path" 50 2>/dev/null; then
              sudo update-alternatives --set x-terminal-emulator "$ghostty_path" 2>/dev/null && set_ok=1
            fi
          fi

          # Método 2: GNOME/gsettings (complementar)
          if has_cmd gsettings; then
            # Criar .desktop se não existe (necessário para snap)
            local desktop_file="$HOME/.local/share/applications/ghostty.desktop"
            if [[ ! -f "$desktop_file" ]]; then
              mkdir -p "$HOME/.local/share/applications"
              cat > "$desktop_file" << DESKTOP
[Desktop Entry]
Name=Ghostty
Comment=Terminal rápido e moderno
Exec=$ghostty_path
Icon=com.mitchellh.ghostty
Type=Application
Categories=System;TerminalEmulator;
Keywords=terminal;shell;prompt;command;
StartupNotify=true
DESKTOP
            fi
            gsettings set org.gnome.desktop.default-applications.terminal exec "$ghostty_path" 2>/dev/null && set_ok=1
            gsettings set org.gnome.desktop.default-applications.terminal exec-arg '' 2>/dev/null || true
          fi

          if [[ $set_ok -eq 1 ]]; then
            msg "  ✅ Ghostty definido como terminal padrão"
            changed=1
          else
            msg "  ⚠️  Não foi possível definir automaticamente"
            msg "  💡 Defina manualmente nas configurações do sistema"
          fi
        fi
      else
        msg "  ⏭️  Terminal padrão não alterado"
      fi
    fi
  fi

  [[ $changed -eq 0 ]] && msg "  ℹ️  Nenhuma alteração de padrão aplicada"
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

  if [[ "${TARGET_OS:-}" == "macos" ]] && has_cmd brew; then
    if brew install mise >/dev/null 2>&1; then
      INSTALLED_PACKAGES+=("brew: mise (install)")
      msg "  ✅ mise instalado via Homebrew"
      return 0
    fi
  fi

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
    msg "  💡 Execute: ./install.sh --dry-run e selecione a instalação de runtimes."
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

install_prerequisites() {
  if [[ "${INSTALL_BASE_DEPS:-1}" -ne 1 ]]; then
    msg "  ⏭️  Dependências base desativadas (INSTALL_BASE_DEPS=0)"
    BASE_DEPS_INSTALLED=1
    return 0
  fi
  if [[ "${BASE_DEPS_INSTALLED:-0}" -eq 1 ]]; then
    if has_cmd curl && has_cmd git; then
      return 0
    fi
    msg "  🔄 Dependências base não encontradas, reinstalando..."
  fi

  # macOS/Windows chamam brew/winget direto (sem passar por run_with_sudo), então
  # DRY_RUN precisa ser checado aqui -- senão "dry run" roda brew update/winget
  # install de verdade (achado real: era a causa mais provável do Dry Run macOS
  # do CI travar 30min+/6h+, não um loop de menu).
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) instalaria dependências base via $TARGET_OS (brew/winget/apt/dnf/pacman/zypper)"
    BASE_DEPS_INSTALLED=1
    return 0
  fi

  local install_success=0
  case "$TARGET_OS" in
    linux|wsl2)
      install_linux_base_dependencies && install_success=1
      if is_wsl2; then
        msg "  ℹ️  WSL2 detectado - usando configurações Linux com ajustes para Windows"
      fi
      ;;
    macos)
      install_macos_base_dependencies && install_success=1
      ;;
    windows)
      install_windows_base_dependencies && install_success=1
      ;;
  esac

  [[ $install_success -eq 1 ]] && BASE_DEPS_INSTALLED=1
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
      install_macos_selected_apps
      ;;
    windows)
      install_windows_selected_apps
      ;;
  esac
}

# ════════════════════════════════════════════════════════════════
# Tabela declarativa de operações de cópia de config
# ════════════════════════════════════════════════════════════════
# Formato por linha: "FLAG|type|src_rel|dest_abs|src_exists_check"
#
# - FLAG: nome da variável COPY_X_CONFIG (verificada contra 1)
# - type: "file" (copy_file) ou "dir" (copy_dir)
# - src_rel: caminho relativo a $CONFIG_SHARED
# - dest_abs: caminho absoluto de destino (pode usar $HOME)
# - src_exists_check: arquivo/dir que deve existir no source (guard);
#                     vazio = apenas confere se COPY flag está ativa
#
# Casos especiais (fish, zsh, nushell, git, ssh, claude) ficam em funções
# dedicadas no apply_shared_configs() porque têm pré/pós-processamento.
# Claude Code especificamente: settings.json não pode ser copiado por cima
# (perderia secrets/hooks/permissions específicos da máquina) — precisa de
# merge via lib/../claude/merge-settings.mjs em vez de copy_file/copy_dir.
_build_shared_copy_ops() {
  SHARED_COPY_OPS=(
    # Tool configs (herdadas de copy_tool_configs)
    "COPY_LAZYGIT_CONFIG|dir|lazygit|$HOME/.config/lazygit|lazygit/config.yml"
    "COPY_YAZI_CONFIG|dir|yazi|$HOME/.config/yazi|yazi"
    "COPY_BTOP_CONFIG|dir|btop|$HOME/.config/btop|btop/btop.conf"
    "COPY_BAT_CONFIG|dir|bat|$HOME/.config/bat|bat/config"
    "COPY_KITTY_CONFIG|dir|kitty|$HOME/.config/kitty|kitty/kitty.conf"
    "COPY_ALACRITTY_CONFIG|dir|alacritty|$HOME/.config/alacritty|alacritty/alacritty.toml"
    "COPY_WEZTERM_CONFIG|dir|wezterm|$HOME/.config/wezterm|wezterm/wezterm.lua"
    "COPY_RIPGREP_CONFIG|file|.ripgreprc|$HOME/.ripgreprc|.ripgreprc"
    "COPY_NPM_CONFIG|file|npm/.npmrc|$HOME/.npmrc|npm/.npmrc"
    "COPY_PNPM_CONFIG|file|pnpm/.pnpmrc|$HOME/.config/pnpm/.pnpmrc|pnpm/.pnpmrc"
    "COPY_YARN_CONFIG|file|yarn/.yarnrc|$HOME/.yarnrc|yarn/.yarnrc"
    "COPY_PIP_CONFIG|file|pip/pip.conf|$HOME/.config/pip/pip.conf|pip/pip.conf"
    "COPY_CARGO_CONFIG|file|cargo/config.toml|$HOME/.cargo/config.toml|cargo/config.toml"
    "COPY_ZED_CONFIG|file|zed/settings.json|$HOME/.config/zed/settings.json|zed/settings.json"
    "COPY_HELIX_CONFIG|file|helix/config.toml|$HOME/.config/helix/config.toml|helix/config.toml"
    "COPY_AIDER_CONFIG|file|aider/.aider.conf.yml|$HOME/.aider.conf.yml|aider/.aider.conf.yml"
    "COPY_DOCKER_CONFIG|file|docker/config.json|$HOME/.docker/config.json|docker/config.json"
    "COPY_DIRENV_CONFIG|file|direnv/.direnvrc|$HOME/.config/direnv/direnvrc|direnv/.direnvrc"
    # Configs simples de topo (gated por cmd e não por fish/zsh/git/ssh que são especiais)
    "COPY_MISE_CONFIG|dir|mise|$HOME/.config/mise|mise"
    "COPY_STARSHIP_CONFIG|file|starship.toml|$HOME/.config/starship.toml|starship.toml"
    "COPY_NVIM_CONFIG|dir|nvim|$HOME/.config/nvim|nvim"
    "COPY_TMUX_CONFIG|file|tmux/.tmux.conf|$HOME/.tmux.conf|tmux/.tmux.conf"
  )
}

# Executa uma entrada da tabela SHARED_COPY_OPS.
# Retorna cedo se a flag não está ativa ou o source não existe.
_run_copy_op() {
  local flag="$1" type="$2" src_rel="$3" dest="$4" src_check="$5"
  local flag_value="${!flag:-0}"

  if [[ "$flag_value" -ne 1 ]]; then
    return 0
  fi

  local src_full="$CONFIG_SHARED/$src_rel"
  if [[ -n "$src_check" ]]; then
    local check_path="$CONFIG_SHARED/$src_check"
    if [[ ! -e "$check_path" ]]; then
      return 0
    fi
  fi

  mkdir -p "$(dirname "$dest")"
  case "$type" in
    file) copy_file "$src_full" "$dest" ;;
    dir)  copy_dir "$src_full" "$dest" ;;
  esac
}

install_bat_catppuccin_theme() {
  [[ ${COPY_BAT_CONFIG:-0} -eq 0 ]] && return 0

  local bat_cmd=""
  if has_cmd bat; then
    bat_cmd="bat"
  elif has_cmd batcat; then
    bat_cmd="batcat"
  else
    return 0
  fi

  # O bat passou a empacotar Catppuccin na v0.26.0 (out/2025). Clonar o
  # repositorio nesse caso e trabalho morto: baixa, grava em ~/.config/bat/themes
  # e reconstroi o cache para um tema que ja estava ali. A checagem e pelo tema
  # disponivel, nao pela versao — assim continua funcionando em bat antigo, que
  # e justamente quem ainda precisa do clone.
  if "$bat_cmd" --list-themes 2>/dev/null | grep -qx "Catppuccin Mocha"; then
    msg "  ✅ Tema Catppuccin do bat ja vem no proprio bat ($("$bat_cmd" --version 2>/dev/null | head -1))"
    return 0
  fi

  local themes_dir="$HOME/.config/bat/themes"
  local catppuccin_dir="$themes_dir/catppuccin"

  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) instalaria tema Catppuccin do bat em $catppuccin_dir"
    return 0
  fi

  if ! has_cmd git; then
    record_failure "optional" "git não encontrado - necessário para instalar tema Catppuccin do bat"
    return 1
  fi

  mkdir -p "$themes_dir"

  if [[ -d "$catppuccin_dir/.git" ]]; then
    msg "  🔄 Atualizando tema Catppuccin do bat..."
    if ! git -C "$catppuccin_dir" pull --ff-only >/dev/null 2>&1; then
      warn "Falha ao atualizar tema Catppuccin do bat; mantendo versão atual."
    fi
  elif [[ -d "$catppuccin_dir" ]]; then
    msg "  ℹ️  Tema Catppuccin do bat já existe em $catppuccin_dir"
  else
    msg "  🎨 Instalando tema Catppuccin do bat..."
    if ! git clone --depth=1 https://github.com/catppuccin/bat.git "$catppuccin_dir" >/dev/null 2>&1; then
      record_failure "optional" "Falha ao clonar tema Catppuccin para bat"
      return 1
    fi
  fi

  msg "  🔧 Rebuild do cache de temas do bat..."
  if ! "$bat_cmd" cache --build >/dev/null 2>&1; then
    record_failure "optional" "Falha ao rebuild do cache de temas do bat"
    return 1
  fi

  if "$bat_cmd" --list-themes 2>/dev/null | grep -qi "Catppuccin Mocha"; then
    msg "  ✅ Tema Catppuccin Mocha disponível no bat"
  else
    warn "Tema Catppuccin não encontrado em '$bat_cmd --list-themes'"
  fi
}

# ──────────────────────────────────────────────────────────────
# Casos especiais: tratam preserve-PATH, P10k, Nushell scripts/,
# Git multi-conta + PRIVATE_SHARED override, SSH keys
# ──────────────────────────────────────────────────────────────

_apply_fish_config() {
  if ! is_truthy "$INSTALL_FISH"; then
    return 0
  fi
  if [[ ${COPY_FISH_CONFIG:-0} -ne 1 ]]; then
    msg "  ⏭️  Fish config: usuário optou por não copiar"
    return 0
  fi
  if ! has_cmd fish; then
    msg "  ⚠️ Fish não encontrado, pulando config."
    return 0
  fi

  local preserved=""
  preserved="$(extract_user_path_config_fish)"

  copy_dir "$CONFIG_SHARED/fish" "$HOME/.config/fish"
  normalize_crlf_to_lf "$HOME/.config/fish/config.fish"

  if [[ -n "$preserved" ]]; then
    msg "  🔄 Verificando configurações de PATH para preservar..."
    append_preserved_config "$HOME/.config/fish/config.fish" "$preserved"
  fi
}

_apply_zsh_config() {
  if ! is_truthy "$INSTALL_ZSH"; then
    return 0
  fi
  if [[ ${COPY_ZSH_CONFIG:-0} -ne 1 ]]; then
    msg "  ⏭️  Zsh config: usuário optou por não copiar"
    return 0
  fi
  if ! has_cmd zsh; then
    msg "  ⚠️ Zsh não encontrado, pulando .zshrc."
    return 0
  fi

  local preserved=""
  preserved="$(extract_user_path_config_zsh)"

  copy_file "$CONFIG_SHARED/zsh/.zshrc" "$HOME/.zshrc"
  normalize_crlf_to_lf "$HOME/.zshrc"

  if [[ -n "$preserved" ]]; then
    msg "  🔄 Verificando configurações de PATH para preservar..."
    append_preserved_config "$HOME/.zshrc" "$preserved"
  fi

  if [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]]; then
    copy_file "$CONFIG_SHARED/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
  else
    msg "  ⚠️ Powerlevel10k não encontrado em ~/.oh-my-zsh, pulando .p10k.zsh."
  fi
}

_apply_nushell_config() {
  if ! is_truthy "$INSTALL_NUSHELL"; then
    return 0
  fi
  if [[ ${COPY_NUSHELL_CONFIG:-0} -ne 1 ]]; then
    msg "  ⏭️  Nushell config: usuário optou por não copiar"
    return 0
  fi
  if ! has_cmd nu; then
    msg "  ⚠️ Nushell não encontrado após instalação, pulando config."
    return 0
  fi

  mkdir -p "$HOME/.config/nushell"
  copy_file "$CONFIG_SHARED/nushell/config.nu" "$HOME/.config/nushell/config.nu"
  copy_file "$CONFIG_SHARED/nushell/env.nu" "$HOME/.config/nushell/env.nu"
  mkdir -p "$HOME/.config/nushell/scripts"
}

_apply_git_config() {
  if [[ ${COPY_GIT_CONFIG:-0} -ne 1 ]]; then
    msg "  ⏭️  Git config: usuário optou por não copiar"
    return 0
  fi
  if ! has_cmd git; then
    msg "  ⚠️ Git não encontrado, pulando .gitconfig."
    return 0
  fi

  # Se GIT_CONFIGURE=1, a geração dinâmica (install_git_configuration) vai
  # sobrescrever esses arquivos. Pula cópia estática para preservar o
  # backup correto do original do usuário.
  if [[ ${GIT_CONFIGURE:-0} -eq 1 ]]; then
    msg "  ℹ️  Git config: será gerado interativamente (pulando cópia estática)"
    return 0
  fi

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
}

# Pós-processamento: alacritty usa `open` no macOS (xdg-open é Linux)
_postprocess_alacritty_for_macos() {
  [[ ${COPY_ALACRITTY_CONFIG:-0} -ne 1 ]] && return 0
  [[ "${TARGET_OS:-linux}" != "macos" ]] && return 0
  local conf="$HOME/.config/alacritty/alacritty.toml"
  [[ -f "$conf" ]] || return 0
  sed -i'' 's/command = "xdg-open"/command = "open"/' "$conf" 2>/dev/null || true
}

# Claude Code: CLAUDE.md/RTK.md/skills copiam direto (cp -R aditivo, nao mexe
# em ~/.claude/projects|sessions|credentials.json|plugins que ja existirem).
# settings.json NAO e copiado por cima (perderia secrets/estado por-maquina) --
# um merge script Node funde so enabledPlugins/extraKnownMarketplaces/hooks/
# preferencias, preservando o resto.
_apply_claude_config() {
  [[ ${COPY_CLAUDE_CONFIG:-0} -eq 1 ]] || return 0
  [[ -d "$CONFIG_SHARED/claude" ]] || return 0

  msg "▶ Claude Code (CLAUDE.md, RTK.md, skills, settings.json)"

  copy_file "$CONFIG_SHARED/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  copy_file "$CONFIG_SHARED/claude/RTK.md" "$HOME/.claude/RTK.md"
  if [[ -d "$CONFIG_SHARED/claude/skills" ]]; then
    local skill_dir
    for skill_dir in "$CONFIG_SHARED/claude/skills"/*/; do
      [[ -d "$skill_dir" ]] || continue
      [[ -f "${skill_dir}SKILL.md" ]] || continue
      copy_dir "$skill_dir" "$HOME/.claude/skills/$(basename "$skill_dir")"
    done
  fi

  if ! has_cmd node; then
    warn "node não encontrado — pulando merge de settings.json do Claude Code (rode depois: node \"$CONFIG_SHARED/claude/merge-settings.mjs\")"
    return 0
  fi
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) node merge-settings.mjs (funde plugins/hooks/preferencias em ~/.claude/settings.json, sem tocar em env/permissions.allow)"
    return 0
  fi
  if node "$CONFIG_SHARED/claude/merge-settings.mjs"; then
    INSTALLED_MISC+=("claude-code: settings.json mesclado")
  else
    record_failure "optional" "Falha ao mesclar settings.json do Claude Code"
  fi
}

# Instala os arquivos de tema que as configs copiadas pedem pelo nome.
#
# O caso concreto: shared/btop/btop.conf pede color_theme = "catppuccin_mocha",
# que NAO vem no pacote do btop. Sem este passo, uma maquina nova recebia a
# config e o btop caia no tema padrao sem dizer nada — o mesmo sintoma que levou
# tempo para ser diagnosticado nesta maquina em Set/2026.
#
# Reusa lib/theme_assets.sh, que ja trata DRY_RUN, ja recusa instalar quando o
# btop vem de snap com confinamento estrito (onde criar o diretorio de temas o
# faz abortar), e ja avisa em vez de falhar quando nao consegue baixar.
_apply_theme_assets() {
  declare -F install_theme_assets_for >/dev/null 2>&1 || return 0
  [[ ${COPY_BTOP_CONFIG:-0} -eq 1 || ${COPY_BAT_CONFIG:-0} -eq 1 ]] || return 0

  local tema="${TEMA_ATIVO:-catppuccin-mocha}"
  msg "▶ Assets de tema (${tema})"
  install_theme_assets_for "$tema"
}

apply_shared_configs() {
  msg "▶ Copiando configs compartilhadas"

  # Casos especiais (preserve-PATH, P10k, multi-conta, SSH prompts)
  _apply_fish_config
  _apply_zsh_config
  _apply_nushell_config
  _apply_git_config
  _apply_claude_config

  # Configs simples via tabela declarativa
  declare -a SHARED_COPY_OPS=()
  _build_shared_copy_ops
  local op
  for op in "${SHARED_COPY_OPS[@]}"; do
    IFS='|' read -r flag type src_rel dest src_check <<< "$op"
    _run_copy_op "$flag" "$type" "$src_rel" "$dest" "$src_check"
  done
  _postprocess_alacritty_for_macos

  # VS Code: função dedicada (resolve path por OS)
  if [[ ${COPY_VSCODE_SETTINGS:-0} -eq 1 ]]; then
    copy_vscode_settings
  else
    msg "  ⏭️  VS Code settings: usuário optou por não copiar"
  fi

  install_bat_catppuccin_theme
  _apply_theme_assets

  _apply_ssh_keys
}

# export_vscode_settings() → Movido para lib/fileops.sh

# export_windows_configs_back() → Movido para lib/os_windows.sh

main() {
  if [[ ! -d "$CONFIG_SHARED" ]]; then
    echo "❌ Pasta shared/ não encontrada em $CONFIG_SHARED" >&2
    exit 1
  fi

  TARGET_OS="$(detect_os)"

  # Simulacao nao suja o $HOME: em DRY_RUN o log vai para o diretorio temporario
  # do sistema. Sem isso, cada `DRY_RUN=1 bash install.sh` deixava um
  # .dotfiles-install-*.log permanente no home de quem so queria simular.
  if is_truthy "$DRY_RUN"; then
    INSTALL_LOG="${TMPDIR:-/tmp}/dotfiles-install-dryrun-$(date +%Y%m%d-%H%M%S).log"
  else
    INSTALL_LOG="$HOME/.dotfiles-install-$(date +%Y%m%d-%H%M%S).log"
  fi

  if [[ "$MODE" == "export" ]]; then
    export_configs
    exit 0
  fi

  if [[ "$MODE" == "sync" ]]; then
    export_configs
    msg ""
    msg "╔══════════════════════════════════════╗"
    msg "║   Agora instalando configs...        ║"
    msg "╚══════════════════════════════════════╝"
    sleep 1
  fi

  if [[ "$MODE" == "install" || "$MODE" == "sync" ]]; then
    if checkpoint_exists && [[ "$RESUME_MODE" -ne 1 ]]; then
      echo ""
      echo "╭──────────────────────────────────────────────────────────╮"
      echo "│  🔄 Checkpoint encontrado de instalação anterior         │"
      echo "│     Deseja retomar de onde parou?                        │"
      echo "├──────────────────────────────────────────────────────────┤"
      echo "│  Enter = Retomar    N = Nova instalação                  │"
      echo "╰──────────────────────────────────────────────────────────╯"
      local resume_choice
      read -r -p "  → " resume_choice
      if [[ "${resume_choice,,}" != "n" ]]; then
        checkpoint_load
        RESUME_MODE=1
        msg "  ✅ Checkpoint carregado. Retomando instalação..."
        sleep 1
      else
        checkpoint_clear
        msg "  🗑️  Checkpoint removido. Iniciando nova instalação..."
        sleep 1
      fi
    fi

    show_banner
    pause_before_next_section "Pressione Enter para começar a configuração..." "true"
  fi

  clear_screen

  # ══════════════════════════════════════════════════════════════
  # ETAPA 1: Seleções Essenciais (pular se resumindo)
  # ══════════════════════════════════════════════════════════════
  if [[ "$RESUME_MODE" -ne 1 ]]; then
    ask_base_dependencies
    pause_before_next_section
    install_prerequisites
    UI_MODE=""
    detect_ui_mode
    ask_shells
    ask_nerd_fonts
    ask_themes
    [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && ask_oh_my_zsh_plugins
    [[ $INSTALL_STARSHIP -eq 1 ]] && ask_starship_preset
    [[ $INSTALL_OH_MY_POSH -eq 1 ]] && ask_oh_my_posh_theme
    [[ $INSTALL_FISH -eq 1 ]] && ask_fish_plugins

    # ══════════════════════════════════════════════════════════════
    # ETAPA 2: Apps e Ferramentas
    # ══════════════════════════════════════════════════════════════
    ask_terminals
    ask_cli_tools
    ask_ia_tools
    ask_gui_apps
    ask_runtimes
    ask_git_configuration
    ask_ssh_keys

    _auto_enable_configs

    # ══════════════════════════════════════════════════════════════
    # Confirmação Final e Checkpoint
    # ══════════════════════════════════════════════════════════════
    review_selections

    checkpoint_save "install"
  else
    msg "  ⏩ Retomando instalação do checkpoint..."
  fi

  clear_screen
  exec > >(tee -a "$INSTALL_LOG") 2>&1
  step_init 13

  local _shell_desc=""
  [[ ${INSTALL_ZSH:-0} -eq 1 ]] && _shell_desc+="Zsh "
  [[ ${INSTALL_FISH:-0} -eq 1 ]] && _shell_desc+="Fish "
  [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && _shell_desc+="Nushell "
  step_begin "Shells" "${_shell_desc:+${_shell_desc% }}"
  install_selected_shells
  step_end

  step_begin "Ferramentas CLI" "${#SELECTED_CLI_TOOLS[@]} ferramentas selecionadas"
  install_selected_cli_tools
  step_end

  step_begin "Apps GUI"
  install_selected_gui_apps
  step_end

  step_begin "Ferramentas IA" "${#SELECTED_IA_TOOLS[@]} ferramentas selecionadas"
  install_selected_ia_tools
  step_end

  step_begin "Extensões VS Code"
  install_vscode_extensions
  step_end

  step_begin "Configs Compartilhados"
  apply_shared_configs
  step_end

  step_begin "Git" "${GIT_CONFIGURE:+configuracao interativa}"
  install_git_configuration
  step_end

  step_begin "Configs de Plataforma" "${TARGET_OS}"
  case "$TARGET_OS" in
    linux|wsl2) apply_linux_configs ;;
    macos) apply_macos_configs ;;
    windows) apply_windows_configs ;;
  esac
  step_end

  step_begin "Runtimes" "${#SELECTED_RUNTIMES[@]} runtimes selecionados"
  install_selected_runtimes
  step_end

  step_begin "Editores"
  install_selected_editors
  step_end

  step_begin "Fontes Nerd" "${#SELECTED_NERD_FONTS[@]} fontes selecionadas"
  install_nerd_fonts
  step_end

  step_begin "Temas"
  install_selected_themes
  step_end

  step_begin "Padrões do Sistema" "shell e terminal"
  apply_post_install_defaults
  step_end

  clear_screen

  if [[ ${#CRITICAL_ERRORS[@]} -eq 0 ]]; then
    checkpoint_clear
  fi

  print_post_install_report
  POST_INSTALL_REPORT_SHOWN=1

  print_final_summary
}

main "$@"
