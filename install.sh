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
BACKUP_DIR="$(mktemp -d "$HOME/.bkp-$(date +%Y%m%d-%H%M%S)-XXXXXX" 2>/dev/null || echo "$HOME/.bkp-$(date +%Y%m%d-%H%M%S)-$$")"
TARGET_OS=""
ARCH=""
LINUX_PKG_MANAGER=""
LINUX_PKG_UPDATED=0
MODE="install"
FAIL_FAST="${FAIL_FAST:-0}"
DRY_RUN="${DRY_RUN:-0}"
SCRIPT_VERSION="1.0.0"
VERBOSE="${VERBOSE:-0}"
QUIET="${QUIET:-0}"
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
  echo -e "  ${c}-q${r}, ${c}--quiet${r}         Saida reduzida"
  echo -e "  ${c}--verbose${r}           Saida detalhada"
  echo -e "  ${c}--no-color${r}          Desativar cores (equivale a NO_COLOR=1)"
  echo ""
  echo -e "${b}Variaveis de ambiente:${r}"
  echo -e "  DRY_RUN=1           Mesmo que --dry-run"
  echo -e "  NO_COLOR=1          Mesmo que --no-color"
  echo -e "  FORCE_UI_MODE=bash  Forcar modo de UI (fzf/gum/bash)"
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
  return 1
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

_ssh_is_identity_file() {
  local key_file="$1"
  local key_name
  key_name=$(basename "$key_file")
  case "$key_name" in
    *.pub|config|known_hosts|known_hosts.*|authorized_keys|authorized_keys.*) return 1 ;;
  esac
  return 0
}

_ssh_key_kind() {
  local key_file="$1"
  [[ -f "$key_file" ]] || { echo "missing"; return 0; }

  local first_line
  first_line=$(head -n 1 "$key_file" 2>/dev/null)

  case "$first_line" in
    "-----BEGIN OPENSSH PRIVATE KEY-----"|"-----BEGIN RSA PRIVATE KEY-----"|"-----BEGIN EC PRIVATE KEY-----"|"-----BEGIN DSA PRIVATE KEY-----"|"-----BEGIN PRIVATE KEY-----"|"-----BEGIN ENCRYPTED PRIVATE KEY-----")
      echo "private"
      ;;
    ssh-*)
      echo "public"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

_ssh_sync_public_key() {
  local src_private="$1" dest_private="$2"
  local src_pub="${src_private}.pub"
  local dest_pub="${dest_private}.pub"
  local private_fp src_pub_fp dest_pub_fp

  private_fp=$(get_ssh_key_fingerprint "$src_private")

  # Se a .pub de origem existir e combinar com a privada, ela é preferida.
  if [[ -f "$src_pub" ]]; then
    src_pub_fp=$(get_ssh_key_fingerprint "$src_pub")
    if [[ "$private_fp" != "unknown" ]] && [[ "$private_fp" == "$src_pub_fp" ]]; then
      cp "$src_pub" "$dest_pub"
      return 0
    fi
    echo -e "  ${UI_WARNING}⚠ ${src_pub##*/} não corresponde à privada (${private_fp} != ${src_pub_fp}).${UI_RESET}"
  fi

  # Se o destino já possui .pub compatível com a privada, preserva.
  if [[ -f "$dest_pub" ]]; then
    dest_pub_fp=$(get_ssh_key_fingerprint "$dest_pub")
    if [[ "$private_fp" != "unknown" ]] && [[ "$private_fp" == "$dest_pub_fp" ]]; then
      return 0
    fi
  fi

  # Tentativa de regenerar .pub a partir da privada sem prompt interativo.
  local pub_tmp
  if pub_tmp="$(mktemp 2>/dev/null)"; then
    if ssh-keygen -y -f "$src_private" </dev/null > "$pub_tmp" 2>/dev/null; then
      mv "$pub_tmp" "$dest_pub"
      return 0
    fi
    rm -f "$pub_tmp" 2>/dev/null || true
  fi

  # Evita manter .pub incorreta quando não for possível regenerar.
  if [[ -f "$dest_pub" ]]; then
    rm -f "$dest_pub"
    echo -e "  ${UI_WARNING}⚠ ${dest_pub##*/} removida para evitar fingerprint divergente.${UI_RESET}"
  fi

  return 0
}

