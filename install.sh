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
CONFIG_UNIX_LEGACY="$SCRIPT_DIR/mac-linux"
DATA_APPS="$SCRIPT_DIR/data/apps.sh"
DATA_RUNTIMES="$SCRIPT_DIR/data/runtimes.sh"
BACKUP_DIR="$HOME/.bkp-$(date +%Y%m%d-%H%M)"
TARGET_OS=""
LINUX_PKG_MANAGER=""
LINUX_PKG_UPDATED=0
MODE="install"
FAIL_FAST="${FAIL_FAST:-0}"
DRY_RUN="${DRY_RUN:-0}"
SCRIPT_VERSION="1.0.0"
VERBOSE="${VERBOSE:-0}"
QUIET="${QUIET:-0}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"
INSTALL_FISH="${INSTALL_FISH:-1}"
INSTALL_NUSHELL="${INSTALL_NUSHELL:-0}"
INSTALL_BASE_DEPS=1
BASE_DEPS_INSTALLED=0

COPY_ZSH_CONFIG=1
COPY_FISH_CONFIG=1
COPY_NUSHELL_CONFIG=1
COPY_GIT_CONFIG=1
COPY_NVIM_CONFIG=1
COPY_TMUX_CONFIG=1
COPY_TERMINAL_CONFIG=1
COPY_MISE_CONFIG=1
COPY_STARSHIP_CONFIG=1
COPY_SSH_KEYS=0
COPY_VSCODE_SETTINGS=1
COPY_LAZYGIT_CONFIG=1
COPY_YAZI_CONFIG=1
COPY_BTOP_CONFIG=1
COPY_KITTY_CONFIG=1
COPY_ALACRITTY_CONFIG=1
COPY_WEZTERM_CONFIG=1
COPY_RIPGREP_CONFIG=1
COPY_NPM_CONFIG=1
COPY_PNPM_CONFIG=1
COPY_YARN_CONFIG=1
COPY_PIP_CONFIG=1
COPY_CARGO_CONFIG=1
COPY_ZED_CONFIG=1
COPY_HELIX_CONFIG=1
COPY_AIDER_CONFIG=1
COPY_DOCKER_CONFIG=1
COPY_DIRENV_CONFIG=1

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
    c='\033[0;36m' b='\033[1m' r='\033[0m'
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
  echo -e "  ${c}-q${r}, ${c}--quiet${r}         Saida reduzida"
  echo -e "  ${c}--verbose${r}           Saida detalhada"
  echo -e "  ${c}--no-color${r}          Desativar cores (equivale a NO_COLOR=1)"
  echo ""
  echo -e "${b}Variaveis de ambiente:${r}"
  echo -e "  DRY_RUN=1           Mesmo que --dry-run"
  echo -e "  NO_COLOR=1          Mesmo que --no-color"
  echo -e "  FORCE_UI_MODE=bash  Forcar modo de UI (fzf/gum/bash)"
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
    -q|--quiet) QUIET=1 ;;
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

msg() {
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

ensure_snap_app() {
  local pkg="$1"
  local friendly="$2"
  local flatpak_ref="${3:-}"
  local cmd="${4:-}"
  local level="${5:-optional}"
  shift 5 2>/dev/null || true
  local snap_args=("$@")

  has_cmd snap || return 0

  if [[ -n "$flatpak_ref" ]] && has_flatpak_ref "$flatpak_ref"; then
    msg "  ℹ️  $friendly já instalado via Flatpak ($flatpak_ref); pulando Snap."
    return 0
  fi

  if [[ -n "$cmd" ]] && has_cmd "$cmd"; then
    msg "  ℹ️  $friendly já está disponível no sistema ($cmd); pulando Snap."
    return 0
  fi

  snap_install_or_refresh "$pkg" "$friendly" "$level" "${snap_args[@]}"
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
  local fix_hint="${3:-}"
  if [[ "$level" == "critical" ]]; then
    CRITICAL_ERRORS+=("$message")
    warn "❌ $message"
    [[ -n "$fix_hint" ]] && warn "💡 $fix_hint"
    if [[ "$FAIL_FAST" -eq 1 ]]; then
      print_final_summary 1
    fi
  else
    OPTIONAL_ERRORS+=("$message")
    warn "$message"
    [[ -n "$fix_hint" ]] && warn "💡 $fix_hint"
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
  apt_pkg=$(echo "$sources" | grep -oP 'apt:\K[^,]+' || true)
  snap_pkg=$(echo "$sources" | grep -oP 'snap:\K[^, ]+' || true)
  flatpak_ref=$(echo "$sources" | grep -oP 'flatpak:\K[^,]+' || true)
  brew_pkg=$(echo "$sources" | grep -oP 'brew:\K[^,]+' || true)
  winget_pkg=$(echo "$sources" | grep -oP 'winget:\K[^,]+' || true)
  choco_pkg=$(echo "$sources" | grep -oP 'choco:\K[^,]+' || true)
  scoop_pkg=$(echo "$sources" | grep -oP 'scoop:\K[^,]+' || true)

  # Linux: dpkg, rpm, snap, flatpak
  [[ -n "$apt_pkg" ]] && has_cmd dpkg && dpkg -l "$apt_pkg" 2>/dev/null | grep -q '^ii' && return 0
  [[ -n "$apt_pkg" ]] && has_cmd rpm && rpm -q "$apt_pkg" >/dev/null 2>&1 && return 0
  [[ -n "$snap_pkg" ]] && has_snap_pkg "$snap_pkg" && return 0
  [[ -n "$flatpak_ref" ]] && has_flatpak_ref "$flatpak_ref" && return 0

  # macOS: brew (cask + formula)
  if [[ -n "$brew_pkg" ]] && has_cmd brew; then
    brew list --cask "$brew_pkg" &>/dev/null && return 0
    brew list "$brew_pkg" &>/dev/null && return 0
  fi

  # Windows: winget, choco, scoop
  [[ -n "$winget_pkg" ]] && has_cmd winget && winget list --id "$winget_pkg" 2>/dev/null | grep -q "$winget_pkg" && return 0
  [[ -n "$choco_pkg" ]] && has_cmd choco && choco list --local-only "$choco_pkg" 2>/dev/null | grep -q "$choco_pkg" && return 0
  [[ -n "$scoop_pkg" ]] && has_cmd scoop && scoop list 2>/dev/null | grep -q "$scoop_pkg" && return 0

  return 1
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

source "$SCRIPT_DIR/lib/fileops.sh"

get_ssh_key_fingerprint() {
  local key_file="$1"
  if [[ -f "$key_file" ]]; then
    ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $2}' || echo "unknown"
  else
    echo "not_a_key"
  fi
}

get_ssh_key_comment() {
  local key_file="$1"
  if [[ -f "$key_file" ]] && [[ "$key_file" == *.pub ]]; then
    awk '{print $NF}' "$key_file" 2>/dev/null
    return
  elif [[ -f "${key_file}.pub" ]]; then
    awk '{print $NF}' "${key_file}.pub" 2>/dev/null
    return
  fi
  echo ""
}

_ssh_print_key_preview() {
  local label="$1" key_file="$2"
  if [[ -f "$key_file" ]]; then
    local fp comment key_type
    fp=$(get_ssh_key_fingerprint "$key_file")
    comment=$(get_ssh_key_comment "$key_file")
    key_type=$(ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $NF}' | tr -d '()')
    echo -e "    ${UI_MUTED}${label}:${UI_RESET}"
    echo -e "      ${UI_MUTED}Tipo:${UI_RESET}        ${UI_TEXT}${key_type:-desconhecido}${UI_RESET}"
    echo -e "      ${UI_MUTED}Fingerprint:${UI_RESET} ${UI_TEXT}${fp}${UI_RESET}"
    [[ -n "$comment" ]] && echo -e "      ${UI_MUTED}Comentário:${UI_RESET}  ${UI_TEXT}${comment}${UI_RESET}"
    if [[ "$key_file" == *.pub ]]; then
      local pub_content
      pub_content=$(head -c 80 "$key_file" 2>/dev/null)
      echo -e "      ${UI_MUTED}Pub:${UI_RESET}         ${UI_DIM}${pub_content}...${UI_RESET}"
    fi
  fi
}

_ssh_resolve_conflict() {
  local key_name="$1" src_path="$2" dest_path="$3" ssh_dest="$4"

  echo ""
  echo -e "  ${UI_WARNING}${UI_BOLD}Conflito:${UI_RESET} ${UI_TEXT}${key_name}${UI_RESET} ${UI_MUTED}já existe em ~/.ssh/${UI_RESET}"
  echo ""

  _ssh_print_key_preview "Backup (origem)" "$src_path"
  echo ""
  _ssh_print_key_preview "Sistema (destino)" "$dest_path"
  echo ""

  echo -e "  ${UI_PEACH}${UI_BOLD}S${UI_RESET} ${UI_TEXT}Substituir${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_SKY}${UI_BOLD}R${UI_RESET} ${UI_TEXT}Renomear${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_RED}${UI_BOLD}D${UI_RESET} ${UI_TEXT}Deletar existente${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_DIM}P${UI_RESET} ${UI_TEXT}Pular${UI_RESET}"
  local ssh_choice
  read -r -p "  → " ssh_choice
  case "${ssh_choice,,}" in
    s|substituir)
      cp "$src_path" "$dest_path"
      [[ -f "${src_path}.pub" ]] && cp "${src_path}.pub" "${dest_path}.pub"
      echo -e "  ${UI_GREEN}✓ Substituído: ${key_name}${UI_RESET}"
      ;;
    r|renomear)
      local new_name=""
      while true; do
        read -r -p "  Novo nome (ex: id_ed25519_work): " new_name
        [[ -z "$new_name" ]] && { echo -e "  ${UI_WARNING}Nome não pode ser vazio.${UI_RESET}"; continue; }
        [[ -f "$ssh_dest/$new_name" ]] && { echo -e "  ${UI_WARNING}${new_name} já existe.${UI_RESET}"; continue; }
        break
      done
      cp "$src_path" "$ssh_dest/$new_name"
      [[ -f "${src_path}.pub" ]] && cp "${src_path}.pub" "$ssh_dest/${new_name}.pub"
      echo -e "  ${UI_GREEN}✓ Copiado como: ${new_name}${UI_RESET}"
      ;;
    d|deletar)
      rm -f "$dest_path" "${dest_path}.pub"
      cp "$src_path" "$dest_path"
      [[ -f "${src_path}.pub" ]] && cp "${src_path}.pub" "${dest_path}.pub"
      echo -e "  ${UI_GREEN}✓ Existente removido e substituído: ${key_name}${UI_RESET}"
      ;;
    *)
      echo -e "  ${UI_MUTED}⏭ Mantido: ${key_name} (original preservado)${UI_RESET}"
      ;;
  esac
}

