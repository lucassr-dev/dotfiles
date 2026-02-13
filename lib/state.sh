#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════
# State Management — Gestão centralizada de estado
# ═══════════════════════════════════════════════════════════
#
# Substitui 50+ variáveis globais por um único associative array
# com API limpa para get/set/append/array operations.
#
# Uso:
#   state_set "system.os" "linux"
#   state_get "system.os"                    # → "linux"
#   state_append "selections.cli_tools" "fzf"
#   state_get_array "selections.cli_tools"   # → array
#   state_has "system.os"                    # → 0 (true)

declare -A DOTFILES_STATE=()

_state_ensure_map() {
  if ! declare -p DOTFILES_STATE 2>/dev/null | grep -q '^declare \-A'; then
    unset DOTFILES_STATE 2>/dev/null || true
    declare -g -A DOTFILES_STATE=()
  fi
}

state_set() {
  _state_ensure_map
  DOTFILES_STATE["$1"]="$2"
}

state_get() {
  _state_ensure_map
  local key="$1"
  local default="${2:-}"
  echo "${DOTFILES_STATE["$key"]:-$default}"
}

state_append() {
  _state_ensure_map
  local key="$1" value="$2"
  if [[ -n "${DOTFILES_STATE[$key]:-}" ]]; then
    DOTFILES_STATE["$key"]="${DOTFILES_STATE[$key]},$value"
  else
    DOTFILES_STATE["$key"]="$value"
  fi
}

state_get_array() {
  _state_ensure_map
  local key="$1"
  local csv="${DOTFILES_STATE[$key]:-}"
  [[ -z "$csv" ]] && return
  local IFS=','
  # shellcheck disable=SC2086
  echo $csv
}

state_get_array_into() {
  _state_ensure_map
  local key="$1"
  local -n _out_arr="$2"
  _out_arr=()
  local csv="${DOTFILES_STATE[$key]:-}"
  [[ -z "$csv" ]] && return
  IFS=',' read -ra _out_arr <<< "$csv"
}

state_has() {
  _state_ensure_map
  local key="$1"
  [[ -n "${DOTFILES_STATE["$key"]:-}" ]]
}

state_remove() {
  _state_ensure_map
  local key="$1"
  unset 'DOTFILES_STATE[$key]'
}

state_dump() {
  _state_ensure_map
  local key
  for key in $(printf '%s\n' "${!DOTFILES_STATE[@]}" | sort); do
    printf '%s=%s\n' "$key" "${DOTFILES_STATE[$key]}"
  done
}

state_save() {
  _state_ensure_map
  local file="${1:-$HOME/.dotfiles-state}"
  {
    echo "# Dotfiles state — $(date '+%Y-%m-%d %H:%M:%S')"
    local key
    for key in $(printf '%s\n' "${!DOTFILES_STATE[@]}" | sort); do
      printf 'state_set %q %q\n' "$key" "${DOTFILES_STATE[$key]}"
    done
  } > "$file"
}

state_load() {
  local file="${1:-$HOME/.dotfiles-state}"
  [[ -f "$file" ]] || return 1
  # shellcheck source=/dev/null
  source "$file"
}

state_clear() {
  _state_ensure_map
  DOTFILES_STATE=()
}

# ═══════════════════════════════════════════════════════════
# Compatibilidade — Ponte entre globals legadas e state
# ═══════════════════════════════════════════════════════════
#
# Durante a migração, estas funções sincronizam globals ↔ state.
# Serão removidas quando todas as funções usarem state diretamente.

_sync_globals_to_state() {
  # System
  state_set "system.os" "${TARGET_OS:-}"
  state_set "system.pkg_manager" "${LINUX_PKG_MANAGER:-}"
  state_set "system.mode" "${MODE:-install}"

  # Config flags
  state_set "config.install_zsh" "${INSTALL_ZSH:-1}"
  state_set "config.install_fish" "${INSTALL_FISH:-1}"
  state_set "config.install_nushell" "${INSTALL_NUSHELL:-0}"
  state_set "config.install_base_deps" "${INSTALL_BASE_DEPS:-1}"
  state_set "config.copy_terminal" "${COPY_TERMINAL_CONFIG:-1}"
  state_set "config.copy_vscode" "${COPY_VSCODE_SETTINGS:-1}"
  state_set "config.copy_ssh" "${COPY_SSH_KEYS:-0}"

  # Selections (arrays → csv)
  local arr
  if [[ ${#SELECTED_CLI_TOOLS[@]} -gt 0 ]]; then
    printf -v arr '%s,' "${SELECTED_CLI_TOOLS[@]}"
    state_set "selections.cli_tools" "${arr%,}"
  fi
  if [[ ${#SELECTED_IA_TOOLS[@]} -gt 0 ]]; then
    printf -v arr '%s,' "${SELECTED_IA_TOOLS[@]}"
    state_set "selections.ia_tools" "${arr%,}"
  fi
  if [[ ${#SELECTED_TERMINALS[@]} -gt 0 ]]; then
    printf -v arr '%s,' "${SELECTED_TERMINALS[@]}"
    state_set "selections.terminals" "${arr%,}"
  fi
  if [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]]; then
    printf -v arr '%s,' "${SELECTED_RUNTIMES[@]}"
    state_set "selections.runtimes" "${arr%,}"
  fi
  if [[ ${#SELECTED_NERD_FONTS[@]} -gt 0 ]]; then
    printf -v arr '%s,' "${SELECTED_NERD_FONTS[@]}"
    state_set "selections.fonts" "${arr%,}"
  fi
}

_sync_state_to_globals() {
  TARGET_OS="$(state_get 'system.os')"
  LINUX_PKG_MANAGER="$(state_get 'system.pkg_manager')"
  MODE="$(state_get 'system.mode' 'install')"

  INSTALL_ZSH="$(state_get 'config.install_zsh' '1')"
  INSTALL_FISH="$(state_get 'config.install_fish' '1')"
  INSTALL_NUSHELL="$(state_get 'config.install_nushell' '0')"
  INSTALL_BASE_DEPS="$(state_get 'config.install_base_deps' '1')"
  COPY_TERMINAL_CONFIG="$(state_get 'config.copy_terminal' '1')"
  COPY_VSCODE_SETTINGS="$(state_get 'config.copy_vscode' '1')"
  COPY_SSH_KEYS="$(state_get 'config.copy_ssh' '0')"

  state_get_array_into "selections.cli_tools" SELECTED_CLI_TOOLS
  state_get_array_into "selections.ia_tools" SELECTED_IA_TOOLS
  state_get_array_into "selections.terminals" SELECTED_TERMINALS
  state_get_array_into "selections.runtimes" SELECTED_RUNTIMES
  state_get_array_into "selections.fonts" SELECTED_NERD_FONTS
}
