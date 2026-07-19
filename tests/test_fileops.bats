#!/usr/bin/env bats
# fileops.sh nunca teve nenhum teste (achado de auditoria) apesar de ser onde
# vive a lógica de backup/cópia que todo o resto do instalador depende. Cobre
# só os caminhos mais arriscados: copy_file/copy_dir em modo real e DRY_RUN,
# e o skip por arquivo idêntico.

setup() {
  SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
  TMP_DIR="$(mktemp -d)"
  SRC_DIR="$TMP_DIR/src"
  DEST_DIR="$TMP_DIR/dest"
  BACKUP_DIR="$TMP_DIR/backup"
  mkdir -p "$SRC_DIR" "$DEST_DIR"

  DRY_RUN=0
  MODE="install"
  CRITICAL_ERRORS=()
  OPTIONAL_ERRORS=()
  COPIED_PATHS=()

  is_truthy() { case "${1:-}" in 1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;; *) return 1 ;; esac; }
  has_cmd() { command -v "$1" >/dev/null 2>&1; }
  msg() { printf '%b\n' "$1"; }
  warn() { msg "  ⚠️ $1"; }
  record_failure() { echo "FAIL[$1]: $2"; return 1; }
  UI_BORDER="" UI_RESET=""

  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/lib/fileops.sh"
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "copy_file copies a new file to destination" {
  echo "conteudo" > "$SRC_DIR/arquivo.txt"
  copy_file "$SRC_DIR/arquivo.txt" "$DEST_DIR/arquivo.txt"
  [ -f "$DEST_DIR/arquivo.txt" ]
  [ "$(cat "$DEST_DIR/arquivo.txt")" = "conteudo" ]
}

@test "copy_file is a no-op when source does not exist" {
  copy_file "$SRC_DIR/nao-existe.txt" "$DEST_DIR/arquivo.txt"
  [ ! -f "$DEST_DIR/arquivo.txt" ]
}

@test "copy_file skips when file is already identical" {
  echo "mesmo conteudo" > "$SRC_DIR/arquivo.txt"
  cp "$SRC_DIR/arquivo.txt" "$DEST_DIR/arquivo.txt"
  run copy_file "$SRC_DIR/arquivo.txt" "$DEST_DIR/arquivo.txt"
  [[ "$output" == *"inalterado"* ]]
}

@test "copy_file respects DRY_RUN (does not write destination)" {
  DRY_RUN=1
  echo "conteudo" > "$SRC_DIR/arquivo.txt"
  copy_file "$SRC_DIR/arquivo.txt" "$DEST_DIR/arquivo.txt"
  [ ! -f "$DEST_DIR/arquivo.txt" ]
}

@test "copy_file backs up an existing destination before overwriting" {
  echo "novo" > "$SRC_DIR/arquivo.txt"
  echo "antigo" > "$DEST_DIR/arquivo.txt"
  copy_file "$SRC_DIR/arquivo.txt" "$DEST_DIR/arquivo.txt"
  [ "$(cat "$DEST_DIR/arquivo.txt")" = "novo" ]
  [ -f "$BACKUP_DIR/arquivo.txt" ]
  [ "$(cat "$BACKUP_DIR/arquivo.txt")" = "antigo" ]
}

@test "copy_dir copies a directory tree recursively" {
  mkdir -p "$SRC_DIR/config/sub"
  echo "a" > "$SRC_DIR/config/a.txt"
  echo "b" > "$SRC_DIR/config/sub/b.txt"
  copy_dir "$SRC_DIR/config" "$DEST_DIR/config"
  [ "$(cat "$DEST_DIR/config/a.txt")" = "a" ]
  [ "$(cat "$DEST_DIR/config/sub/b.txt")" = "b" ]
}

@test "copy_dir is additive, does not delete files already in destination" {
  mkdir -p "$SRC_DIR/config" "$DEST_DIR/config"
  echo "novo" > "$SRC_DIR/config/novo.txt"
  echo "existente" > "$DEST_DIR/config/existente.txt"
  copy_dir "$SRC_DIR/config" "$DEST_DIR/config"
  [ -f "$DEST_DIR/config/novo.txt" ]
  [ -f "$DEST_DIR/config/existente.txt" ]
}

@test "copy_dir respects DRY_RUN (does not write destination)" {
  DRY_RUN=1
  mkdir -p "$SRC_DIR/config"
  echo "a" > "$SRC_DIR/config/a.txt"
  copy_dir "$SRC_DIR/config" "$DEST_DIR/config"
  [ ! -f "$DEST_DIR/config/a.txt" ]
}

@test "backup_if_exists only backs up in install mode" {
  MODE="export"
  echo "conteudo" > "$TMP_DIR/alvo.txt"
  backup_if_exists "$TMP_DIR/alvo.txt"
  [ ! -f "$BACKUP_DIR/alvo.txt" ]
}
