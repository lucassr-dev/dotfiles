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
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
TARGET_OS=""
LINUX_PKG_MANAGER=""
LINUX_PKG_UPDATED=0
MODE="install"  # install, export, or sync
FAIL_FAST=1
DRY_RUN="${DRY_RUN:-0}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"
INSTALL_FISH="${INSTALL_FISH:-1}"
INSTALL_BASE_DEPS=1  # Dependências base (pode ser desativado pelo usuário)
INSTALL_VSCODE_EXTENSIONS=0
BASE_DEPS_INSTALLED=0
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

# Parse argumentos da linha de comando
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
  printf '%s\n' "$1"
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
  # Padrão: atualizar itens selecionados quando possível
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
  # Instala/atualiza via Snap, mas evita duplicar se já houver Flatpak ou binário.
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
  # Garantir flathub (idempotente)
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
  # Usa Flatpak só quando o app não está presente via snap/cli; atualiza se já for Flatpak.
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

  # Só faz sentido em ambientes Unix; no Windows CRLF pode ser desejado.
  [[ "${TARGET_OS:-}" == "windows" ]] && return 0

  # Detecta carriage return (CR) e remove de forma portátil (sem sed -i específico por OS)
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
}

set_ssh_permissions() {
  if [[ -d "$HOME/.ssh" ]]; then
    chmod 700 "$HOME/.ssh"
    # Usar find para evitar problemas com globbing e nomes de arquivo com espaços
    find "$HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
    find "$HOME/.ssh" -type d -exec chmod 700 {} + 2>/dev/null || true
  fi
}

# ═══════════════════════════════════════════════════════════
# Seleção Interativa de Apps GUI
# ═══════════════════════════════════════════════════════════

# Arrays globais para armazenar seleções de apps
# shellcheck disable=SC2034
declare -a SELECTED_IDES=()
# shellcheck disable=SC2034
declare -a SELECTED_BROWSERS=()
# shellcheck disable=SC2034
declare -a SELECTED_DEV_TOOLS=()
# shellcheck disable=SC2034
declare -a SELECTED_DATABASES=()
# shellcheck disable=SC2034
declare -a SELECTED_PRODUCTIVITY=()
# shellcheck disable=SC2034
declare -a SELECTED_COMMUNICATION=()
# shellcheck disable=SC2034
declare -a SELECTED_MEDIA=()
# shellcheck disable=SC2034
declare -a SELECTED_UTILITIES=()
# shellcheck disable=SC2034
declare -a SELECTED_RUNTIMES=()
# shellcheck disable=SC2034
INTERACTIVE_GUI_APPS=true

# Variável de controle: se false, não pergunta e instala tudo (comportamento antigo)
INSTALL_BREWFILE=true  # macOS only: instalar apps do Brewfile

# Carregar dados de apps/runtimes
# shellcheck disable=SC1091
if [[ -f "$DATA_APPS" ]]; then
  # shellcheck source=./data/apps.sh
  # shellcheck disable=SC1091
  source "$DATA_APPS"
else
  warn "Arquivo de dados de apps não encontrado: $DATA_APPS"
fi
if [[ -f "$DATA_RUNTIMES" ]]; then
  # shellcheck source=./data/runtimes.sh
  # shellcheck disable=SC1091
  source "$DATA_RUNTIMES"
else
  warn "Arquivo de dados de runtimes não encontrado: $DATA_RUNTIMES"
