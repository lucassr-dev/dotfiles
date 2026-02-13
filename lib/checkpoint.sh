#!/usr/bin/env bash

CHECKPOINT_FILE="$HOME/.dotfiles-checkpoint"
CHECKPOINT_STAGE=""
RESUME_MODE=0

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
      for key in $(printf '%s\n' "${!_STATE[@]}" | sort); do
        printf 'state_set %q %q\n' "$key" "${_STATE[$key]}"
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
}

checkpoint_load() {
  if [[ -f "$CHECKPOINT_FILE" ]]; then
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