_ssh_copy_entry() {
  local src_path="$1" dest_path="$2"

  if _ssh_is_identity_file "$src_path"; then
    local key_kind
    key_kind=$(_ssh_key_kind "$src_path")
    if [[ "$key_kind" != "private" ]]; then
      echo -e "  ${UI_WARNING}⚠ ${src_path##*/} não é uma chave privada válida (${key_kind}); cópia ignorada.${UI_RESET}"
      return 1
    fi
  fi

  if ! cp "$src_path" "$dest_path"; then
    echo -e "  ${UI_WARNING}⚠ Falha ao copiar ${src_path##*/}.${UI_RESET}"
    return 1
  fi

  if _ssh_is_identity_file "$src_path"; then
    _ssh_sync_public_key "$src_path" "$dest_path"
  fi

  return 0
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
      if _ssh_copy_entry "$src_path" "$dest_path"; then
        echo -e "  ${UI_GREEN}✓ Substituído: ${key_name}${UI_RESET}"
      fi
      ;;
    r|renomear)
      local new_name=""
      while true; do
        read -r -p "  Novo nome (ex: id_ed25519_work): " new_name
        [[ -z "$new_name" ]] && { echo -e "  ${UI_WARNING}Nome não pode ser vazio.${UI_RESET}"; continue; }
        [[ -f "$ssh_dest/$new_name" ]] && { echo -e "  ${UI_WARNING}${new_name} já existe.${UI_RESET}"; continue; }
        break
      done
      if _ssh_copy_entry "$src_path" "$ssh_dest/$new_name"; then
        echo -e "  ${UI_GREEN}✓ Copiado como: ${new_name}${UI_RESET}"
      fi
      ;;
    d|deletar)
      if _ssh_is_identity_file "$dest_path"; then
        rm -f "$dest_path" "${dest_path}.pub"
      else
        rm -f "$dest_path"
      fi
      if _ssh_copy_entry "$src_path" "$dest_path"; then
        echo -e "  ${UI_GREEN}✓ Existente removido e substituído: ${key_name}${UI_RESET}"
      fi
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

  # Coletar chaves privadas válidas + arquivos auxiliares esperados em ~/.ssh
  local source_keys=()
  while IFS= read -r -d '' key; do
    local key_name key_kind
    key_name=$(basename "$key")
    case "$key_name" in
      *.pub|authorized_keys|authorized_keys.*)
        continue
        ;;
      known_hosts|known_hosts.*|config)
        source_keys+=("$key")
        continue
        ;;
    esac

    key_kind=$(_ssh_key_kind "$key")
    [[ "$key_kind" == "private" ]] && source_keys+=("$key")
  done < <(find "$ssh_source" -maxdepth 1 -type f -print0 2>/dev/null)

  if [[ ${#source_keys[@]} -eq 0 ]]; then
    echo -e "  ${UI_INFO}ℹ Nenhuma chave SSH encontrada em ${ssh_source}${UI_RESET}"
    return
  fi

  # Mapear fingerprints existentes no destino
  declare -A dest_fingerprints
  if [[ -d "$ssh_dest" ]]; then
    while IFS= read -r -d '' existing_key; do
      local fp
      _ssh_is_identity_file "$existing_key" || continue
      fp=$(get_ssh_key_fingerprint "$existing_key")
      [[ "$fp" != "unknown" ]] && [[ "$fp" != "not_a_key" ]] && dest_fingerprints["$fp"]="$existing_key"
    done < <(find "$ssh_dest" -maxdepth 1 -type f -print0 2>/dev/null)
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
    if _ssh_copy_entry "$key_path" "$dest_path"; then
      echo -e "  ${UI_GREEN}✓ Copiado: ${key_name}${UI_RESET}"
    fi
  done
}

set_ssh_permissions() {
  if [[ -d "$HOME/.ssh" ]]; then
    chmod 700 "$HOME/.ssh"
    find "$HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
    find "$HOME/.ssh" -type d -exec chmod 700 {} + 2>/dev/null || true
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


# ══════════════════════════════════════════════════════════════════════════════
# RESUMO DE SELEÇÕES INTERATIVAS
# ══════════════════════════════════════════════════════════════════════════════

_rv_div() {
  local w="$1" title="$2"
  local pad_left="${left_pad:-0}"
  local divider_color="${rv_divider_color:-$UI_BORDER}"
  local section_color="${rv_section_color:-${UI_LAVENDER:-$UI_ACCENT}}"
  local title_vis fill fill_str
  title_vis=$(_visible_len "$title")
  fill=$(( w - title_vis - 4 ))
  [[ $fill -lt 0 ]] && fill=0
  printf -v fill_str '%*s' "$fill" ''
  printf "%*s%b\n" "$pad_left" "" "${divider_color}── ${section_color}${UI_BOLD}${title}${UI_RESET}${divider_color} ${fill_str// /─}${UI_RESET}"
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

    local width=$((term_width > 98 ? 92 : term_width - 6))
    [[ $width -lt 48 ]] && width=48
    local left_pad=2
    local rv_divider_color="${UI_OVERLAY1:-$UI_BORDER}"
    local rv_section_color="${UI_MAUVE:-$UI_ACCENT}"
    local rv_label_color="${UI_LAVENDER:-$UI_ACCENT}"

    local total_pkgs total_cfgs
    total_pkgs=$(_count_total_packages)
    total_cfgs=$(_count_configs_to_copy)

    local actions_to_do=()
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]] && actions_to_do+=("Git")
    [[ ${INSTALL_POWERLEVEL10K:-0} -eq 1 ]] && actions_to_do+=("P10k")
    [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && actions_to_do+=("Starship")
    [[ ${INSTALL_OH_MY_POSH:-0} -eq 1 ]] && actions_to_do+=("OMP")
    [[ ${COPY_SSH_KEYS:-0} -eq 1 ]] && actions_to_do+=("SSH")
    local actions_plain="${UI_DIM}(nenhum)${UI_RESET}"
    [[ ${#actions_to_do[@]} -gt 0 ]] && actions_plain="${UI_TEXT}$(_join_items "${actions_to_do[@]}")${UI_RESET}"

    local so_color="$UI_TEAL"
    local so_icon="🐧"
    local so_name="${TARGET_OS:-linux}"
    if [[ "${TARGET_OS:-linux}" == "macos" ]]; then
      so_color="$UI_PEACH"
      so_icon="🍎"
      so_name="macOS"
    elif [[ "${TARGET_OS:-linux}" == "windows" ]]; then
      so_color="$UI_BLUE"
      so_icon="⊞"
      so_name="Windows"
    elif [[ "${TARGET_OS:-linux}" == "wsl2" ]]; then
      so_color="$UI_SKY"
      so_name="WSL2"
    else
      so_name="Linux"
    fi

    echo ""
    _rv_hbar "$width"
    printf "%*s%b\n" "$left_pad" "" "  ${UI_GREEN}${UI_BOLD}RESUMO FINAL${UI_RESET}"
    printf "%*s%b\n" "$left_pad" "" "  ${UI_SUBTEXT1}Revise o plano abaixo. Use ${UI_YELLOW}${UI_BOLD}0-8${UI_RESET}${UI_SUBTEXT1} para ajustar qualquer grupo antes de iniciar.${UI_RESET}"
    _rv_hbar "$width"
    echo ""

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

    _rv_lv() {
      local lbl_w="$1" label="$2" empty_val="$3"
      shift 3
      local items=("$@")
      local pad_left="${left_pad:-0}"
      local label_color="${rv_label_color:-$UI_MUTED}"
      local label_str="${label}:"
      local label_vis pad label_col
      label_vis=$(_visible_len "$label_str")
      pad=$(( lbl_w - label_vis ))
      [[ $pad -lt 0 ]] && pad=0
      printf -v label_col '%s%*s' "$label_str" "$pad" ''
      local value_w=$(( width - lbl_w - 4 ))
      [[ $value_w -lt 10 ]] && value_w=10
      if [[ ${#items[@]} -eq 0 ]]; then
        printf "%*s  ${label_color}%s${UI_RESET}${UI_DIM}%s${UI_RESET}\n" "$pad_left" "" "$label_col" "$empty_val"
        return
      fi
      local -a lines=()
      local line="" item candidate
      for item in "${items[@]}"; do
        if [[ -z "$line" ]]; then
          line="$item"
          continue
        fi
        candidate="${line}, ${item}"
        if (( $(_visible_len "$candidate") > value_w )); then
          lines+=("${line},")
          line="$item"
        else
          line="$candidate"
        fi
      done
      [[ -n "$line" ]] && lines+=("$line")
      printf "%*s  ${label_color}%s${UI_RESET}${UI_TEXT}%s${UI_RESET}\n" "$pad_left" "" "$label_col" "${lines[0]}"
      local indent
      printf -v indent '%*s' "$((lbl_w + 2))" ''
      local i
      for (( i=1; i<${#lines[@]}; i++ )); do
        printf "%*s  %s${UI_TEXT}%s${UI_RESET}\n" "$pad_left" "" "$indent" "${lines[i]}"
      done
    }

    _rv_kv() {
      local lbl_w="$1" label="$2" value="$3"
      local pad_left="${left_pad:-0}"
      local label_color="${rv_label_color:-$UI_MUTED}"
      local label_str="${label}:"
      local label_vis pad label_col
      label_vis=$(_visible_len "$label_str")
      pad=$(( lbl_w - label_vis ))
      [[ $pad -lt 0 ]] && pad=0
      printf -v label_col '%s%*s' "$label_str" "$pad" ''
      local value_w=$(( width - lbl_w - 4 ))
      [[ $value_w -lt 10 ]] && value_w=10
      local -a lines=()
      _wrap_text "$value" "$value_w" lines
      [[ ${#lines[@]} -eq 0 ]] && lines=("$value")
      printf "%*s  ${label_color}%s${UI_RESET}%b\n" "$pad_left" "" "$label_col" "${lines[0]}"
      local indent
      printf -v indent '%*s' "$((lbl_w + 2))" ''
      local i
      for (( i=1; i<${#lines[@]}; i++ )); do
        printf "%*s  %s%b\n" "$pad_left" "" "$indent" "${lines[i]}"
      done
    }

    _rv_cfg_item() {
      local available="$1" selected_flag="$2" name="$3"
      if [[ $available -eq 1 ]]; then
        if [[ $selected_flag -eq 1 ]]; then
          echo "${UI_GREEN}${UI_BOLD}✓${UI_RESET} ${UI_TEXT}${name}${UI_RESET}"
        else
          echo "${UI_DIM}✗ ${name}${UI_RESET}"
        fi
      fi
    }

    _rv_cfg_row() {
      local lbl_w="$1" label="$2" arr_name="$3"
      local -n _cfg_ref="$arr_name"
      [[ ${#_cfg_ref[@]} -eq 0 ]] && return
      local pad_left="${left_pad:-0}"
      local label_color="${rv_label_color:-$UI_MUTED}"
      local label_str="${label}:"
      local label_vis pad label_col
      label_vis=$(_visible_len "$label_str")
      pad=$(( lbl_w - label_vis ))
      [[ $pad -lt 0 ]] && pad=0
      printf -v label_col '%s%*s' "$label_str" "$pad" ''
      local value_w=$(( width - lbl_w - 4 ))
      [[ $value_w -lt 10 ]] && value_w=10
      local -a lines=()
      local line="" item candidate
      for item in "${_cfg_ref[@]}"; do
        if [[ -z "$line" ]]; then
          line="$item"
          continue
        fi
        candidate="${line}  ${item}"
        if (( $(_visible_len "$candidate") > value_w )); then
          lines+=("$line")
          line="$item"
        else
          line="$candidate"
        fi
      done
      [[ -n "$line" ]] && lines+=("$line")
      printf "%*s  ${label_color}%s${UI_RESET}%b\n" "$pad_left" "" "$label_col" "${lines[0]}"
      local indent
      printf -v indent '%*s' "$((lbl_w + 2))" ''
      local i
      for (( i=1; i<${#lines[@]}; i++ )); do
        printf "%*s  %s%b\n" "$pad_left" "" "$indent" "${lines[i]}"
      done
    }

    _rv_menu_cell() {
      local num="$1" label="$2" cell_w="$3"
      local cell_plain="${num} ${label}"
      local pad=$(( cell_w - $(_visible_len "$cell_plain") ))
      [[ $pad -lt 0 ]] && pad=0
      printf "${UI_YELLOW}${UI_BOLD}%s${UI_RESET} ${UI_SUBTEXT1}%s${UI_RESET}%*s" "$num" "$label" "$pad" ""
    }

    local env_label_w tools_label_w apps_label_w cfg_label_w
    env_label_w=$(_rv_measure_label_width 10 "Shells" "Terminais" "Temas" "Fontes")
    tools_label_w=$(_rv_measure_label_width 10 "CLI" "IA" "Runtimes")
    apps_label_w=$(_rv_measure_label_width 12 "IDEs" "Navegadores" "Dev Tools" "Bancos" "Produtividade" "Comunicação" "Mídia" "Utilitários")
    cfg_label_w=$(_rv_measure_label_width 12 "Shells" "Terminais" "Editores" "Runtimes" "Ferramentas")

    _rv_kv 15 "Pacotes" "${UI_PEACH}${UI_BOLD}${total_pkgs}${UI_RESET} ${UI_TEXT}selecionados${UI_RESET}"
    _rv_kv 15 "Configs" "${UI_BLUE}${UI_BOLD}${total_cfgs}${UI_RESET} ${UI_TEXT}para copiar${UI_RESET}"
    _rv_kv 15 "Sistema" "${so_color}${UI_BOLD}${so_icon} ${so_name}${UI_RESET}"
    _rv_kv 15 "Ações extras" "${actions_plain}"
    _rv_kv 15 "Backup" "${UI_DIM}${BACKUP_DIR}${UI_RESET}"
    echo ""

    _rv_div "$width" "🏠 AMBIENTE"
    _rv_lv "$env_label_w" "Shells"    "(nenhum)"  "${selected_shells[@]}"
    _rv_lv "$env_label_w" "Terminais" "(nenhum)"  "${SELECTED_TERMINALS[@]}"
    _rv_lv "$env_label_w" "Temas"     "(nenhum)"  "${themes_selected[@]}"
    _rv_lv "$env_label_w" "Fontes"    "(nenhuma)" "${SELECTED_NERD_FONTS[@]}"
    echo ""

    _rv_div "$width" "🔧 FERRAMENTAS"
    _rv_lv "$tools_label_w" "CLI"      "(nenhuma)" "${SELECTED_CLI_TOOLS[@]}"
    _rv_lv "$tools_label_w" "IA"       "(nenhuma)" "${SELECTED_IA_TOOLS[@]}"
    _rv_lv "$tools_label_w" "Runtimes" "(nenhum)"  "${SELECTED_RUNTIMES[@]}"
    echo ""

    local gui_total=0
    gui_total=$((${#SELECTED_IDES[@]} + ${#SELECTED_BROWSERS[@]} + ${#SELECTED_DEV_TOOLS[@]} + \
                 ${#SELECTED_DATABASES[@]} + ${#SELECTED_PRODUCTIVITY[@]} + \
                 ${#SELECTED_COMMUNICATION[@]} + ${#SELECTED_MEDIA[@]} + ${#SELECTED_UTILITIES[@]}))
    if [[ $gui_total -gt 0 ]]; then
      _rv_div "$width" "🖥 APPS GUI"
      [[ ${#SELECTED_IDES[@]} -gt 0 ]]          && _rv_lv "$apps_label_w" "IDEs"          "" "${SELECTED_IDES[@]}"
      [[ ${#SELECTED_BROWSERS[@]} -gt 0 ]]      && _rv_lv "$apps_label_w" "Navegadores"   "" "${SELECTED_BROWSERS[@]}"
      [[ ${#SELECTED_DEV_TOOLS[@]} -gt 0 ]]     && _rv_lv "$apps_label_w" "Dev Tools"     "" "${SELECTED_DEV_TOOLS[@]}"
      [[ ${#SELECTED_DATABASES[@]} -gt 0 ]]     && _rv_lv "$apps_label_w" "Bancos"        "" "${SELECTED_DATABASES[@]}"
      [[ ${#SELECTED_PRODUCTIVITY[@]} -gt 0 ]]  && _rv_lv "$apps_label_w" "Produtividade" "" "${SELECTED_PRODUCTIVITY[@]}"
      [[ ${#SELECTED_COMMUNICATION[@]} -gt 0 ]] && _rv_lv "$apps_label_w" "Comunicação"   "" "${SELECTED_COMMUNICATION[@]}"
      [[ ${#SELECTED_MEDIA[@]} -gt 0 ]]         && _rv_lv "$apps_label_w" "Mídia"         "" "${SELECTED_MEDIA[@]}"
      [[ ${#SELECTED_UTILITIES[@]} -gt 0 ]]     && _rv_lv "$apps_label_w" "Utilitários"   "" "${SELECTED_UTILITIES[@]}"
      echo ""
    fi

    # ── COPIAR CONFIGURAÇÕES ──
    local cfg_shells=()
    [[ ${INSTALL_ZSH:-0} -eq 1 ]]     && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_ZSH_CONFIG:-0}"    "Zsh")")
    [[ ${INSTALL_FISH:-0} -eq 1 ]]    && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_FISH_CONFIG:-0}"   "Fish")")
    [[ ${INSTALL_NUSHELL:-0} -eq 1 ]] && cfg_shells+=("$(_rv_cfg_item 1 "${COPY_NUSHELL_CONFIG:-0}" "Nushell")")

    local cfg_terminals=()
    for term in "${SELECTED_TERMINALS[@]}"; do
      case "$term" in
        ghostty)   cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_TERMINAL_CONFIG:-0}"  "ghostty")") ;;
        kitty)     cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_KITTY_CONFIG:-0}"     "kitty")") ;;
        alacritty) cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_ALACRITTY_CONFIG:-0}" "alacritty")") ;;
        wezterm)   cfg_terminals+=("$(_rv_cfg_item 1 "${COPY_WEZTERM_CONFIG:-0}"   "wezterm")") ;;
      esac
    done

    local cfg_editors=()
    local has_neovim=0 has_vscode=0 has_zed=0 has_helix=0
    for ide in "${SELECTED_IDES[@]}"; do
      case "$ide" in
        neovim) has_neovim=1 ;; vscode) has_vscode=1 ;;
        zed)    has_zed=1    ;; helix)  has_helix=1   ;;
      esac
    done
    [[ $has_neovim -eq 1 ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_NVIM_CONFIG:-0}"     "Neovim")")
    [[ $has_vscode -eq 1 ]] && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_VSCODE_SETTINGS:-0}" "VSCode")")
    [[ $has_zed -eq 1    ]] && [[ -f "$CONFIG_SHARED/zed/settings.json" ]]  && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_ZED_CONFIG:-0}"   "Zed")")
    [[ $has_helix -eq 1  ]] && [[ -f "$CONFIG_SHARED/helix/config.toml" ]]  && cfg_editors+=("$(_rv_cfg_item 1 "${COPY_HELIX_CONFIG:-0}" "Helix")")

    local cfg_tools=()
    local has_tmux=0 has_lazygit=0 has_yazi=0 has_btop=0 has_bat=0 has_direnv=0
    for tool in "${SELECTED_CLI_TOOLS[@]}"; do
      case "$tool" in
        tmux)    has_tmux=1    ;; lazygit) has_lazygit=1 ;;
        yazi)    has_yazi=1    ;; btop)    has_btop=1     ;;
        bat)     has_bat=1     ;; direnv)  has_direnv=1   ;;
      esac
    done
    [[ $has_tmux -eq 1    ]] && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_TMUX_CONFIG:-0}"    "tmux")")
    [[ $has_lazygit -eq 1 ]] && [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]  && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_LAZYGIT_CONFIG:-0}" "lazygit")")
    [[ $has_yazi -eq 1    ]] && [[ -d "$CONFIG_SHARED/yazi" ]]                 && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_YAZI_CONFIG:-0}"    "yazi")")
    [[ $has_btop -eq 1    ]] && [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]       && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_BTOP_CONFIG:-0}"    "btop")")
    [[ $has_bat -eq 1     ]] && [[ -f "$CONFIG_SHARED/bat/config" ]]           && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_BAT_CONFIG:-0}"     "bat")")
    [[ $has_direnv -eq 1  ]] && [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]     && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_DIRENV_CONFIG:-0}"  "direnv")")
    [[ ${GIT_CONFIGURE:-0} -eq 1 ]]                                            && cfg_tools+=("$(_rv_cfg_item 1 "${COPY_GIT_CONFIG:-0}"     "Git")")

    local cfg_runtime=()
    [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && cfg_runtime+=("$(_rv_cfg_item 1 "${COPY_MISE_CONFIG:-0}"     "Mise")")
    [[ ${INSTALL_STARSHIP:-0} -eq 1    ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]] && cfg_runtime+=("$(_rv_cfg_item 1 "${COPY_STARSHIP_CONFIG:-0}" "Starship")")

    _rv_div "$width" "📋 COPIAR CONFIGURAÇÕES"
    _rv_cfg_row "$cfg_label_w" "Shells"      "cfg_shells"
    _rv_cfg_row "$cfg_label_w" "Terminais"   "cfg_terminals"
    _rv_cfg_row "$cfg_label_w" "Editores"    "cfg_editors"
    _rv_cfg_row "$cfg_label_w" "Runtimes"    "cfg_runtime"
    _rv_cfg_row "$cfg_label_w" "Ferramentas" "cfg_tools"

    local has_any_cfg=0
    [[ ${#cfg_shells[@]} -gt 0    || ${#cfg_editors[@]} -gt 0   || \
       ${#cfg_tools[@]} -gt 0     || ${#cfg_terminals[@]} -gt 0 || \
       ${#cfg_runtime[@]} -gt 0 ]] && has_any_cfg=1
    if [[ $has_any_cfg -eq 0 ]]; then
      printf "%*s  ${UI_DIM}(nenhuma configuração disponível)${UI_RESET}\n" "$left_pad" ""
    fi

    echo ""
    _rv_div "$width" "✏️ AJUSTAR SELEÇÕES"
    printf "%*s%b\n" "$left_pad" "" "  ${UI_SUBTEXT1}Digite o número da seção que deseja revisar:${UI_RESET}"
    echo ""

    local menu_numbers=(0 1 2 3 4 5 6 7 8)
    local menu_labels=("Configs" "Shells" "Fontes" "Terminais" "CLI" "IA" "Apps GUI" "Runtimes" "Git")
    local menu_cols=3
    [[ $width -lt 64 ]] && menu_cols=2
    [[ $width -lt 48 ]] && menu_cols=1
    local menu_gap=3
    local menu_cell_w=$(( (width - (menu_gap * (menu_cols - 1)) - 2) / menu_cols ))
    [[ $menu_cell_w -lt 14 ]] && menu_cell_w=14
    local i
    for (( i=0; i<${#menu_numbers[@]}; i++ )); do
      if (( i % menu_cols == 0 )); then
        printf "%*s  " "$left_pad" ""
      fi
      _rv_menu_cell "${menu_numbers[i]}" "${menu_labels[i]}" "$menu_cell_w"
      if (( (i + 1) % menu_cols == 0 || i == ${#menu_numbers[@]} - 1 )); then
        echo ""
      else
        printf "%*s" "$menu_gap" ""
      fi
    done
    echo ""
    printf "%*s  ${UI_GREEN}${UI_BOLD}Enter${UI_RESET} ${UI_SUBTEXT1}iniciar instalação${UI_RESET}   ${UI_RED}${UI_BOLD}S${UI_RESET} ${UI_SUBTEXT1}sair${UI_RESET}\n" "$left_pad" ""

    _rv_hbar "$width"
    echo ""
    read -r -p "$(printf '%*s  → ' "$left_pad" '')" choice

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
        ask_nerd_fonts
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
        _toggle_configs
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
# TOGGLE CONFIGS — toggle inline rápido no RESUMO FINAL (opção 0)
# ══════════════════════════════════════════════════════════════════════════════
_toggle_configs() {
  local cfg_names=()
  local cfg_keys=()
  local cfg_labels=()

  [[ ${INSTALL_ZSH:-0} -eq 1 ]]      && cfg_names+=("Zsh")      && cfg_keys+=("COPY_ZSH_CONFIG")
  [[ ${INSTALL_FISH:-0} -eq 1 ]]     && cfg_names+=("Fish")     && cfg_keys+=("COPY_FISH_CONFIG")
  [[ ${INSTALL_NUSHELL:-0} -eq 1 ]]  && cfg_names+=("Nushell")  && cfg_keys+=("COPY_NUSHELL_CONFIG")
  [[ ${GIT_CONFIGURE:-0} -eq 1 ]]    && cfg_names+=("Git")      && cfg_keys+=("COPY_GIT_CONFIG")

  local _ide
  for _ide in "${SELECTED_IDES[@]}"; do
    case "$_ide" in
      neovim)       [[ -d "$CONFIG_SHARED/nvim" ]]                 && cfg_names+=("Neovim")  && cfg_keys+=("COPY_NVIM_CONFIG") ;;
      vscode|cursor) [[ -f "$CONFIG_SHARED/vscode/settings.json" ]] && cfg_names+=("VSCode")  && cfg_keys+=("COPY_VSCODE_SETTINGS") ;;
      zed)          [[ -f "$CONFIG_SHARED/zed/settings.json" ]]    && cfg_names+=("Zed")     && cfg_keys+=("COPY_ZED_CONFIG") ;;
      helix)        [[ -f "$CONFIG_SHARED/helix/config.toml" ]]    && cfg_names+=("Helix")   && cfg_keys+=("COPY_HELIX_CONFIG") ;;
    esac
  done

  local _tool
  for _tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$_tool" in
      tmux)    [[ -d "$CONFIG_SHARED/tmux" ]]                && cfg_names+=("tmux")    && cfg_keys+=("COPY_TMUX_CONFIG") ;;
      lazygit) [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]  && cfg_names+=("lazygit") && cfg_keys+=("COPY_LAZYGIT_CONFIG") ;;
      yazi)    [[ -d "$CONFIG_SHARED/yazi" ]]                 && cfg_names+=("yazi")    && cfg_keys+=("COPY_YAZI_CONFIG") ;;
      btop)    [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]       && cfg_names+=("btop")    && cfg_keys+=("COPY_BTOP_CONFIG") ;;
      bat)     [[ -f "$CONFIG_SHARED/bat/config" ]]           && cfg_names+=("bat")     && cfg_keys+=("COPY_BAT_CONFIG") ;;
      ripgrep) [[ -f "$CONFIG_SHARED/.ripgreprc" ]]           && cfg_names+=("ripgrep") && cfg_keys+=("COPY_RIPGREP_CONFIG") ;;
      direnv)  [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]     && cfg_names+=("direnv")  && cfg_keys+=("COPY_DIRENV_CONFIG") ;;
    esac
  done

  local _ia
  for _ia in "${SELECTED_IA_TOOLS[@]}"; do
    [[ "$_ia" == "aider" ]] && [[ -f "$CONFIG_SHARED/aider/.aider.conf.yml" ]] && cfg_names+=("aider") && cfg_keys+=("COPY_AIDER_CONFIG")
  done

  local _term
  for _term in "${SELECTED_TERMINALS[@]}"; do
    case "$_term" in
      ghostty)   cfg_names+=("ghostty")   && cfg_keys+=("COPY_TERMINAL_CONFIG") ;;
      kitty)     [[ -f "$CONFIG_SHARED/kitty/kitty.conf" ]]       && cfg_names+=("kitty")     && cfg_keys+=("COPY_KITTY_CONFIG") ;;
      alacritty) [[ -f "$CONFIG_SHARED/alacritty/alacritty.toml" ]] && cfg_names+=("alacritty") && cfg_keys+=("COPY_ALACRITTY_CONFIG") ;;
      wezterm)   [[ -f "$CONFIG_SHARED/wezterm/wezterm.lua" ]]     && cfg_names+=("wezterm")   && cfg_keys+=("COPY_WEZTERM_CONFIG") ;;
    esac
  done

  [[ ${INSTALL_STARSHIP:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]] && cfg_names+=("Starship") && cfg_keys+=("COPY_STARSHIP_CONFIG")
  [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] && cfg_names+=("Mise") && cfg_keys+=("COPY_MISE_CONFIG")

  local _rt
  for _rt in "${SELECTED_RUNTIMES[@]}"; do
    case "$_rt" in
      node)   [[ -f "$CONFIG_SHARED/npm/.npmrc" ]]       && cfg_names+=("npm")   && cfg_keys+=("COPY_NPM_CONFIG") ;;
      python) [[ -f "$CONFIG_SHARED/pip/pip.conf" ]]     && cfg_names+=("pip")   && cfg_keys+=("COPY_PIP_CONFIG") ;;
      rust)   [[ -f "$CONFIG_SHARED/cargo/config.toml" ]] && cfg_names+=("cargo") && cfg_keys+=("COPY_CARGO_CONFIG") ;;
    esac
  done

  local _dt
  for _dt in "${SELECTED_DEV_TOOLS[@]}"; do
    [[ "$_dt" == "docker" ]] && [[ -f "$CONFIG_SHARED/docker/config.json" ]] && cfg_names+=("Docker") && cfg_keys+=("COPY_DOCKER_CONFIG")
  done

  if [[ ${#cfg_names[@]} -eq 0 ]]; then
    msg "  ℹ️  Nenhuma configuração disponível."
    sleep 1
    return
  fi

  while true; do
    clear_screen
    echo ""
    echo -e "  ${UI_ACCENT}${UI_BOLD}📋 Toggle Configs${UI_RESET}  ${UI_MUTED}(digite número para alternar, Enter para voltar)${UI_RESET}"
    echo ""

    local i cols=3
    local col_w=25
    local count=${#cfg_names[@]}

    for (( i=0; i<count; i++ )); do
      local key="${cfg_keys[$i]}"
      local val="${!key:-0}"
      local icon="${UI_DIM}✗${UI_RESET}"
      [[ $val -eq 1 ]] && icon="${UI_GREEN}${UI_BOLD}✓${UI_RESET}"
      local num="${UI_PEACH}${UI_BOLD}$((i+1))${UI_RESET}"
      printf "  ${num} ${icon} ${UI_TEXT}%-16s${UI_RESET}" "${cfg_names[$i]}"
      if (( (i+1) % cols == 0 )); then
        echo ""
      fi
    done
    (( count % cols != 0 )) && echo ""
    echo ""

    local toggle_choice
    read -r -p "  → " toggle_choice

    [[ -z "$toggle_choice" ]] && return

    if [[ "$toggle_choice" =~ ^[0-9]+$ ]] && (( toggle_choice >= 1 && toggle_choice <= count )); then
      local idx=$((toggle_choice - 1))
      local key="${cfg_keys[$idx]}"
      local cur="${!key:-0}"
      if [[ $cur -eq 1 ]]; then
        eval "$key=0"
      else
        eval "$key=1"
      fi
    fi
  done
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

  record_failure "optional" "MongoDB Server não instalado automaticamente no Linux" "Instale o MongoDB Community Server manualmente para sua distro"
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

  local -a curl_args=(-fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --connect-timeout 10 --max-time 180)
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

  if is_truthy "$VERBOSE"; then
    "$shell_bin" "$temp_script" "${exec_args[@]}" || rc=$?
  else
    "$shell_bin" "$temp_script" "${exec_args[@]}" >/dev/null 2>&1 || rc=$?
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

copy_tool_configs() {
  msg "▶ Copiando configurações de ferramentas CLI"

  if [[ ${COPY_LAZYGIT_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/lazygit/config.yml" ]]; then
    copy_dir "$CONFIG_SHARED/lazygit" "$HOME/.config/lazygit"
  fi

  if [[ ${COPY_YAZI_CONFIG:-0} -eq 1 ]] && [[ -d "$CONFIG_SHARED/yazi" ]]; then
    copy_dir "$CONFIG_SHARED/yazi" "$HOME/.config/yazi"
  fi

  if [[ ${COPY_BTOP_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/btop/btop.conf" ]]; then
    copy_dir "$CONFIG_SHARED/btop" "$HOME/.config/btop"
  fi

  if [[ ${COPY_BAT_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/bat/config" ]]; then
    copy_dir "$CONFIG_SHARED/bat" "$HOME/.config/bat"
  fi

  if [[ ${COPY_KITTY_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/kitty/kitty.conf" ]]; then
    copy_dir "$CONFIG_SHARED/kitty" "$HOME/.config/kitty"
  fi

  if [[ ${COPY_ALACRITTY_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/alacritty/alacritty.toml" ]]; then
    copy_dir "$CONFIG_SHARED/alacritty" "$HOME/.config/alacritty"
    if [[ "${TARGET_OS:-linux}" == "macos" ]]; then
      sed -i'' 's/command = "xdg-open"/command = "open"/' "$HOME/.config/alacritty/alacritty.toml" 2>/dev/null
    fi
  fi

  if [[ ${COPY_WEZTERM_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/wezterm/wezterm.lua" ]]; then
    copy_dir "$CONFIG_SHARED/wezterm" "$HOME/.config/wezterm"
  fi

  if [[ ${COPY_RIPGREP_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/.ripgreprc" ]]; then
    copy_file "$CONFIG_SHARED/.ripgreprc" "$HOME/.ripgreprc"
  fi

  if [[ ${COPY_NPM_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/npm/.npmrc" ]]; then
    copy_file "$CONFIG_SHARED/npm/.npmrc" "$HOME/.npmrc"
  fi

  if [[ ${COPY_PNPM_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/pnpm/.pnpmrc" ]]; then
    mkdir -p "$HOME/.config/pnpm"
    copy_file "$CONFIG_SHARED/pnpm/.pnpmrc" "$HOME/.config/pnpm/.pnpmrc"
  fi

  if [[ ${COPY_YARN_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/yarn/.yarnrc" ]]; then
    copy_file "$CONFIG_SHARED/yarn/.yarnrc" "$HOME/.yarnrc"
  fi

  if [[ ${COPY_PIP_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/pip/pip.conf" ]]; then
    mkdir -p "$HOME/.config/pip"
    copy_file "$CONFIG_SHARED/pip/pip.conf" "$HOME/.config/pip/pip.conf"
  fi

  if [[ ${COPY_CARGO_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/cargo/config.toml" ]]; then
    mkdir -p "$HOME/.cargo"
    copy_file "$CONFIG_SHARED/cargo/config.toml" "$HOME/.cargo/config.toml"
  fi

  if [[ ${COPY_ZED_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/zed/settings.json" ]]; then
    mkdir -p "$HOME/.config/zed"
    copy_file "$CONFIG_SHARED/zed/settings.json" "$HOME/.config/zed/settings.json"
  fi

  if [[ ${COPY_HELIX_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/helix/config.toml" ]]; then
    mkdir -p "$HOME/.config/helix"
    copy_file "$CONFIG_SHARED/helix/config.toml" "$HOME/.config/helix/config.toml"
  fi

  if [[ ${COPY_AIDER_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/aider/.aider.conf.yml" ]]; then
    copy_file "$CONFIG_SHARED/aider/.aider.conf.yml" "$HOME/.aider.conf.yml"
  fi

  if [[ ${COPY_DOCKER_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/docker/config.json" ]]; then
    mkdir -p "$HOME/.docker"
    copy_file "$CONFIG_SHARED/docker/config.json" "$HOME/.docker/config.json"
  fi

  if [[ ${COPY_DIRENV_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/direnv/.direnvrc" ]]; then
    mkdir -p "$HOME/.config/direnv"
    copy_file "$CONFIG_SHARED/direnv/.direnvrc" "$HOME/.config/direnv/direnvrc"
  fi
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

apply_shared_configs() {
  msg "▶ Copiando configs compartilhadas"

  if is_truthy "$INSTALL_FISH" && has_cmd fish && [[ ${COPY_FISH_CONFIG:-0} -eq 1 ]]; then
    local preserved_fish_config=""
    preserved_fish_config="$(extract_user_path_config_fish)"

    copy_dir "$CONFIG_SHARED/fish" "$HOME/.config/fish"
    normalize_crlf_to_lf "$HOME/.config/fish/config.fish"

    if [[ -n "$preserved_fish_config" ]]; then
      msg "  🔄 Verificando configurações de PATH para preservar..."
      append_preserved_config "$HOME/.config/fish/config.fish" "$preserved_fish_config"
    fi
  elif is_truthy "$INSTALL_FISH" && [[ ${COPY_FISH_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Fish config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_FISH" && ! has_cmd fish; then
    msg "  ⚠️ Fish não encontrado, pulando config."
  fi

  if is_truthy "$INSTALL_ZSH" && has_cmd zsh && [[ ${COPY_ZSH_CONFIG:-0} -eq 1 ]]; then
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
  elif is_truthy "$INSTALL_ZSH" && [[ ${COPY_ZSH_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Zsh config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_ZSH" && ! has_cmd zsh; then
    msg "  ⚠️ Zsh não encontrado, pulando .zshrc."
  fi

  if is_truthy "$INSTALL_NUSHELL" && has_cmd nu && [[ ${COPY_NUSHELL_CONFIG:-0} -eq 1 ]]; then
    mkdir -p "$HOME/.config/nushell"
    copy_file "$CONFIG_SHARED/nushell/config.nu" "$HOME/.config/nushell/config.nu"
    copy_file "$CONFIG_SHARED/nushell/env.nu" "$HOME/.config/nushell/env.nu"
    mkdir -p "$HOME/.config/nushell/scripts"
  elif is_truthy "$INSTALL_NUSHELL" && [[ ${COPY_NUSHELL_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Nushell config: usuário optou por não copiar"
  elif is_truthy "$INSTALL_NUSHELL" && ! has_cmd nu; then
    msg "  ⚠️ Nushell não encontrado após instalação, pulando config."
  fi

  if has_cmd git && [[ ${COPY_GIT_CONFIG:-0} -eq 1 ]]; then
    # Se GIT_CONFIGURE=1, a geração dinâmica (install_git_configuration) vai
    # sobrescrever esses arquivos. Copiar apenas quando NÃO há config interativo,
    # para preservar o backup correto do original do usuário.
    if [[ ${GIT_CONFIGURE:-0} -eq 1 ]]; then
      msg "  ℹ️  Git config: será gerado interativamente (pulando cópia estática)"
    else
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
    fi
  elif [[ ${COPY_GIT_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Git config: usuário optou por não copiar"
  elif ! has_cmd git; then
    msg "  ⚠️ Git não encontrado, pulando .gitconfig."
  fi

  if has_cmd mise && [[ ${COPY_MISE_CONFIG:-0} -eq 1 ]]; then
    copy_dir "$CONFIG_SHARED/mise" "$HOME/.config/mise"
  elif [[ ${COPY_MISE_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Mise config: usuário optou por não copiar"
  elif ! has_cmd mise; then
    msg "  ⚠️ Mise não encontrado, pulando config."
  fi

  if has_cmd starship && [[ ${COPY_STARSHIP_CONFIG:-0} -eq 1 ]] && [[ -f "$CONFIG_SHARED/starship.toml" ]]; then
    mkdir -p "$HOME/.config"
    copy_file "$CONFIG_SHARED/starship.toml" "$HOME/.config/starship.toml"
  elif [[ ${COPY_STARSHIP_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Starship config: usuário optou por não copiar"
  elif ! has_cmd starship; then
    msg "  ⚠️ Starship não encontrado, pulando config."
  fi

  if has_cmd nvim && [[ ${COPY_NVIM_CONFIG:-0} -eq 1 ]]; then
    copy_dir "$CONFIG_SHARED/nvim" "$HOME/.config/nvim"
  elif [[ ${COPY_NVIM_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Neovim config: usuário optou por não copiar"
  elif ! has_cmd nvim; then
    msg "  ⚠️ Neovim não encontrado, pulando config."
  fi

  if has_cmd tmux && [[ ${COPY_TMUX_CONFIG:-0} -eq 1 ]]; then
    copy_file "$CONFIG_SHARED/tmux/.tmux.conf" "$HOME/.tmux.conf"
  elif [[ ${COPY_TMUX_CONFIG:-0} -eq 0 ]]; then
    msg "  ⏭️  Tmux config: usuário optou por não copiar"
  elif ! has_cmd tmux; then
    msg "  ⚠️ tmux não encontrado, pulando .tmux.conf."
  fi

  if [[ ${COPY_VSCODE_SETTINGS:-0} -eq 1 ]]; then
    copy_vscode_settings
  else
    msg "  ⏭️  VS Code settings: usuário optou por não copiar"
  fi

  copy_tool_configs
  install_bat_catppuccin_theme

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

  if [[ -f "$HOME/.config/bat/config" ]]; then
    mkdir -p "$CONFIG_SHARED/bat"
    export_file "$HOME/.config/bat/config" "$CONFIG_SHARED/bat/config"
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