fi
# Libs
if [[ -f "$SCRIPT_DIR/lib/banner.sh" ]]; then
  # shellcheck source=./lib/banner.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/banner.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/selections.sh" ]]; then
  # shellcheck source=./lib/selections.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/selections.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/nerd_fonts.sh" ]]; then
  # shellcheck source=./lib/nerd_fonts.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/nerd_fonts.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/themes.sh" ]]; then
  # shellcheck source=./lib/themes.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/themes.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/os_linux.sh" ]]; then
  # shellcheck source=./lib/os_linux.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/os_linux.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/os_macos.sh" ]]; then
  # shellcheck source=./lib/os_macos.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/os_macos.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/os_windows.sh" ]]; then
  # shellcheck source=./lib/os_windows.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/os_windows.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/gui_apps.sh" ]]; then
  # shellcheck source=./lib/gui_apps.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/gui_apps.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/app_installers.sh" ]]; then
  # shellcheck source=./lib/app_installers.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/app_installers.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/tools.sh" ]]; then
  # shellcheck source=./lib/tools.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/tools.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/git_config.sh" ]]; then
  # shellcheck source=./lib/git_config.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/git_config.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/runtimes.sh" ]]; then
  # shellcheck source=./lib/runtimes.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/runtimes.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/report.sh" ]]; then
  # shellcheck source=./lib/report.sh
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/report.sh"
fi

# shellcheck disable=SC2329
print_selection_summary() {
  local label="$1"
  shift
  local items=("$@")
  local list="(nenhum)"
  if [[ ${#items[@]} -gt 0 ]]; then
    list="$(printf "%s, " "${items[@]}")"
    list="${list%, }"
  fi
  msg "  • $label: $list"
}

ask_vscode_extensions() {
  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"
  INSTALL_VSCODE_EXTENSIONS=0

  if [[ ! -f "$extensions_file" ]]; then
    return 0
  fi

  show_section_header "🧩 VS Code - Extensões"
  msg "Este script pode aplicar automaticamente suas configurações do VS Code:"
  msg "  • Settings: shared/vscode/settings.json"
  msg "  • Extensões: shared/vscode/extensions.txt"
  msg ""
  msg "Se quiser usar suas próprias configs, edite esses arquivos antes de continuar."
  msg "Dica: você pode abrir e ajustar agora, e depois voltar para esta tela."
  msg ""

  if ask_yes_no "Deseja instalar as extensões do VS Code?"; then
    INSTALL_VSCODE_EXTENSIONS=1
    print_selection_summary "🧩 VS Code Extensions" "instalar"
  else
    print_selection_summary "🧩 VS Code Extensions" "não instalar"
  fi
  msg ""
}

review_selections() {
  local choice=""
  while true; do
    if declare -F clear_screen >/dev/null; then
      clear_screen
    else
      clear
    fi
    msg ""
    msg "╔══════════════════════════════════════════════════════════╗"
    msg "║           RESUMO DAS SELEÇÕES                            ║"
    msg "╚══════════════════════════════════════════════════════════╝"
    msg ""
    print_selection_summary "🐚 Shells" "${INSTALL_ZSH:+zsh}" "${INSTALL_FISH:+fish}"
    [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && print_selection_summary "🎨 Oh My Zsh" "ativado"
    if [[ $INSTALL_STARSHIP -eq 1 ]]; then
      local starship_summary="padrão"
      if [[ -n "${SELECTED_STARSHIP_PRESET:-}" ]]; then
        starship_summary="$SELECTED_STARSHIP_PRESET"
        if [[ -n "${SELECTED_CATPPUCCIN_FLAVOR:-}" ]]; then
          starship_summary+=" (${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_})"
        fi
      fi
      print_selection_summary "✨ Starship" "$starship_summary"
    fi
    [[ $INSTALL_OH_MY_POSH -eq 1 ]] && print_selection_summary "🎭 Oh My Posh" "${SELECTED_OMP_THEME:-padrão}"
    print_selection_summary "💻 Terminais" "${SELECTED_TERMINALS[@]}"
    print_selection_summary "🛠️  CLI Tools" "${SELECTED_CLI_TOOLS[@]}"
    print_selection_summary "🤖 IA Tools" "${SELECTED_IA_TOOLS[@]}"
    print_selection_summary "📦 GUI Apps" "${#SELECTED_IDES[@]} IDEs, ${#SELECTED_BROWSERS[@]} navegadores, ${#SELECTED_DEV_TOOLS[@]} dev tools"
    print_selection_summary "🧩 Runtimes" "${SELECTED_RUNTIMES[@]}"
    if [[ -f "$CONFIG_SHARED/vscode/extensions.txt" ]]; then
      if [[ $INSTALL_VSCODE_EXTENSIONS -eq 1 ]]; then
        print_selection_summary "🧩 VS Code Extensions" "instalar"
      else
        print_selection_summary "🧩 VS Code Extensions" "não instalar"
      fi
    fi
    local ssh_source=""
    if [[ -n "$PRIVATE_SHARED" ]] && [[ -d "$PRIVATE_SHARED/.ssh" ]]; then
      ssh_source="$PRIVATE_SHARED/.ssh"
    elif [[ -d "$CONFIG_SHARED/.ssh" ]]; then
      ssh_source="$CONFIG_SHARED/.ssh"
    fi
    if [[ -n "$ssh_source" ]]; then
      msg ""
      warn "Chaves SSH encontradas em $ssh_source (serão copiadas para ~/.ssh)."
      warn "Confira se você não está commitando chaves privadas: git status"
    fi
    msg ""
    msg "Digite o número da seção para editar."
    msg "Enter ou C para iniciar, S para sair."
    msg "  1) Shells e temas"
    msg "  2) Nerd Fonts"
    msg "  3) Terminais"
    msg "  4) CLI Tools"
    msg "  5) IA Tools"
    msg "  6) GUI Apps"
    msg "  7) Runtimes"
    msg "  8) Git"
    msg "  9) VS Code Extensions"
    msg ""
    read -r -p "👉 " choice
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
        clear
        ask_shells
        clear
        ask_themes
        ask_oh_my_zsh_plugins
        ask_starship_preset
        ask_oh_my_posh_theme
        ask_fish_plugins
        pause_before_next_section
        ;;
      2)
        clear
        ask_nerd_fonts
        pause_before_next_section
        ;;
      3)
        clear
        ask_terminals
        pause_before_next_section
        ;;
      4)
        clear
        ask_cli_tools
        pause_before_next_section
        ;;
      5)
        clear
        ask_ia_tools
        pause_before_next_section
        ;;
      6)
        clear
        ask_gui_apps
        ;;
      7)
        clear
        ask_runtimes
        pause_before_next_section
        ;;
      8)
        clear
        ask_git_configuration
        ;;
      9)
        clear
        ask_vscode_extensions
        pause_before_next_section
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
      # Detectar WSL2 (Windows Subsystem for Linux)
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