manage_ssh_keys() {
  local ssh_source="$1"
  local ssh_dest="$HOME/.ssh"

  mkdir -p "$ssh_dest"

  # Coletar apenas chaves privadas e arquivos de config (não .pub separados)
  local source_keys=()
  while IFS= read -r -d '' key; do
    source_keys+=("$key")
  done < <(find "$ssh_source" -type f \( -name "id_*" ! -name "*.pub" \) -o -name "known_hosts*" -o -name "config" 2>/dev/null | sort -z 2>/dev/null)
  # Fallback com -print0 se sort -z falhar
  if [[ ${#source_keys[@]} -eq 0 ]]; then
    while IFS= read -r -d '' key; do
      source_keys+=("$key")
    done < <(find "$ssh_source" -type f \( -name "id_*" ! -name "*.pub" -o -name "known_hosts*" -o -name "config" \) -print0 2>/dev/null)
  fi

  if [[ ${#source_keys[@]} -eq 0 ]]; then
    echo -e "  ${UI_INFO}ℹ Nenhuma chave SSH encontrada em ${ssh_source}${UI_RESET}"
    return
  fi

  # Mapear fingerprints existentes no destino
  declare -A dest_fingerprints
  if [[ -d "$ssh_dest" ]]; then
    while IFS= read -r -d '' existing_key; do
      local fp
      fp=$(get_ssh_key_fingerprint "$existing_key")
      [[ "$fp" != "unknown" ]] && [[ "$fp" != "not_a_key" ]] && dest_fingerprints["$fp"]="$existing_key"
    done < <(find "$ssh_dest" -type f \( -name "id_*" ! -name "*.pub" \) -print0 2>/dev/null)
  fi

  # ── Exibir chaves encontradas ──
  echo ""
  echo -e "  ${UI_ACCENT}${UI_BOLD}▸ Chaves SSH${UI_RESET}"
  echo -e "  ${UI_BORDER}────────────────${UI_RESET}"
  echo ""

  local has_conflict=0
  for key_path in "${source_keys[@]}"; do
    local key_name
    key_name=$(basename "$key_path")
    local fp
    fp=$(get_ssh_key_fingerprint "$key_path")

    [[ "$fp" == "not_a_key" ]] && continue

    local comment
    comment=$(get_ssh_key_comment "$key_path")
    local status_icon="${UI_GREEN}●${UI_RESET}"
    local status_text=""
    local dest_path="$ssh_dest/$key_name"

    if [[ -f "$dest_path" ]]; then
      status_icon="${UI_WARNING}●${UI_RESET}"
      status_text=" ${UI_DIM}(conflito)${UI_RESET}"
      has_conflict=1
    elif [[ "$fp" != "unknown" ]] && [[ -n "${dest_fingerprints[$fp]:-}" ]]; then
      local existing_name
      existing_name=$(basename "${dest_fingerprints[$fp]}")
      status_icon="${UI_WARNING}●${UI_RESET}"
      status_text=" ${UI_DIM}(duplica ${existing_name})${UI_RESET}"
      has_conflict=1
    fi

    echo -e "  ${status_icon} ${UI_TEXT}${UI_BOLD}${key_name}${UI_RESET}${status_text}"
    [[ -n "$comment" ]] && echo -e "    ${UI_MUTED}${comment}${UI_RESET}"
    [[ "$fp" != "unknown" ]] && echo -e "    ${UI_DIM}${fp}${UI_RESET}"
  done

  echo ""
  [[ $has_conflict -eq 1 ]] && echo -e "  ${UI_WARNING}⚠ Chaves com conflito serão tratadas individualmente${UI_RESET}" && echo ""

  if ! ui_confirm "Deseja copiar as chaves SSH?"; then
    echo -e "  ${UI_MUTED}⏭ Cópia de chaves SSH cancelada${UI_RESET}"
    return 1
  fi

  echo ""

  # ── Copiar chaves ──
  for key_path in "${source_keys[@]}"; do
    local key_name
    key_name=$(basename "$key_path")
    local dest_path="$ssh_dest/$key_name"
    local fp
    fp=$(get_ssh_key_fingerprint "$key_path")

    [[ "$fp" == "not_a_key" ]] && continue

    # Conflito por fingerprint (nome diferente, mesma chave)
    if [[ "$fp" != "unknown" ]] && [[ -n "${dest_fingerprints[$fp]:-}" ]]; then
      local existing_path="${dest_fingerprints[$fp]}"
      local existing_name
      existing_name=$(basename "$existing_path")

      if [[ "$existing_name" != "$key_name" ]]; then
        echo -e "  ${UI_WARNING}${key_name} duplica ${existing_name}${UI_RESET} ${UI_DIM}(mesmo fingerprint)${UI_RESET}"
        _ssh_resolve_conflict "$existing_name" "$key_path" "$existing_path" "$ssh_dest"
        continue
      fi
    fi

    # Conflito por nome
    if [[ -f "$dest_path" ]]; then
      _ssh_resolve_conflict "$key_name" "$key_path" "$dest_path" "$ssh_dest"
      continue
    fi

    # Sem conflito — copiar diretamente
    cp "$key_path" "$dest_path"
    [[ -f "${key_path}.pub" ]] && cp "${key_path}.pub" "${dest_path}.pub"
    echo -e "  ${UI_GREEN}✓ Copiado: ${key_name}${UI_RESET}"
  done
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

tool_config_exists() {
  local file="$1"
  local line="$2"

  [[ ! -f "$file" ]] && return 1
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

extract_user_path_config_zsh() {
  local zshrc="$HOME/.zshrc"
  [[ -f "$zshrc" ]] || return

  local preserved_lines=()
  local prev_line=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    case "$line" in
      *"NVM_DIR"*|*"nvm.sh"*|*"nvm bash_completion"*|*'$NVM_DIR'*)
        preserved_lines+=("$line")
        ;;
      *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*|*"/Android/Sdk"*|*"/android"*"/tools"*|*"/platform-tools"*)
        preserved_lines+=("$line")
        ;;
      *"SDKMAN_DIR"*|*"sdkman-init.sh"*|*".sdkman"*)
        preserved_lines+=("$line")
        ;;
      *"PYENV_ROOT"*|*"pyenv init"*|*'$PYENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      *"RBENV_ROOT"*|*"rbenv init"*|*'$RBENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      *"JAVA_HOME"*|*"JDK_HOME"*|*'$JAVA_HOME'*)
        preserved_lines+=("$line")
        ;;
      *"GOPATH"*|*"GOROOT"*|*"/go/bin"*|*'$GOPATH'*|*'$GOROOT'*)
        preserved_lines+=("$line")
        ;;
      *".yarn/bin"*|*".config/yarn"*|*"yarn global"*)
        preserved_lines+=("$line")
        ;;
      *"PNPM_HOME"*|*".local/share/pnpm"*|*'$PNPM_HOME'*)
        preserved_lines+=("$line")
        ;;
      *"BUN_INSTALL"*|*".bun/bin"*|*'$BUN_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      *"DENO_INSTALL"*|*".deno/bin"*|*'$DENO_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      *"FLUTTER_HOME"*|*"flutter/bin"*|*'$FLUTTER_HOME'*)
        preserved_lines+=("$line")
        ;;
      *"DOTNET_ROOT"*|*".dotnet"*|*'$DOTNET_ROOT'*)
        preserved_lines+=("$line")
        ;;
      *".cargo/env"*|*"CARGO_HOME"*|*"RUSTUP_HOME"*)
        ;;
      *"/home/linuxbrew"*|*"HOMEBREW_PREFIX"*|*'$HOMEBREW_PREFIX'*)
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
      *"NVM_DIR"*|*"nvm.fish"*|*"bass"*"nvm"*|*'$NVM_DIR'*)
        preserved_lines+=("$line")
        ;;
      *"ANDROID_HOME"*|*"ANDROID_SDK_ROOT"*|*"/Android/Sdk"*|*"/android"*"/tools"*|*"/platform-tools"*)
        preserved_lines+=("$line")
        ;;
      *"SDKMAN_DIR"*|*"sdkman"*|*".sdkman"*)
        preserved_lines+=("$line")
        ;;
      *"PYENV_ROOT"*|*"pyenv init"*|*'$PYENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      *"RBENV_ROOT"*|*"rbenv init"*|*'$RBENV_ROOT'*)
        preserved_lines+=("$line")
        ;;
      *"JAVA_HOME"*|*"JDK_HOME"*|*'$JAVA_HOME'*)
        preserved_lines+=("$line")
        ;;
      *"GOPATH"*|*"GOROOT"*|*"/go/bin"*|*'$GOPATH'*|*'$GOROOT'*)
        preserved_lines+=("$line")
        ;;
      *".yarn/bin"*|*".config/yarn"*|*"yarn global"*)
        preserved_lines+=("$line")
        ;;
      *"PNPM_HOME"*|*".local/share/pnpm"*|*'$PNPM_HOME'*)
        preserved_lines+=("$line")
        ;;
      *"BUN_INSTALL"*|*".bun/bin"*|*'$BUN_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      *"DENO_INSTALL"*|*".deno/bin"*|*'$DENO_INSTALL'*)
        preserved_lines+=("$line")
        ;;
      *"FLUTTER_HOME"*|*"flutter/bin"*|*'$FLUTTER_HOME'*)
        preserved_lines+=("$line")
        ;;
      *"DOTNET_ROOT"*|*".dotnet"*|*'$DOTNET_ROOT'*)
        preserved_lines+=("$line")
        ;;
      *"/home/linuxbrew"*|*"HOMEBREW_PREFIX"*|*'$HOMEBREW_PREFIX'*)
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
INSTALL_BREWFILE=true

