#!/usr/bin/env bats
# Cobre a lógica de versionamento adicionada em 2026-07-19 (auditoria item 2):
# checkpoint agora grava o SHA do commit do repo e avisa no load se divergir.
# checkpoint_save/load dependem de vários globals do install.sh (SELECTED_*,
# GIT_*, COPY_*) -- declarados vazios/default aqui, igual o script real faz
# antes de sourcing os libs.

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
  export SCRIPT_VERSION="1.0.0"
  export TMP_HOME
  TMP_HOME="$(mktemp -d)"
  export HOME="$TMP_HOME"

  declare -gA DOTFILES_STATE=()
  declare -ga SELECTED_CLI_TOOLS=() SELECTED_IA_TOOLS=() SELECTED_TERMINALS=()
  declare -ga SELECTED_RUNTIMES=() SELECTED_NERD_FONTS=() SELECTED_IDES=()
  declare -ga SELECTED_BROWSERS=() SELECTED_DEV_TOOLS=() SELECTED_DATABASES=()
  declare -ga SELECTED_PRODUCTIVITY=() SELECTED_COMMUNICATION=() SELECTED_MEDIA=()
  declare -ga SELECTED_UTILITIES=() GIT_PERSONAL_DIRS=() GIT_WORK_DIRS=()

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/checkpoint.sh"
}

teardown() {
  rm -rf "$TMP_HOME"
}

@test "_current_repo_sha returns a non-empty value" {
  result="$(_current_repo_sha)"
  [ -n "$result" ]
}

@test "checkpoint_save writes CHECKPOINT_REPO_SHA to the file" {
  checkpoint_save "test-stage"
  grep -q "CHECKPOINT_REPO_SHA=" "$CHECKPOINT_FILE"
}

@test "checkpoint_save then checkpoint_load with matching SHA does not warn" {
  checkpoint_save "test-stage"
  run checkpoint_load
  [ "$status" -eq 0 ]
  [[ "$output" != *"versão diferente"* ]]
}

@test "checkpoint_load warns when CHECKPOINT_REPO_SHA does not match current" {
  checkpoint_save "test-stage"
  sed -i "s/CHECKPOINT_REPO_SHA=.*/CHECKPOINT_REPO_SHA='deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'/" "$CHECKPOINT_FILE"
  run checkpoint_load
  [ "$status" -eq 0 ]
  [[ "$output" == *"versão diferente"* ]]
}

@test "checkpoint_save then checkpoint_load roundtrips a state value" {
  state_set "test.roundtrip" "hello"
  checkpoint_save "test-stage"
  state_clear
  checkpoint_load
  result="$(state_get "test.roundtrip")"
  [ "$result" = "hello" ]
}

@test "checkpoint_exists reflects file presence" {
  ! checkpoint_exists
  checkpoint_save "test-stage"
  checkpoint_exists
}

@test "checkpoint_clear removes the checkpoint file" {
  checkpoint_save "test-stage"
  checkpoint_exists
  checkpoint_clear
  ! checkpoint_exists
}