# Função auxiliar para verificar se é WSL2
is_wsl2() {
  [[ "$TARGET_OS" == "wsl2" ]]
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
  # Suporte automático apenas para distros baseadas em apt (Ubuntu/Debian)
  detect_linux_pkg_manager
  if has_cmd google-chrome || command -v google-chrome-stable >/dev/null 2>&1 || has_flatpak_ref "com.google.Chrome"; then
    return 0
  fi
  if [[ "$LINUX_PKG_MANAGER" != "apt-get" ]]; then
    record_failure "optional" "Google Chrome (Linux) suportado automaticamente apenas em distros apt; instale manualmente."
    return 0
  fi
  local deb=""
  deb="$(mktemp /tmp/google-chrome-XXXXXX.deb)"
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
  rm -f "$deb"
}

install_brave_linux() {
  if has_cmd brave-browser; then
    return 0
  fi
  if has_cmd flatpak; then
    flatpak_install_or_update com.brave.Browser "Brave" optional
    return 0
  fi
  if has_cmd snap; then
    snap_install_or_refresh brave "Brave" optional
    return 0
  fi
  record_failure "optional" "Brave não instalado: Flatpak/Snap indisponíveis nesta distro."
}

install_zen_linux() {
  if has_cmd zen-browser; then
    return 0
  fi
  if has_cmd flatpak; then
    flatpak_install_or_update io.github.ranfdev.Zen "Zen Browser" optional
    return 0
  fi
  record_failure "optional" "Zen Browser não instalado: Flatpak indisponível nesta distro."
}

