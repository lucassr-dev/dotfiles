#!/usr/bin/env bash
# shellcheck disable=SC2034

CHECKPOINT_FILE="$HOME/.dotfiles-checkpoint"
CHECKPOINT_STAGE=""
RESUME_MODE=0

_checkpoint_file_is_secure() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  [[ -O "$file" ]] || return 1

  local perm=""
  if command -v stat >/dev/null 2>&1; then
    perm="$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null || true)"
  fi

  if [[ -n "$perm" ]] && [[ "$perm" =~ ^[0-7]{3,4}$ ]]; then
    local mode="$perm"
    [[ ${#mode} -eq 4 ]] && mode="${mode:1}"
    local group_digit="${mode:1:1}"
    local other_digit="${mode:2:1}"
    if (( 10#$group_digit != 0 || 10#$other_digit != 0 )); then
      return 1
    fi
  fi

  return 0
}

checkpoint_save() {
  local stage="$1"
  CHECKPOINT_STAGE="$stage"

  # Sincronizar globals atuais para state antes de salvar
  if declare -F _sync_globals_to_state >/dev/null 2>&1; then
    _sync_globals_to_state
  fi

  {
    echo "# Dotfiles Checkpoint - $(date)"
    echo "CHECKPOINT_STAGE=\"$stage\""

    # Salvar state centralizado
    if declare -F state_dump >/dev/null 2>&1; then
      local key
      for key in $(printf '%s\n' "${!DOTFILES_STATE[@]}" | sort); do
        printf 'state_set %q %q\n' "$key" "${DOTFILES_STATE[$key]}"
      done
    fi

    # Compatibilidade: salvar globals legadas para checkpoint antigos
    echo "INSTALL_ZSH=${INSTALL_ZSH:-1}"
    echo "INSTALL_FISH=${INSTALL_FISH:-1}"
    echo "INSTALL_NUSHELL=${INSTALL_NUSHELL:-0}"
    echo "INSTALL_OH_MY_ZSH=${INSTALL_OH_MY_ZSH:-0}"
    echo "INSTALL_STARSHIP=${INSTALL_STARSHIP:-0}"
    echo "INSTALL_OH_MY_POSH=${INSTALL_OH_MY_POSH:-0}"
    echo "INSTALL_POWERLEVEL10K=${INSTALL_POWERLEVEL10K:-0}"
    echo "GIT_CONFIGURE=${GIT_CONFIGURE:-0}"

    # Git multi-conta (necessário para install_git_configuration no resume)
    if [[ ${GIT_CONFIGURE:-0} -eq 1 ]]; then
      printf 'GIT_PERSONAL_NAME=%q\n' "${GIT_PERSONAL_NAME:-}"
      printf 'GIT_PERSONAL_EMAIL=%q\n' "${GIT_PERSONAL_EMAIL:-}"
      printf 'GIT_PERSONAL_USER=%q\n' "${GIT_PERSONAL_USER:-}"
      printf 'GIT_PERSONAL_SSH_KEY=%q\n' "${GIT_PERSONAL_SSH_KEY:-}"
      printf 'GIT_WORK_NAME=%q\n' "${GIT_WORK_NAME:-}"
      printf 'GIT_WORK_EMAIL=%q\n' "${GIT_WORK_EMAIL:-}"
      printf 'GIT_WORK_USER=%q\n' "${GIT_WORK_USER:-}"
      printf 'GIT_WORK_SSH_KEY=%q\n' "${GIT_WORK_SSH_KEY:-}"
      printf 'GIT_EDITOR=%q\n' "${GIT_EDITOR:-nvim}"
      printf 'GIT_PAGER=%q\n' "${GIT_PAGER:-delta}"
      echo "GIT_PERSONAL_DIRS=(${GIT_PERSONAL_DIRS[*]})"
      echo "GIT_WORK_DIRS=(${GIT_WORK_DIRS[*]})"
    fi

    # Flags de cópia de configs
    echo "COPY_GIT_CONFIG=${COPY_GIT_CONFIG:-0}"
    echo "COPY_SSH_KEYS=${COPY_SSH_KEYS:-0}"
    echo "COPY_ZSH_CONFIG=${COPY_ZSH_CONFIG:-0}"
    echo "COPY_FISH_CONFIG=${COPY_FISH_CONFIG:-0}"
    echo "COPY_NUSHELL_CONFIG=${COPY_NUSHELL_CONFIG:-0}"
    echo "COPY_NVIM_CONFIG=${COPY_NVIM_CONFIG:-0}"
    echo "COPY_VSCODE_SETTINGS=${COPY_VSCODE_SETTINGS:-0}"
    echo "COPY_TMUX_CONFIG=${COPY_TMUX_CONFIG:-0}"
    echo "COPY_TERMINAL_CONFIG=${COPY_TERMINAL_CONFIG:-0}"
    echo "COPY_KITTY_CONFIG=${COPY_KITTY_CONFIG:-0}"
    echo "COPY_ALACRITTY_CONFIG=${COPY_ALACRITTY_CONFIG:-0}"
    echo "COPY_WEZTERM_CONFIG=${COPY_WEZTERM_CONFIG:-0}"
    echo "COPY_MISE_CONFIG=${COPY_MISE_CONFIG:-0}"
    echo "COPY_STARSHIP_CONFIG=${COPY_STARSHIP_CONFIG:-0}"
    echo "COPY_LAZYGIT_CONFIG=${COPY_LAZYGIT_CONFIG:-0}"
    echo "COPY_YAZI_CONFIG=${COPY_YAZI_CONFIG:-0}"
    echo "COPY_BTOP_CONFIG=${COPY_BTOP_CONFIG:-0}"
    echo "COPY_BAT_CONFIG=${COPY_BAT_CONFIG:-0}"
    echo "COPY_DIRENV_CONFIG=${COPY_DIRENV_CONFIG:-0}"
    echo "COPY_ZED_CONFIG=${COPY_ZED_CONFIG:-0}"
    echo "COPY_HELIX_CONFIG=${COPY_HELIX_CONFIG:-0}"

    echo "SELECTED_CLI_TOOLS=(${SELECTED_CLI_TOOLS[*]})"
    echo "SELECTED_IA_TOOLS=(${SELECTED_IA_TOOLS[*]})"
    echo "SELECTED_TERMINALS=(${SELECTED_TERMINALS[*]})"
    echo "SELECTED_RUNTIMES=(${SELECTED_RUNTIMES[*]})"
    echo "SELECTED_NERD_FONTS=(${SELECTED_NERD_FONTS[*]})"
    echo "SELECTED_IDES=(${SELECTED_IDES[*]})"
    echo "SELECTED_BROWSERS=(${SELECTED_BROWSERS[*]})"
    echo "SELECTED_DEV_TOOLS=(${SELECTED_DEV_TOOLS[*]})"
    echo "SELECTED_DATABASES=(${SELECTED_DATABASES[*]})"
    echo "SELECTED_PRODUCTIVITY=(${SELECTED_PRODUCTIVITY[*]})"
    echo "SELECTED_COMMUNICATION=(${SELECTED_COMMUNICATION[*]})"
    echo "SELECTED_MEDIA=(${SELECTED_MEDIA[*]})"
    echo "SELECTED_UTILITIES=(${SELECTED_UTILITIES[*]})"
  } > "$CHECKPOINT_FILE"

  chmod 600 "$CHECKPOINT_FILE" 2>/dev/null || true
}

checkpoint_load() {
  if [[ -f "$CHECKPOINT_FILE" ]]; then
    if ! _checkpoint_file_is_secure "$CHECKPOINT_FILE"; then
      echo "⚠️ Checkpoint inseguro detectado em $CHECKPOINT_FILE (owner/permissões inválidos)." >&2
      return 1
    fi

    # shellcheck source=/dev/null
    source "$CHECKPOINT_FILE"

    # Sincronizar state carregado para globals
    if declare -F _sync_state_to_globals >/dev/null 2>&1; then
      _sync_state_to_globals
    fi
    return 0
  fi
  return 1
}

checkpoint_clear() {
  [[ -f "$CHECKPOINT_FILE" ]] && rm -f "$CHECKPOINT_FILE"
}

checkpoint_exists() {
  [[ -f "$CHECKPOINT_FILE" ]]
}