[[ -f "$DATA_APPS" ]] && source "$DATA_APPS" || warn "Arquivo de dados de apps não encontrado: $DATA_APPS"
[[ -f "$DATA_RUNTIMES" ]] && source "$DATA_RUNTIMES" || warn "Arquivo de dados de runtimes não encontrado: $DATA_RUNTIMES"

[[ -f "$SCRIPT_DIR/lib/colors.sh" ]] && source "$SCRIPT_DIR/lib/colors.sh"
[[ -f "$SCRIPT_DIR/lib/utils.sh" ]] && source "$SCRIPT_DIR/lib/utils.sh"
[[ -f "$SCRIPT_DIR/lib/components.sh" ]] && source "$SCRIPT_DIR/lib/components.sh"
[[ -f "$SCRIPT_DIR/lib/ui.sh" ]] && source "$SCRIPT_DIR/lib/ui.sh"
detect_terminal_capabilities
detect_ui_mode
[[ -f "$SCRIPT_DIR/lib/banner.sh" ]] && source "$SCRIPT_DIR/lib/banner.sh"
[[ -f "$SCRIPT_DIR/lib/selections.sh" ]] && source "$SCRIPT_DIR/lib/selections.sh"
[[ -f "$SCRIPT_DIR/lib/nerd_fonts.sh" ]] && source "$SCRIPT_DIR/lib/nerd_fonts.sh"
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

_truncate_text() {
  local width="$1" text="$2"
  if [[ $width -le 0 ]]; then
    printf ''
    return
  fi
  local visual
  visual=$(_visible_len "$text")
  if [[ $visual -le $width ]]; then
    printf '%s' "$text"
    return
  fi
  if [[ $width -le 3 ]]; then
    printf '%s' "${text:0:$width}"
    return
  fi
  printf '%s...' "${text:0:$((width - 3))}"
}