install_pgadmin_linux() {
  if has_cmd pgadmin4; then
    return 0
  fi
  if has_cmd flatpak; then
    flatpak_install_or_update org.pgadmin.pgadmin4 "pgAdmin" optional
    return 0
  fi
  record_failure "optional" "pgAdmin não instalado: Flatpak indisponível nesta distro."
}

install_mongodb_linux() {
  if has_cmd mongod || has_cmd mongodb-compass; then
    return 0
  fi
  if has_cmd flatpak; then
    flatpak_install_or_update com.mongodb.Compass "MongoDB Compass" optional
    return 0
  fi
  install_linux_packages optional mongodb 2>/dev/null
}

install_vscode_linux() {
  # Objetivo: garantir VS Code Stable o mais recente possível no Linux.
  # Preferência: instalador oficial (latest .deb/.rpm). Fallback: snap/flatpak.

  # Se já estiver instalado via Snap, apenas atualiza no canal stable.
  if has_snap_pkg code; then
    msg "  🔄 Atualizando VS Code via snap (stable)..."
    if run_with_sudo snap refresh code --channel=stable >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: snap refresh (stable)")
    else
      record_failure "optional" "Falha ao atualizar VS Code via snap"
    fi
    return 0
  fi

  # Se já estiver instalado via Flatpak, apenas atualiza.
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

  # Preferir pacotes oficiais do site (sempre apontam para o último stable).
  if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
    if has_cmd code; then
      msg "  🔄 Atualizando VS Code (deb oficial)..."
    else
      msg "  📦 Instalando VS Code (deb oficial)..."
    fi

    local deb=""
    deb="$(mktemp /tmp/vscode-XXXXXX.deb)"
    if curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o "$deb"; then
      if run_with_sudo dpkg -i "$deb" >/dev/null 2>&1; then
        INSTALLED_MISC+=("vscode: deb oficial (stable)")
      else
        # Resolver dependências quebradas (dpkg -i pode falhar por deps)
        run_with_sudo apt-get install -f -y >/dev/null 2>&1 || true
        if run_with_sudo dpkg -i "$deb" >/dev/null 2>&1; then
          INSTALLED_MISC+=("vscode: deb oficial (stable)")
        else
          record_failure "optional" "Falha ao instalar VS Code (deb)"
        fi
      fi
      rm -f "$deb" >/dev/null 2>&1 || true
      return 0
    fi
    rm -f "$deb" >/dev/null 2>&1 || true
    record_failure "optional" "Falha ao baixar VS Code (deb oficial)"
  fi

  if [[ "$LINUX_PKG_MANAGER" == "dnf" ]]; then
    msg "  📦 Instalando VS Code (rpm oficial via dnf)..."
    if run_with_sudo dnf install -y "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: rpm oficial (stable)")
    else
      record_failure "optional" "Falha ao instalar VS Code via dnf (rpm oficial)"
    fi
    return 0
  fi

  if [[ "$LINUX_PKG_MANAGER" == "zypper" ]]; then
    msg "  📦 Instalando VS Code (rpm oficial via zypper)..."
    if run_with_sudo zypper install -y "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" >/dev/null 2>&1; then
      INSTALLED_MISC+=("vscode: rpm oficial (stable)")
    else
      record_failure "optional" "Falha ao instalar VS Code via zypper (rpm oficial)"
    fi
    return 0
  fi

  # Fallbacks quando não dá pra usar .deb/.rpm.
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
  # Preferência: Homebrew cask (bem mantido). Fallback: não automatizado.

  if has_cmd brew; then
    msg "  🍺 VS Code via Homebrew..."
    if brew list --cask visual-studio-code >/dev/null 2>&1; then
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
  # Preferência: winget (upgrade/install). Fallback: Chocolatey.

  if has_cmd winget; then
    local id="Microsoft.VisualStudioCode"
    local result=""
    result="$(winget list --id "$id" 2>/dev/null || true)"
    if [[ "$result" == *"$id"* ]]; then
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

