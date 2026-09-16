#!/usr/bin/env bats
#
# Regressao para o bug de subshell no BACKUP_DIR: _ensure_backup_dir() e
# BACKUP_DIR="" vivem no topo do install.sh (nao em lib/), e install.sh chama
# main() incondicionalmente na ultima linha. Nao da para dar "source" no
# arquivo inteiro sem rodar o instalador interativo, entao extraimos so o
# trecho sob teste (do "BACKUP_DIR=\"\"" ate o "}" da funcao) com sed e
# fazemos "source" so dele. Isso testa o codigo real do install.sh, nao uma
# copia reescrita aqui.
#
# Todo teste roda com HOME apontando para um diretorio temporario: nunca deve
# tocar em ~/.bkp-* de verdade.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_HOME="$(mktemp -d)"
}

teardown() {
  rm -rf "$FAKE_HOME"
}

@test "chamar a funcao de backup varias vezes cria um unico diretorio" {
  echo "zsh" > "$FAKE_HOME/.zshrc"
  echo "git" > "$FAKE_HOME/.gitconfig"
  echo "tmux" > "$FAKE_HOME/.tmux.conf"

  run env HOME="$FAKE_HOME" bash -c '
    source <(sed -n "/^BACKUP_DIR=\"\"/,/^}/p" "'"$REPO_ROOT"'/install.sh")
    source "'"$REPO_ROOT"'/lib/fileops.sh"

    msg() { :; }
    record_failure() { :; }
    MODE="install"

    backup_if_exists "$HOME/.zshrc"
    backup_if_exists "$HOME/.gitconfig"
    backup_if_exists "$HOME/.tmux.conf"
  '
  [ "$status" -eq 0 ]

  local dir_count
  dir_count=$(find "$FAKE_HOME" -maxdepth 1 -type d -name ".bkp-*" | wc -l)
  [ "$dir_count" -eq 1 ]
}

@test "BACKUP_DIR fica preenchido no processo apos as chamadas" {
  echo "zsh" > "$FAKE_HOME/.zshrc"

  run env HOME="$FAKE_HOME" bash -c '
    source <(sed -n "/^BACKUP_DIR=\"\"/,/^}/p" "'"$REPO_ROOT"'/install.sh")
    source "'"$REPO_ROOT"'/lib/fileops.sh"

    msg() { :; }
    record_failure() { :; }
    MODE="install"

    backup_if_exists "$HOME/.zshrc"

    [[ -n "$BACKUP_DIR" ]] || exit 1
    [[ "$BACKUP_DIR" == "$HOME"/.bkp-* ]] || exit 2
    echo "BACKUP_DIR=$BACKUP_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"BACKUP_DIR=$FAKE_HOME/.bkp-"* ]]
}

@test "arquivos salvos ficam todos dentro do mesmo diretorio de backup" {
  echo "zsh" > "$FAKE_HOME/.zshrc"
  echo "git" > "$FAKE_HOME/.gitconfig"

  run env HOME="$FAKE_HOME" bash -c '
    source <(sed -n "/^BACKUP_DIR=\"\"/,/^}/p" "'"$REPO_ROOT"'/install.sh")
    source "'"$REPO_ROOT"'/lib/fileops.sh"

    msg() { :; }
    record_failure() { :; }
    MODE="install"

    backup_if_exists "$HOME/.zshrc"
    backup_if_exists "$HOME/.gitconfig"

    [[ -f "$BACKUP_DIR/.zshrc" ]] || exit 1
    [[ -f "$BACKUP_DIR/.gitconfig" ]] || exit 2
  '
  [ "$status" -eq 0 ]
}

@test "_ensure_backup_dir e idempotente: chamadas repetidas nao trocam o diretorio" {
  run env HOME="$FAKE_HOME" bash -c '
    source <(sed -n "/^BACKUP_DIR=\"\"/,/^}/p" "'"$REPO_ROOT"'/install.sh")

    _ensure_backup_dir
    first="$BACKUP_DIR"

    _ensure_backup_dir
    second="$BACKUP_DIR"

    [[ -n "$first" ]] || exit 1
    [[ "$first" == "$second" ]] || exit 2
  '
  [ "$status" -eq 0 ]

  local dir_count
  dir_count=$(find "$FAKE_HOME" -maxdepth 1 -type d -name ".bkp-*" | wc -l)
  [ "$dir_count" -eq 1 ]
}