_truncate_items() {
  local max_width="$1"
  shift
  local items=("$@")
  local total=${#items[@]}

  if [[ $total -eq 0 ]]; then
    echo "(nenhum)"
    return
  fi

  if [[ $max_width -le 0 ]]; then
    echo "(...)"
    return
  fi

  local result=""
  local included=0
  local i=0
  for ((i=0; i<total; i++)); do
    local candidate="${items[i]}"
    [[ -n "$result" ]] && candidate="$result, ${items[i]}"
    local remaining_after=$((total - i - 1))
    local suffix=""
    [[ $remaining_after -gt 0 ]] && suffix=" +${remaining_after}"

    if [[ $(_visible_len "${candidate}${suffix}") -le $max_width ]]; then
      result="$candidate"
      included=$((i + 1))
    else
      break
    fi
  done

  if [[ $included -eq $total ]]; then
    echo "$result"
    return
  fi

  if [[ $included -eq 0 ]]; then
    local omitted=$((total - 1))
    local suffix=""
    [[ $omitted -gt 0 ]] && suffix=" +${omitted}"
    if [[ -z "$suffix" ]]; then
      _truncate_text "$max_width" "${items[0]}"
      echo ""
      return
    fi
    if [[ $(_visible_len "$suffix") -ge $max_width ]]; then
      _truncate_text "$max_width" "$suffix"
      echo ""
      return
    fi
    local first_w=$((max_width - $(_visible_len "$suffix")))
    [[ $first_w -lt 1 ]] && first_w=1
    local first_item
    first_item=$(_truncate_text "$first_w" "${items[0]}")
    echo "${first_item}${suffix}"
    return
  fi

  local remaining=$((total - included))
  local suffix=" +${remaining}"
  local final="${result}${suffix}"
  while [[ $(_visible_len "$final") -gt $max_width ]]; do
    if [[ "$result" == *", "* ]]; then
      result="${result%, *}"
      ((remaining++))
      suffix=" +${remaining}"
      final="${result}${suffix}"
    else
      if [[ $(_visible_len "$suffix") -ge $max_width ]]; then
        _truncate_text "$max_width" "$suffix"
        echo ""
        return
      fi
      local value_w=$((max_width - $(_visible_len "$suffix")))
      [[ $value_w -lt 1 ]] && value_w=1
      result=$(_truncate_text "$value_w" "$result")
      final="${result}${suffix}"
      break
    fi
  done

  echo "$final"
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO DE SELEÇÕES INTERATIVAS
# ══════════════════════════════════════════════════════════════════════════════

_rv_hline() {
  local width="$1"
  local i line=""
  for ((i=0; i<width; i++)); do line+="─"; done
  printf '%s' "$line"
}

_rv_section_footer() {
  local inner_w="$1"
  echo -e "${UI_BORDER}╰$(_rv_hline "$inner_w")╯${UI_RESET}"
}

_rv_divider() {
  local inner_w="$1" title="$2"
  local title_vis
  title_vis=$(_visible_len "$title")
  local pad=$((inner_w - title_vis - 3))
  [[ $pad -lt 0 ]] && pad=0
  echo -e "${UI_BORDER}├─ ${UI_ACCENT}${UI_BOLD}${title}${UI_RESET}${UI_BORDER} $(_rv_hline "$pad")┤${UI_RESET}"
}

_print_box_line() {
  local inner_w="$1" content="$2" align="${3:-left}"
  local visible_len
  visible_len=$(_visible_len "$content")
  local pad=$((inner_w - 2 - visible_len))
  [[ $pad -lt 0 ]] && pad=0
  if [[ "$align" == "center" ]]; then
    local left_pad=$((pad / 2))
    local right_pad=$((pad - left_pad))
    echo -e "${UI_BORDER}│${UI_RESET} $(printf '%*s' "$left_pad" '')${content}$(printf '%*s' "$right_pad" '') ${UI_BORDER}│${UI_RESET}"
  else
    echo -e "${UI_BORDER}│${UI_RESET} ${content}$(printf '%*s' "$pad" '') ${UI_BORDER}│${UI_RESET}"
  fi
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

    local w=$((term_width > 100 ? 100 : term_width - 4))
    [[ $w -lt 60 ]] && w=60

    echo ""

    local inner_w=$((w - 2))

    echo -e "${UI_BORDER}╭$(_rv_hline "$inner_w")╮${UI_RESET}"
    _print_box_line "$inner_w" "${UI_PEACH}${UI_BOLD}  RESUMO FINAL${UI_RESET}" "center"
    echo -e "${UI_BORDER}├$(_rv_hline "$inner_w")┤${UI_RESET}"

    local total_pkgs
    total_pkgs=$(_count_total_packages)
    local total_cfgs
    total_cfgs=$(_count_configs_to_copy)
    _print_box_line "$inner_w" "${UI_MUTED}Pacotes:${UI_RESET} ${UI_GREEN}${total_pkgs}${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_MUTED}Configs:${UI_RESET} ${UI_BLUE}${total_cfgs}${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_MUTED}SO:${UI_RESET} ${UI_TEXT}${TARGET_OS:-linux}${UI_RESET}"

    local selected_shells=()
    [[ ${INSTALL_ZSH:-0} -eq 1 ]] && selected_shells+=("zsh")
    [[ ${INSTALL_FISH:-0} -eq 1 ]] && selected_shells+=("fish")
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && selected_shells+=("nushell")

    local themes_selected=()
    [[ ${INSTALL_OH_MY_ZSH:-0} -eq 1 ]] && themes_selected+=("OMZ+P10k")
    if [[ ${INSTALL_STARSHIP:-0} -eq 1 ]]; then
      local starship_label="Starship"
      if [[ "${SELECTED_STARSHIP_PRESET:-}" == "catppuccin-powerline" ]]; then
        if [[ -n "${SELECTED_CATPPUCCIN_FLAVOR:-}" ]]; then
          local starship_flavor="${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}"
          starship_label="Starship Catppuccin (${starship_flavor^})"
        else
          starship_label="Starship Catppuccin"
        fi
      elif [[ -n "${SELECTED_STARSHIP_PRESET:-}" ]]; then
        local preset_display
        case "${SELECTED_STARSHIP_PRESET}" in
          tokyo-night) preset_display="Tokyo Night" ;;
          gruvbox-rainbow) preset_display="Gruvbox Rainbow" ;;
          pastel-powerline) preset_display="Pastel Powerline" ;;
          nerd-font-symbols) preset_display="Nerd Font Symbols" ;;
          plain-text-symbols) preset_display="Plain Text" ;;
          *) preset_display="${SELECTED_STARSHIP_PRESET}" ;;
        esac
        starship_label="Starship ($preset_display)"
      fi
      themes_selected+=("$starship_label")
    fi
    [[ ${INSTALL_OH_MY_POSH:-0} -eq 1 ]] && themes_selected+=("OMP")

    _wrap_items_multiline() {
      local max_w="$1"
      shift
      local items=("$@")
      local lines=()
      local current=""
      local item test_line

      [[ $max_w -lt 10 ]] && max_w=10
      for item in "${items[@]}"; do
        test_line="$item"
        [[ -n "$current" ]] && test_line="${current}, ${item}"
        if [[ $(_visible_len "$test_line") -le $max_w ]]; then
          current="$test_line"
        else
          [[ -n "$current" ]] && lines+=("$current")
          if [[ $(_visible_len "$item") -le $max_w ]]; then
            current="$item"
          else
            lines+=("$(_truncate_text "$max_w" "$item")")
            current=""
          fi
        fi
      done
      [[ -n "$current" ]] && lines+=("$current")
      local IFS='|'
      echo "${lines[*]}"
    }

    _print_wrapped_items() {
      local label="$1"
      local empty_value="$2"
      shift 2
      local items=("$@")

      local label_plain="${label}:"
      local label_vis
      label_vis=$(_visible_len "$label_plain")
      local value_w=$((inner_w - label_vis - 8))
      [[ $value_w -lt 10 ]] && value_w=10

      local -a wrapped_lines=()
      if [[ ${#items[@]} -gt 0 ]]; then
        local wrapped
        wrapped=$(_wrap_items_multiline "$value_w" "${items[@]}")
        IFS='|' read -ra wrapped_lines <<< "$wrapped"
      else
        wrapped_lines=("$empty_value")
      fi
      [[ ${#wrapped_lines[@]} -eq 0 ]] && wrapped_lines=("$empty_value")

      _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}${label}:${UI_RESET} ${UI_TEXT}${wrapped_lines[0]}${UI_RESET}"

      local prefix
      prefix=$(printf '%*s' "$((label_vis + 1))" '')
      local i=0
      for ((i=1; i<${#wrapped_lines[@]}; i++)); do
        _print_box_line "$inner_w" "  ${UI_DIM}${prefix}${UI_RESET}${UI_TEXT}${wrapped_lines[i]}${UI_RESET}"
      done
    }

    _items_to_text() {
      local empty_value="$1"
      shift
      local items=("$@")
      if [[ ${#items[@]} -gt 0 ]]; then
        _join_items "${items[@]}"
      else
        echo "$empty_value"
      fi
    }

    _print_pair_items() {
      local left_label="$1" left_empty="$2" left_arr_name="$3"
      local right_label="$4" right_empty="$5" right_arr_name="$6"
      local -n left_arr="$left_arr_name"
      local -n right_arr="$right_arr_name"

      local left_text right_text
      left_text=$(_items_to_text "$left_empty" "${left_arr[@]}")
      right_text=$(_items_to_text "$right_empty" "${right_arr[@]}")

      local left_fmt right_fmt pair_line
      left_fmt="${UI_BOLD}${UI_YELLOW}${left_label}:${UI_RESET} ${UI_TEXT}${left_text}${UI_RESET}"
      right_fmt="${UI_BOLD}${UI_YELLOW}${right_label}:${UI_RESET} ${UI_TEXT}${right_text}${UI_RESET}"
      pair_line="• ${left_fmt} ${UI_DIM}|${UI_RESET} ${right_fmt}"

      if [[ ${#left_arr[@]} -le 6 ]] && [[ ${#right_arr[@]} -le 6 ]] && [[ $(_visible_len "$pair_line") -le $((inner_w - 2)) ]]; then
        _print_box_line "$inner_w" "$pair_line"
      else
        _print_wrapped_items "$left_label" "$left_empty" "${left_arr[@]}"
        _print_box_line "$inner_w" " "
        _print_wrapped_items "$right_label" "$right_empty" "${right_arr[@]}"
      fi
    }

    _rv_divider "$inner_w" "AMBIENTE"
    _print_pair_items "Shells" "(nenhum)" "selected_shells" "Terminal" "(nenhum)" "SELECTED_TERMINALS"
    _print_box_line "$inner_w" " "
    _print_wrapped_items "Temas" "(nenhum)" "${themes_selected[@]}"
    _print_box_line "$inner_w" " "
    _print_wrapped_items "Fontes" "(nenhuma)" "${SELECTED_NERD_FONTS[@]}"
    _print_box_line "$inner_w" " "

    _rv_divider "$inner_w" "FERRAMENTAS"
    _print_wrapped_items "Ferramentas CLI" "(nenhuma)" "${SELECTED_CLI_TOOLS[@]}"
    _print_box_line "$inner_w" " "
    _print_wrapped_items "Ferramentas IA" "(nenhuma)" "${SELECTED_IA_TOOLS[@]}"
    _print_box_line "$inner_w" " "
    _print_wrapped_items "Runtimes" "(nenhum)" "${SELECTED_RUNTIMES[@]}"
    _print_box_line "$inner_w" " "

    local gui_total=0
    gui_total=$((${#SELECTED_IDES[@]} + ${#SELECTED_BROWSERS[@]} + ${#SELECTED_DEV_TOOLS[@]} + \
                 ${#SELECTED_DATABASES[@]} + ${#SELECTED_PRODUCTIVITY[@]} + \
                 ${#SELECTED_COMMUNICATION[@]} + ${#SELECTED_MEDIA[@]} + ${#SELECTED_UTILITIES[@]}))

    if [[ $gui_total -gt 0 ]]; then
      _rv_divider "$inner_w" "APPS GUI ${UI_RESET}${UI_DIM}(${gui_total})"

      local gui_data_w=$((inner_w - 15))
      if [[ ${#SELECTED_IDES[@]} -gt 0 ]]; then
        local ides_str
        ides_str=$(_truncate_items "$gui_data_w" "${SELECTED_IDES[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}IDEs:${UI_RESET}      ${UI_TEXT}$ides_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_BROWSERS[@]} -gt 0 ]]; then
        local browsers_str
        browsers_str=$(_truncate_items "$gui_data_w" "${SELECTED_BROWSERS[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Navegadores:${UI_RESET} ${UI_TEXT}$browsers_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_DEV_TOOLS[@]} -gt 0 ]]; then
        local devtools_str
        devtools_str=$(_truncate_items "$gui_data_w" "${SELECTED_DEV_TOOLS[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Dev Tools:${UI_RESET} ${UI_TEXT}$devtools_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_DATABASES[@]} -gt 0 ]]; then
        local dbs_str
        dbs_str=$(_truncate_items "$gui_data_w" "${SELECTED_DATABASES[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Bancos:${UI_RESET}    ${UI_TEXT}$dbs_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_PRODUCTIVITY[@]} -gt 0 ]]; then
        local prod_str
        prod_str=$(_truncate_items "$gui_data_w" "${SELECTED_PRODUCTIVITY[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Produtiv.:${UI_RESET} ${UI_TEXT}$prod_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_COMMUNICATION[@]} -gt 0 ]]; then
        local comm_str
        comm_str=$(_truncate_items "$gui_data_w" "${SELECTED_COMMUNICATION[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Comunic.:${UI_RESET}  ${UI_TEXT}$comm_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_MEDIA[@]} -gt 0 ]]; then
        local media_str
        media_str=$(_truncate_items "$gui_data_w" "${SELECTED_MEDIA[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Mídia:${UI_RESET}     ${UI_TEXT}$media_str${UI_RESET}"
      fi
      if [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]]; then
        local utils_str
        utils_str=$(_truncate_items "$gui_data_w" "${SELECTED_UTILITIES[@]}")
        _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}Utilitár.:${UI_RESET} ${UI_TEXT}$utils_str${UI_RESET}"
      fi
      _rv_divider "$inner_w" "COPIAR CONFIGURAÇÕES"
    else
      _rv_divider "$inner_w" "COPIAR CONFIGURAÇÕES"
    fi

    _rv_cfg_item() {
      local available="$1" selected="$2" name="$3"
      if [[ $available -eq 1 ]]; then
        if [[ $selected -eq 1 ]]; then
          echo "${UI_GREEN}✓${UI_RESET}${name}"
        else
          echo "${UI_DIM}✗${name}${UI_RESET}"
        fi
      fi
    }

    local cfg_shells=()
    [[ ${INSTALL_ZSH:-0} -eq 1 ]] && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_ZSH_CONFIG:-0}" "Zsh")")
    [[ ${INSTALL_FISH:-0} -eq 1 ]] && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_FISH_CONFIG:-0}" "Fish")")
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_NUSHELL_CONFIG:-0}" "Nushell")")

    local cfg_editors=()
    local has_neovim=0 has_vscode=0 has_zed=0 has_helix=0
    for ide in "${SELECTED_IDES[@]}"; do
      case "$ide" in
        neovim) has_neovim=1 ;;
        vscode) has_vscode=1 ;;
        zed) has_zed=1 ;;
        helix) has_helix=1 ;;
      esac
    done
    [[ $has_neovim -eq 1 ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_NVIM_CONFIG:-0}" "Neovim")")
    [[ $has_vscode -eq 1 ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_VSCODE_SETTINGS:-0}" "VSCode")")
    [[ $has_zed -eq 1 ]] && [[ -f "$CONFIG_SHARED/zed/settings.json" ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_ZED_CONFIG:-0}" "Zed")")
    [[ $has_helix -eq 1 ]] && [[ -f "$CONFIG_SHARED/helix/config.toml" ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_HELIX_CONFIG:-0}" "Helix")")

    local cfg_tools=()
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
    [[ $has_tmux -eq 1 ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_TMUX_CONFIG:-0}" "tmux")")
    [[ $has_lazygit -eq 1 ]] && [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_LAZYGIT_CONFIG:-0}" "lazygit")")
    [[ $has_yazi -eq 1 ]] && [[ -d "$CONFIG_SHARED/yazi" ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_YAZI_CONFIG:-0}" "yazi")")
    [[ $has_btop -eq 1 ]] && [[ -f "$CONFIG_SHARED/btop/btop.conf" ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_BTOP_CONFIG:-0}" "btop")")
    [[ $has_direnv -eq 1 ]] && [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_DIRENV_CONFIG:-0}" "direnv")")
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_GIT_CONFIG:-0}" "Git")")

    local cfg_terminals=()
    for term in "${SELECTED_TERMINALS[@]}"; do
      case "$term" in
        ghostty) cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_TERMINAL_CONFIG:-0}" "ghostty")") ;;
        kitty) cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_KITTY_CONFIG:-0}" "kitty")") ;;
        alacritty) cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_ALACRITTY_CONFIG:-0}" "alacritty")") ;;
        wezterm) cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_WEZTERM_CONFIG:-0}" "wezterm")") ;;
      esac
    done

    local cfg_runtime=()
    [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && cfg_runtime+=("$(_rv_cfg_item 1 "${COPY_MISE_CONFIG:-0}" "Mise")")
    [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]] && cfg_runtime+=("$(_rv_cfg_item 1 "${COPY_STARSHIP_CONFIG:-0}" "Starship")")

    _cfg_join_text() {
      local arr_name="$1"
      local -n arr_ref="$arr_name"
      if [[ ${#arr_ref[@]} -gt 0 ]]; then
        local IFS=' '
        echo "${arr_ref[*]}"
      fi
    }

    _print_cfg_single() {
      local label="$1" arr_name="$2"
      local -n arr_ref="$arr_name"
      [[ ${#arr_ref[@]} -eq 0 ]] && return
      local text
      text=$(_cfg_join_text "$arr_name")
      _print_box_line "$inner_w" "• ${UI_BOLD}${UI_YELLOW}${label}:${UI_RESET} ${UI_TEXT}${text}${UI_RESET}"
    }

    _print_cfg_pair() {
      local left_label="$1" left_arr_name="$2" right_label="$3" right_arr_name="$4"
      local -n left_ref="$left_arr_name"
      local -n right_ref="$right_arr_name"

      if [[ ${#left_ref[@]} -eq 0 ]] && [[ ${#right_ref[@]} -eq 0 ]]; then
        return
      fi

      if [[ ${#left_ref[@]} -gt 0 ]] && [[ ${#right_ref[@]} -gt 0 ]] && \
         [[ ${#left_ref[@]} -le 6 ]] && [[ ${#right_ref[@]} -le 6 ]]; then
        local left_txt right_txt pair_line
        left_txt=$(_cfg_join_text "$left_arr_name")
        right_txt=$(_cfg_join_text "$right_arr_name")
        pair_line="• ${UI_BOLD}${UI_YELLOW}${left_label}:${UI_RESET} ${UI_TEXT}${left_txt}${UI_RESET} ${UI_DIM}|${UI_RESET} ${UI_BOLD}${UI_YELLOW}${right_label}:${UI_RESET} ${UI_TEXT}${right_txt}${UI_RESET}"
        if [[ $(_visible_len "$pair_line") -le $((inner_w - 2)) ]]; then
          _print_box_line "$inner_w" "$pair_line"
          return
        fi
      fi

      _print_cfg_single "$left_label" "$left_arr_name"
      if [[ ${#left_ref[@]} -gt 0 ]] && [[ ${#right_ref[@]} -gt 0 ]]; then
        _print_box_line "$inner_w" " "
      fi
      _print_cfg_single "$right_label" "$right_arr_name"
    }

    _print_cfg_pair "Shells" "cfg_shells" "Terminais" "cfg_terminals"
    if [[ ${#cfg_shells[@]} -gt 0 ]] || [[ ${#cfg_terminals[@]} -gt 0 ]]; then
      _print_box_line "$inner_w" " "
    fi
    _print_cfg_pair "Editores" "cfg_editors" "Runtimes" "cfg_runtime"
    if [[ ${#cfg_editors[@]} -gt 0 ]] || [[ ${#cfg_runtime[@]} -gt 0 ]]; then
      _print_box_line "$inner_w" " "
    fi
    _print_cfg_single "Ferramentas" "cfg_tools"

    local has_any_cfg=0
    [[ ${#cfg_shells[@]} -gt 0 ]] && has_any_cfg=1
    [[ ${#cfg_editors[@]} -gt 0 ]] && has_any_cfg=1
    [[ ${#cfg_tools[@]} -gt 0 ]] && has_any_cfg=1
    [[ ${#cfg_terminals[@]} -gt 0 ]] && has_any_cfg=1
    [[ ${#cfg_runtime[@]} -gt 0 ]] && has_any_cfg=1
    if [[ $has_any_cfg -eq 0 ]]; then
      _print_box_line "$inner_w" "${UI_DIM}(nenhuma configuração disponível)${UI_RESET}"
    fi

    _rv_section_footer "$inner_w"
    echo ""

    # ── Ações ──
    echo -e "${UI_BORDER}╭$(_rv_hline "$inner_w")╮${UI_RESET}"
    _print_box_line "$inner_w" "${UI_ACCENT}${UI_BOLD}EDITAR SELEÇÕES${UI_RESET}" "center"
    echo -e "${UI_BORDER}├$(_rv_hline "$inner_w")┤${UI_RESET}"

    local n="${UI_PEACH}"
    local t="${UI_TEXT}"
    _print_box_line "$inner_w" " ${n}0${UI_RESET} ${t}Config${UI_RESET}  ${n}1${UI_RESET} ${t}Shells${UI_RESET}  ${n}2${UI_RESET} ${t}Fontes${UI_RESET}  ${n}3${UI_RESET} ${t}Terminais${UI_RESET}  ${n}4${UI_RESET} ${t}CLI${UI_RESET}  ${n}5${UI_RESET} ${t}IA${UI_RESET}"
    _print_box_line "$inner_w" " ${n}6${UI_RESET} ${t}Apps GUI${UI_RESET}  ${n}7${UI_RESET} ${t}Runtimes${UI_RESET}  ${n}8${UI_RESET} ${t}Git${UI_RESET}"
    echo -e "${UI_BORDER}├$(_rv_hline "$inner_w")┤${UI_RESET}"
    _print_box_line "$inner_w" "${UI_GREEN}${UI_BOLD}Enter${UI_RESET} ${UI_MUTED}Iniciar instalação${UI_RESET}   ${UI_RED}${UI_BOLD}S${UI_RESET} ${UI_MUTED}Sair${UI_RESET}"
    _rv_section_footer "$inner_w"
    echo ""
    read -r -p "  → " choice

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
# SELEÇÃO DE CONFIGURAÇÕES A COPIAR
# ══════════════════════════════════════════════════════════════════════════════
ask_configs_to_copy() {
  local config_options=()
  local config_keys=()

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

  if [[ -f "$CONFIG_SHARED/starship.toml" ]] && [[ ${INSTALL_STARSHIP:-0} -eq 1 ]]; then
    config_options+=("starship-config - Starship (~/.config/starship.toml)")
    config_keys+=("COPY_STARSHIP_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/vscode/settings.json" ]] || [[ -f "$CONFIG_SHARED/vscode/extensions.txt" ]]; then
    config_options+=("vscode-config   - VS Code (settings + extensões)")
    config_keys+=("COPY_VSCODE_SETTINGS")
  fi

  if [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]; then
    config_options+=("lazygit-config  - Lazygit (theme + keybindings)")
    config_keys+=("COPY_LAZYGIT_CONFIG")
  fi

  if [[ -d "$CONFIG_SHARED/yazi" ]] && [[ -n "$(ls -A "$CONFIG_SHARED/yazi" 2>/dev/null)" ]]; then
    config_options+=("yazi-config     - Yazi (file manager)")
    config_keys+=("COPY_YAZI_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]; then
    config_options+=("btop-config     - Btop (resource monitor)")
    config_keys+=("COPY_BTOP_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/kitty/kitty.conf" ]]; then
    config_options+=("kitty-config    - Kitty (terminal)")
    config_keys+=("COPY_KITTY_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/alacritty/alacritty.toml" ]]; then
    config_options+=("alacritty-config - Alacritty (terminal)")
    config_keys+=("COPY_ALACRITTY_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/wezterm/wezterm.lua" ]]; then
    config_options+=("wezterm-config  - WezTerm (terminal)")
    config_keys+=("COPY_WEZTERM_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/.ripgreprc" ]]; then
    config_options+=("ripgrep-config  - Ripgrep (~/.ripgreprc)")
    config_keys+=("COPY_RIPGREP_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/npm/.npmrc" ]]; then
    config_options+=("npm-config      - NPM (~/.npmrc)")
    config_keys+=("COPY_NPM_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/pnpm/.pnpmrc" ]]; then
    config_options+=("pnpm-config     - PNPM (~/.config/pnpm/)")
    config_keys+=("COPY_PNPM_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/yarn/.yarnrc" ]]; then
    config_options+=("yarn-config     - Yarn (~/.yarnrc)")
    config_keys+=("COPY_YARN_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/pip/pip.conf" ]]; then
    config_options+=("pip-config      - Pip (~/.config/pip/)")
    config_keys+=("COPY_PIP_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/cargo/config.toml" ]]; then
    config_options+=("cargo-config    - Cargo (~/.cargo/)")
    config_keys+=("COPY_CARGO_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/zed/settings.json" ]]; then
    config_options+=("zed-config      - Zed (editor)")
    config_keys+=("COPY_ZED_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/helix/config.toml" ]]; then
    config_options+=("helix-config    - Helix (editor)")
    config_keys+=("COPY_HELIX_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/aider/.aider.conf.yml" ]]; then
    config_options+=("aider-config    - Aider (~/.aider.conf.yml)")
    config_keys+=("COPY_AIDER_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/docker/config.json" ]]; then
    config_options+=("docker-config   - Docker (~/.docker/)")
    config_keys+=("COPY_DOCKER_CONFIG")
  fi

  if [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]; then
    config_options+=("direnv-config   - Direnv (~/.config/direnv/)")
    config_keys+=("COPY_DIRENV_CONFIG")
  fi

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
      "starship-config") COPY_STARSHIP_CONFIG=1 ;;
      "vscode-config")   COPY_VSCODE_SETTINGS=1 ;;
      "lazygit-config")  COPY_LAZYGIT_CONFIG=1 ;;
      "yazi-config")     COPY_YAZI_CONFIG=1 ;;
      "btop-config")     COPY_BTOP_CONFIG=1 ;;
      "kitty-config")    COPY_KITTY_CONFIG=1 ;;
      "alacritty-config") COPY_ALACRITTY_CONFIG=1 ;;
      "wezterm-config")  COPY_WEZTERM_CONFIG=1 ;;
      "ripgrep-config")  COPY_RIPGREP_CONFIG=1 ;;
      "npm-config")      COPY_NPM_CONFIG=1 ;;
      "pnpm-config")     COPY_PNPM_CONFIG=1 ;;
      "yarn-config")     COPY_YARN_CONFIG=1 ;;
      "pip-config")      COPY_PIP_CONFIG=1 ;;
      "cargo-config")    COPY_CARGO_CONFIG=1 ;;
      "zed-config")      COPY_ZED_CONFIG=1 ;;
      "helix-config")    COPY_HELIX_CONFIG=1 ;;
      "aider-config")    COPY_AIDER_CONFIG=1 ;;
      "docker-config")   COPY_DOCKER_CONFIG=1 ;;
      "direnv-config")   COPY_DIRENV_CONFIG=1 ;;
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

  if [[ -n "${INSTALL_LOG:-}" ]] && [[ -f "${INSTALL_LOG:-}" ]]; then
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
  trap 'rm -f "${deb:-}"' RETURN

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

install_docker_linux() {
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
  trap 'rm -f "${temp_script:-}"' RETURN

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

# ensure_rust_cargo() → Movido para lib/tools.sh

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
    if has_cmd curl && has_cmd git; then
      return 0
    fi
    msg "  🔄 Dependências base não encontradas, reinstalando..."
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

copy_tool_configs() {
  msg "▶ Copiando configurações de ferramentas CLI"

  if [[ ${COPY_LAZYGIT_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]; then
    copy_dir "$CONFIG_SHARED/lazygit" "$HOME/.config/lazygit"
  fi

  if [[ ${COPY_YAZI_CONFIG:-1} -eq 1 ]] && [[ -d "$CONFIG_SHARED/yazi" ]]; then
    copy_dir "$CONFIG_SHARED/yazi" "$HOME/.config/yazi"
  fi

  if [[ ${COPY_BTOP_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]; then
    copy_dir "$CONFIG_SHARED/btop" "$HOME/.config/btop"
  fi

  if [[ ${COPY_KITTY_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/kitty/kitty.conf" ]]; then
    copy_dir "$CONFIG_SHARED/kitty" "$HOME/.config/kitty"
  fi

  if [[ ${COPY_ALACRITTY_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/alacritty/alacritty.toml" ]]; then
    copy_dir "$CONFIG_SHARED/alacritty" "$HOME/.config/alacritty"
  fi

  if [[ ${COPY_WEZTERM_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/wezterm/wezterm.lua" ]]; then
    copy_dir "$CONFIG_SHARED/wezterm" "$HOME/.config/wezterm"
  fi

  if [[ ${COPY_RIPGREP_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/.ripgreprc" ]]; then
    copy_file "$CONFIG_SHARED/.ripgreprc" "$HOME/.ripgreprc"
  fi

  if [[ ${COPY_NPM_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/npm/.npmrc" ]]; then
    copy_file "$CONFIG_SHARED/npm/.npmrc" "$HOME/.npmrc"
  fi

  if [[ ${COPY_PNPM_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/pnpm/.pnpmrc" ]]; then
    mkdir -p "$HOME/.config/pnpm"
    copy_file "$CONFIG_SHARED/pnpm/.pnpmrc" "$HOME/.config/pnpm/.pnpmrc"
  fi

  if [[ ${COPY_YARN_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/yarn/.yarnrc" ]]; then
    copy_file "$CONFIG_SHARED/yarn/.yarnrc" "$HOME/.yarnrc"
  fi

  if [[ ${COPY_PIP_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/pip/pip.conf" ]]; then
    mkdir -p "$HOME/.config/pip"
    copy_file "$CONFIG_SHARED/pip/pip.conf" "$HOME/.config/pip/pip.conf"
  fi

  if [[ ${COPY_CARGO_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/cargo/config.toml" ]]; then
    mkdir -p "$HOME/.cargo"
    copy_file "$CONFIG_SHARED/cargo/config.toml" "$HOME/.cargo/config.toml"
  fi

  if [[ ${COPY_ZED_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/zed/settings.json" ]]; then
    mkdir -p "$HOME/.config/zed"
    copy_file "$CONFIG_SHARED/zed/settings.json" "$HOME/.config/zed/settings.json"
  fi

  if [[ ${COPY_HELIX_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/helix/config.toml" ]]; then
    mkdir -p "$HOME/.config/helix"
    copy_file "$CONFIG_SHARED/helix/config.toml" "$HOME/.config/helix/config.toml"
  fi

  if [[ ${COPY_AIDER_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/aider/.aider.conf.yml" ]]; then
    copy_file "$CONFIG_SHARED/aider/.aider.conf.yml" "$HOME/.aider.conf.yml"
  fi

  if [[ ${COPY_DOCKER_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/docker/config.json" ]]; then
    mkdir -p "$HOME/.docker"
    copy_file "$CONFIG_SHARED/docker/config.json" "$HOME/.docker/config.json"
  fi

  if [[ ${COPY_DIRENV_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]; then
    mkdir -p "$HOME/.config/direnv"
    copy_file "$CONFIG_SHARED/direnv/.direnvrc" "$HOME/.config/direnv/direnvrc"
  fi
}

apply_shared_configs() {
  msg "▶ Copiando configs compartilhadas"

  if is_truthy "$INSTALL_FISH" && has_cmd fish && [[ ${COPY_FISH_CONFIG:-1} -eq 1 ]]; then
    local preserved_fish_config=""
    preserved_fish_config="$(extract_user_path_config_fish)"

    copy_dir "$CONFIG_SHARED/fish" "$HOME/.config/fish"
    normalize_crlf_to_lf "$HOME/.config/fish/config.fish"

    if [[ -n "$preserved_fish_config" ]]; then
      msg "  🔄 Verificando configurações de PATH para preservar..."
      append_preserved_config "$HOME/.config/fish/config.fish" "$preserved_fish_config"
    fi
  elif is_truthy "$INSTALL_FISH" && [[ ${COPY_FISH_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Fish config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_FISH" && ! has_cmd fish; then
    msg "  ⚠️ Fish não encontrado, pulando config."
  fi

  if is_truthy "$INSTALL_ZSH" && has_cmd zsh && [[ ${COPY_ZSH_CONFIG:-1} -eq 1 ]]; then
    local preserved_zsh_config=""
    preserved_zsh_config="$(extract_user_path_config_zsh)"

    copy_file "$CONFIG_SHARED/zsh/.zshrc" "$HOME/.zshrc"
    normalize_crlf_to_lf "$HOME/.zshrc"

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

  if has_cmd mise && [[ ${COPY_MISE_CONFIG:-1} -eq 1 ]]; then
    copy_dir "$CONFIG_SHARED/mise" "$HOME/.config/mise"
  elif [[ ${COPY_MISE_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Mise config: usuário optou por não copiar"
  elif ! has_cmd mise; then
    msg "  ⚠️ Mise não encontrado, pulando config."
  fi

  if has_cmd starship && [[ ${COPY_STARSHIP_CONFIG:-1} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]]; then
    mkdir -p "$HOME/.config"
    copy_file "$CONFIG_SHARED/starship.toml" "$HOME/.config/starship.toml"
  elif [[ ${COPY_STARSHIP_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Starship config: usuário optou por não copiar"
  elif ! has_cmd starship; then
    msg "  ⚠️ Starship não encontrado, pulando config."
  fi

  if has_cmd nvim && [[ ${COPY_NVIM_CONFIG:-1} -eq 1 ]]; then
    copy_dir "$CONFIG_SHARED/nvim" "$HOME/.config/nvim"
  elif [[ ${COPY_NVIM_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Neovim config: usuário optou por não copiar"
  elif ! has_cmd nvim; then
    msg "  ⚠️ Neovim não encontrado, pulando config."
  fi

  if has_cmd tmux && [[ ${COPY_TMUX_CONFIG:-1} -eq 1 ]]; then
    copy_file "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf"
  elif [[ ${COPY_TMUX_CONFIG:-1} -eq 0 ]]; then
    msg "  ⏭️  Tmux config: usuário optou por não copiar"
  elif ! has_cmd tmux; then
    msg "  ⚠️ tmux não encontrado, pulando .tmux.conf."
  fi

  if [[ ${COPY_VSCODE_SETTINGS:-1} -eq 1 ]]; then
    copy_vscode_settings
  else
    msg "  ⏭️  VS Code settings: usuário optou por não copiar"
  fi

  copy_tool_configs

  if [[ ${COPY_SSH_KEYS:-0} -eq 1 ]]; then
    local ssh_source=""
    if [[ -n "$PRIVATE_SHARED" ]] && [[ -d "$PRIVATE_SHARED/.ssh" ]]; then
      ssh_source="$PRIVATE_SHARED/.ssh"
    elif [[ -d "$CONFIG_SHARED/.ssh" ]]; then
      ssh_source="$CONFIG_SHARED/.ssh"
    fi
    if [[ -n "$ssh_source" ]]; then
      msg "▶ Gerenciando Chaves SSH"
      if manage_ssh_keys "$ssh_source"; then
        set_ssh_permissions
        msg "  ✓ Chaves SSH configuradas com permissões corretas (700/600)"
      fi
    fi
  else
    msg "  ⏭️  SSH Keys: usuário optou por não copiar (padrão por segurança)"
  fi
}

# copy_vscode_settings() → Movido para lib/fileops.sh

# apply_linux_configs, apply_macos_configs, apply_windows_configs,
# copy_windows_terminal_settings, copy_windows_powershell_profiles
# → Movidos para lib/os_linux.sh, lib/os_macos.sh, lib/os_windows.sh


# ════════════════════════════════════════════════════════════════
# VS Code Extensions - Export/Import
# ════════════════════════════════════════════════════════════════

# export_vscode_extensions(), install_vscode_extensions() → Movidos para lib/fileops.sh

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

  export_vscode_settings
  export_vscode_extensions

  msg "▶ Exportando configurações de ferramentas CLI"

  if [[ -f "$HOME/.config/lazygit/config.yml" ]]; then
    export_dir "$HOME/.config/lazygit" "$CONFIG_SHARED/lazygit"
  fi

  if [[ -d "$HOME/.config/yazi" ]]; then
    export_dir "$HOME/.config/yazi" "$CONFIG_SHARED/yazi"
  fi

  if [[ -f "$HOME/.config/btop/btop.conf" ]]; then
    export_dir "$HOME/.config/btop" "$CONFIG_SHARED/btop"
  fi

  if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
    export_dir "$HOME/.config/kitty" "$CONFIG_SHARED/kitty"
  fi

  if [[ -f "$HOME/.config/alacritty/alacritty.toml" ]]; then
    export_dir "$HOME/.config/alacritty" "$CONFIG_SHARED/alacritty"
  fi

  if [[ -f "$HOME/.config/wezterm/wezterm.lua" ]]; then
    export_dir "$HOME/.config/wezterm" "$CONFIG_SHARED/wezterm"
  fi

  if [[ -f "$HOME/.ripgreprc" ]]; then
    export_file "$HOME/.ripgreprc" "$CONFIG_SHARED/.ripgreprc"
  fi

  if [[ -f "$HOME/.npmrc" ]]; then
    mkdir -p "$CONFIG_SHARED/npm"
    export_file "$HOME/.npmrc" "$CONFIG_SHARED/npm/.npmrc"
  fi

  if [[ -f "$HOME/.config/pnpm/.pnpmrc" ]]; then
    mkdir -p "$CONFIG_SHARED/pnpm"
    export_file "$HOME/.config/pnpm/.pnpmrc" "$CONFIG_SHARED/pnpm/.pnpmrc"
  fi

  if [[ -f "$HOME/.yarnrc" ]]; then
    mkdir -p "$CONFIG_SHARED/yarn"
    export_file "$HOME/.yarnrc" "$CONFIG_SHARED/yarn/.yarnrc"
  fi

  if [[ -f "$HOME/.config/pip/pip.conf" ]]; then
    mkdir -p "$CONFIG_SHARED/pip"
    export_file "$HOME/.config/pip/pip.conf" "$CONFIG_SHARED/pip/pip.conf"
  fi

  if [[ -f "$HOME/.cargo/config.toml" ]]; then
    mkdir -p "$CONFIG_SHARED/cargo"
    export_file "$HOME/.cargo/config.toml" "$CONFIG_SHARED/cargo/config.toml"
  fi

  if [[ -f "$HOME/.config/zed/settings.json" ]]; then
    mkdir -p "$CONFIG_SHARED/zed"
    export_file "$HOME/.config/zed/settings.json" "$CONFIG_SHARED/zed/settings.json"
  fi

  if [[ -f "$HOME/.config/helix/config.toml" ]]; then
    mkdir -p "$CONFIG_SHARED/helix"
    export_file "$HOME/.config/helix/config.toml" "$CONFIG_SHARED/helix/config.toml"
  fi

  if [[ -f "$HOME/.aider.conf.yml" ]]; then
    mkdir -p "$CONFIG_SHARED/aider"
    export_file "$HOME/.aider.conf.yml" "$CONFIG_SHARED/aider/.aider.conf.yml"
  fi

  if [[ -f "$HOME/.docker/config.json" ]]; then
    mkdir -p "$CONFIG_SHARED/docker"
    export_file "$HOME/.docker/config.json" "$CONFIG_SHARED/docker/config.json"
  fi

  if [[ -f "$HOME/.config/direnv/direnvrc" ]]; then
    mkdir -p "$CONFIG_SHARED/direnv"
    export_file "$HOME/.config/direnv/direnvrc" "$CONFIG_SHARED/direnv/.direnvrc"
  fi

  export_brewfile

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

# export_vscode_settings() → Movido para lib/fileops.sh

# export_windows_configs_back() → Movido para lib/os_windows.sh

main() {
  if [[ ! -d "$CONFIG_SHARED" ]]; then
    echo "❌ Pasta shared/ não encontrada em $CONFIG_SHARED" >&2
    exit 1
  fi

  TARGET_OS="$(detect_os)"

  INSTALL_LOG="$HOME/.dotfiles-install-$(date +%Y%m%d-%H%M%S).log"

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
    ask_themes
    [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && ask_oh_my_zsh_plugins
    [[ $INSTALL_STARSHIP -eq 1 ]] && ask_starship_preset
    [[ $INSTALL_OH_MY_POSH -eq 1 ]] && ask_oh_my_posh_theme
    [[ $INSTALL_FISH -eq 1 ]] && ask_fish_plugins
    ask_nerd_fonts

    # ══════════════════════════════════════════════════════════════
    # ETAPA 2: Apps e Ferramentas
    # ══════════════════════════════════════════════════════════════
    ask_terminals
    ask_cli_tools
    ask_ia_tools
    ask_gui_apps
    ask_runtimes
    ask_git_configuration
    ask_configs_to_copy

    # ══════════════════════════════════════════════════════════════
    # Confirmação Final e Checkpoint
    # ══════════════════════════════════════════════════════════════
    review_selections

    checkpoint_save "install"
    msg "  💾 Checkpoint salvo. Se a instalação falhar, execute novamente para retomar."
    sleep 1
  else
    msg "  ⏩ Retomando instalação do checkpoint..."
  fi

  clear_screen
  exec > >(tee -a "$INSTALL_LOG") 2>&1
  step_init 12

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

  clear_screen

  if [[ ${#CRITICAL_ERRORS[@]} -eq 0 ]]; then
    checkpoint_clear
  fi

  print_post_install_report

  print_final_summary
}

main "$@"