# shellcheck disable=SC2329
install_php_build_deps_linux() {
  # Dependências de build necessárias para compilar PHP (mise/asdf-php).
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

# shellcheck disable=SC2329
install_php_build_deps_macos() {
  # Dependências de build necessárias para compilar PHP (mise/asdf-php) no macOS.
  # Evitamos instalá-las sempre; só chamamos quando o runtime PHP é selecionado.
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

# shellcheck disable=SC2329
install_php_windows() {
  # Preferir binário pronto no Windows (winget/choco) em vez de compilar via mise.
  local installed=0
  if has_cmd winget; then
    # Tenta a versão genérica (latest) e depois uma específica.
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

# shellcheck disable=SC2329
install_composer_and_laravel() {
  # Instala Composer (via mise) e Laravel installer (via Composer global) se ainda não existirem.
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
      # Garantir que o binário global esteja acessível (via symlink em ~/.local/bin)
      local bin_dir=""
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

ensure_rust_cargo() {
  if has_cmd cargo; then
    return 0
  fi

  msg "▶ Rust/Cargo não encontrado. Instalando..."

  if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null 2>&1; then
    # Adicionar cargo ao PATH da sessão atual
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
    return
  fi

  msg "▶ Ghostty não encontrado. Tentando instalar..."

  # Detectar distro
  local distro=""
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
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
        echo "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null || echo "bookworm") main" | run_with_sudo tee /etc/apt/sources.list.d/debian.griffo.io.list >/dev/null
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

  # Fallback: Tentar Flatpak
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

  # Fallback: Tentar Snap
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

  # Tentar via script oficial
  if curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; then
    # Adicionar uv ao PATH da sessão atual
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("uv: installer script")
    msg "  ✅ uv instalado com sucesso"

    # Gerar completions para shells
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

# shellcheck disable=SC2329
ensure_mise() {
  if has_cmd mise; then
    return 0
  fi

  msg "▶ mise (runtime manager) não encontrado. Instalando..."

  # Em macOS, preferir Homebrew quando disponível
  if [[ "${TARGET_OS:-}" == "macos" ]] && has_cmd brew; then
    if brew install mise >/dev/null 2>&1; then
      INSTALLED_PACKAGES+=("brew: mise (install)")
      msg "  ✅ mise instalado via Homebrew"
      return 0
    fi
  fi

  # Fallback cross-platform: instalador standalone
  if curl -fsSL https://mise.run | sh >/dev/null 2>&1; then
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("mise: installer script")
    msg "  ✅ mise instalado com sucesso"
    return 0
  fi

  record_failure "critical" "Falha ao instalar mise. Instale manualmente (https://mise.jdx.dev/installing-mise.html)."
  return 1
}

ensure_spec_kit() {
  # Verificar se uv está instalado (necessário para spec-kit)
  if ! has_cmd uv; then
    record_failure "optional" "uv não encontrado. spec-kit precisa de uv instalado."
    msg "  💡 Execute: curl -LsSf https://astral.sh/uv/install.sh | sh"
    return 1
  fi

  # Verificar se specify já está instalado
  if has_cmd specify; then
    local spec_version
    spec_version="$(specify --version 2>/dev/null | head -n1 || echo 'unknown')"
    msg "  ℹ️  spec-kit já instalado: $spec_version"

    # Oferecer atualização se estiver desatualizado
    if uv tool list 2>/dev/null | grep -q "specify-cli"; then
      msg "  💡 Para atualizar: uv tool upgrade specify-cli"
    fi
    return 0
  fi

  msg "▶ spec-kit (Spec-Driven Development) não encontrado. Instalando..."
  msg "  📚 Spec-Kit: Toolkit do GitHub para desenvolvimento guiado por especificações"
  msg "  🤖 Integra com Claude para gerar especificações e implementações"

  # Instalar spec-kit via uv tool
  local install_output
  install_output="$(uv tool install specify-cli --from git+https://github.com/github/spec-kit.git 2>&1)"
  local install_status=$?

  if [[ $install_status -eq 0 ]]; then
    # Adicionar ao PATH da sessão atual
    export PATH="$HOME/.local/bin:$PATH"

    # Verificar se o comando está disponível agora
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

  # Tentar via script oficial
  if curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --yes >/dev/null 2>&1; then
    # Adicionar atuin ao PATH da sessão atual
    export PATH="$HOME/.atuin/bin:$PATH"
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("atuin: installer script")
    msg "  ✅ Atuin instalado com sucesso"
    msg "  💡 Atuin sincroniza histórico de comandos entre máquinas"
    msg "  💡 Use 'atuin register' para criar conta e sincronizar"
    msg "  💡 Use 'atuin login' se já tiver conta"

    # Gerar completions e configuração para shells
    if has_cmd fish && [[ -d "$HOME/.config/fish" ]]; then
      # Adicionar init do atuin no config.fish se não existir
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

    if has_cmd zsh && [[ -f "$HOME/.zshrc" ]]; then
      # Adicionar init do atuin no .zshrc se não existir
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
    record_failure "critical" "Falha ao instalar Atuin. Tente manualmente: curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh"
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
  if is_truthy "$INSTALL_FISH" && has_cmd fish; then
    copy_dir "$CONFIG_SHARED/fish" "$HOME/.config/fish"
    normalize_crlf_to_lf "$HOME/.config/fish/config.fish"
  else
    msg "  ⚠️ Fish não selecionado/encontrado, pulando config."
  fi

  if is_truthy "$INSTALL_ZSH" && has_cmd zsh; then
    copy_file "$CONFIG_SHARED/zsh/.zshrc" "$HOME/.zshrc"
    normalize_crlf_to_lf "$HOME/.zshrc"
    if [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]]; then
      copy_file "$CONFIG_SHARED/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
    else
      msg "  ⚠️ Powerlevel10k não encontrado em ~/.oh-my-zsh, pulando .p10k.zsh."
    fi
  else
    msg "  ⚠️ Zsh não selecionado/encontrado, pulando .zshrc."
  fi

  # Starship config será aplicado durante install_starship() após seleção do preset

  if has_cmd git; then
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
  else
    msg "  ⚠️ Git não encontrado, pulando .gitconfig."
  fi

  if has_cmd mise; then
    copy_dir "$CONFIG_SHARED/mise" "$HOME/.config/mise"
  else
    msg "  ⚠️ Mise não encontrado, pulando config."
  fi

  if has_cmd nvim; then
    copy_dir "$CONFIG_SHARED/nvim" "$HOME/.config/nvim"
  else
    msg "  ⚠️ Neovim não encontrado, pulando config."
  fi

  if has_cmd tmux; then
    copy_file "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf"
  else
    msg "  ⚠️ tmux não encontrado, pulando .tmux.conf."
  fi

  copy_vscode_settings

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
}



copy_vscode_settings() {
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
  copy_dir "$source_dir/ghostty" "$HOME/.config/ghostty"
}

apply_macos_configs() {
  local source_dir="$CONFIG_MACOS"
  [[ -d "$source_dir" ]] || source_dir="$CONFIG_UNIX_LEGACY"
  [[ -d "$source_dir" ]] || return
  msg "▶ Copiando configs macOS"

  # Ghostty terminal
  copy_dir "$source_dir/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty"

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
  copy_windows_terminal_settings
  copy_windows_powershell_profiles
}

copy_windows_terminal_settings() {
  local wt_settings="$CONFIG_WINDOWS/windows-terminal-settings.json"
  [[ -f "$wt_settings" ]] || return
  local base="${LOCALAPPDATA:-}"
  if [[ -z "$base" ]]; then
    base="$HOME/AppData/Local"
  fi
  if [[ -z "$base" ]]; then
    msg "  ⚠️ LOCALAPPDATA não definido; pulando Windows Terminal."
    return
  fi

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
      # Priorizar wslpath (WSL2) sobre cygpath (Cygwin/MSYS2)
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

  if [[ $INSTALL_VSCODE_EXTENSIONS -ne 1 ]]; then
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
    # Pular linhas vazias e comentários
    [[ -z "$extension" ]] && continue
    [[ "$extension" =~ ^# ]] && continue

    # Verificar se já está instalado (case-insensitive)
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
  • Backups automáticos são criados em ~/.dotfiles-backup-*
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
    pause_before_next_section "Pressione Enter para começar a configuração..."
  fi

  # Modo INSTALL (padrão) - Repositório -> Sistema
  clear
  msg "╔══════════════════════════════════════╗"
  msg "║   Instalando configs do diretório    ║"
  msg "╚══════════════════════════════════════╝"
  msg "Origem: $SCRIPT_DIR"
  msg "Destino: $HOME"
  msg "Sistema: $TARGET_OS"

  # Criar backup se necessário
  if [[ -f "$HOME/.zshrc" ]] || [[ -d "$HOME/.config/fish" ]]; then
    msg "📦 Backup será criado em: $BACKUP_DIR"
  fi
  msg ""

  # ══════════════════════════════════════════════════════════════
  # ETAPA 1: Seleções Essenciais
  # ══════════════════════════════════════════════════════════════

  # Tela de dependências base (informativa - apenas Enter)
  ask_base_dependencies
  pause_before_next_section
  install_prerequisites

  # Shells (obrigatório - Zsh/Fish/Ambos)
  clear
  ask_shells
  pause_before_next_section

  # Temas (baseado nos shells) + Plugins/Presets (SEM pause entre eles)
  clear
  ask_themes

  # Plugins e Presets (IMEDIATAMENTE após selecionar os temas, na mesma sessão)
  if [[ $INSTALL_OH_MY_ZSH -eq 1 ]]; then
    clear
    ask_oh_my_zsh_plugins
  fi
  if [[ $INSTALL_STARSHIP -eq 1 ]]; then
    clear
    ask_starship_preset
  fi
  if [[ $INSTALL_OH_MY_POSH -eq 1 ]]; then
    clear
    ask_oh_my_posh_theme
  fi
  if [[ $INSTALL_FISH -eq 1 ]]; then
    clear
    ask_fish_plugins
  fi
  pause_before_next_section

  # Nerd Fonts (essenciais para temas funcionarem corretamente)
  clear
  ask_nerd_fonts
  pause_before_next_section

  # ══════════════════════════════════════════════════════════════
  # ETAPA 2: Apps e Ferramentas
  # ══════════════════════════════════════════════════════════════

  # Terminais
  clear
  ask_terminals
  pause_before_next_section

  # CLI Tools (ferramentas modernas de linha de comando)
  clear
  ask_cli_tools
  pause_before_next_section

  # IA Tools
  clear
  ask_ia_tools
  pause_before_next_section

  # GUI Apps
  clear
  ask_gui_apps

  # VS Code Extensions
  if [[ -f "$CONFIG_SHARED/vscode/extensions.txt" ]]; then
    clear
    ask_vscode_extensions
    pause_before_next_section
  fi

  # Runtimes (Node/Python/PHP/etc via mise)
  clear
  ask_runtimes
  pause_before_next_section

  # Git Configuration
  clear
  ask_git_configuration

  # ══════════════════════════════════════════════════════════════
  # Confirmação Final
  # ══════════════════════════════════════════════════════════════
  review_selections

  # Instalar dependências base (sempre necessário)
  install_prerequisites

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

  # Instalar Nerd Fonts selecionadas
  install_nerd_fonts

  # Instalar temas selecionados
  install_selected_themes

  print_post_install_report

  print_final_summary
}

main "$@"
