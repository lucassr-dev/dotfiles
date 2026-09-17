#!/usr/bin/env bats
#
# A barreira de export em lib/fileops.sh nao diz "segredo nunca entra" — este
# repositorio e privado e guarda credencial de proposito. Ela diz: material
# secreto so cai em destino que o espelho publico exclui.
#
# Isso cria um acoplamento entre duas listas que moram em arquivos diferentes:
# SECRET_EXPORT_DESTS (lib/fileops.sh) e os --exclude de scripts/sync_public.sh.
# Se alguem acrescentar um destino numa e esquecer da outra, o segredo passa a
# sair no espelho publico em silencio. E esse silencio que estes testes quebram.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT_DIR="$REPO_ROOT"
  DRY_RUN=0
  is_truthy() { case "${1:-}" in 1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;; *) return 1 ;; esac; }
  msg() { :; }
  warn() { :; }
  record_failure() { :; }
  has_cmd() { command -v "$1" >/dev/null 2>&1; }
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/fileops.sh"
  FAKE="$(mktemp -d)"
}

teardown() {
  rm -rf "$FAKE"
}

@test "todo destino que pode receber segredo esta excluido do espelho publico" {
  run _check_secret_dests_match_public_sync
  [ "$status" -eq 0 ]
}

@test "chave privada e reconhecida como segredo" {
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEA\n' > "$FAKE/chave"
  run _looks_like_secret "$FAKE/chave"
  [ "$status" -eq 0 ]
}

@test "token de registry e reconhecido como segredo" {
  printf '//registry.npmjs.org/:_authToken=npm_aAbBcCdDeEfFgGhHiIjJkKlLmMnN\n' > "$FAKE/npmrc"
  run _looks_like_secret "$FAKE/npmrc"
  [ "$status" -eq 0 ]
}

@test "config comum nao e confundida com segredo" {
  printf 'set -g mouse on\nset -g history-limit 10000\n' > "$FAKE/tmux.conf"
  run _looks_like_secret "$FAKE/tmux.conf"
  [ "$status" -eq 1 ]
}

@test "chave publica nao e confundida com segredo" {
  printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyDataHere user@host\n' > "$FAKE/chave.pub"
  run _looks_like_secret "$FAKE/chave.pub"
  [ "$status" -eq 1 ]
}

@test "segredo com destino fora do espelho publico e exportado" {
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEA\n' > "$FAKE/chave"
  run _secret_export_allowed "$FAKE/chave" "$REPO_ROOT/shared/.ssh/id_ed25519_teste"
  [ "$status" -eq 0 ]
}

@test "segredo com destino dentro do espelho publico e recusado" {
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEA\n' > "$FAKE/chave"
  run _secret_export_allowed "$FAKE/chave" "$FAKE/dest/chave"
  [ "$status" -eq 1 ]
}

@test "ALLOW_SECRET_EXPORT libera destino que seria recusado" {
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEA\n' > "$FAKE/chave"
  ALLOW_SECRET_EXPORT=1 run _secret_export_allowed "$FAKE/chave" "$FAKE/dest/chave"
  [ "$status" -eq 0 ]
}

@test "export_dir recusa so o arquivo secreto, nao o diretorio inteiro" {
  mkdir -p "$FAKE/src"
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEA\n' > "$FAKE/src/chave"
  printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample user@host\n' > "$FAKE/src/chave.pub"
  printf 'Host github.com\n  User git\n' > "$FAKE/src/config"

  export_dir "$FAKE/src" "$FAKE/dest"

  [ ! -f "$FAKE/dest/chave" ]
  [ -f "$FAKE/dest/chave.pub" ]
  [ -f "$FAKE/dest/config" ]
}

@test "a lista de exclusao do sync e legivel no formato atual" {
  run bash -c "awk '/^SYNC_EXCLUDES=\\(/{d=1; next} d && /^\\)/{exit} d' '$REPO_ROOT/scripts/sync_public.sh' | grep -c \"'\""
  [ "$status" -eq 0 ]
  [ "$output" -gt 10 ]
}

@test "a checagem acusa quando uma exclusao some do sync" {
  local copia="$FAKE/sync_public.sh"
  grep -v "'shared/aider'" "$REPO_ROOT/scripts/sync_public.sh" > "$copia"

  mkdir -p "$FAKE/repo/scripts"
  cp "$copia" "$FAKE/repo/scripts/sync_public.sh"

  SCRIPT_DIR="$FAKE/repo" run _check_secret_dests_match_public_sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"shared/aider"* ]]
}

@test "o marco de sync esta na lista de exclusao" {
  run grep -c 'SYNC_STAMP=' "$REPO_ROOT/scripts/sync_public.sh"
  [ "$status" -eq 0 ]
  run bash -c "awk '/^SYNC_EXCLUDES=\\(/{d=1; next} d && /^\\)/{exit} d' '$REPO_ROOT/scripts/sync_public.sh' | grep -c 'SYNC_STAMP'"
  [ "$output" -eq 1 ]
}
