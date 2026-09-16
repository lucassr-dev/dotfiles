#!/usr/bin/env bats
#
# Cobre o controle de seguranca do checkpoint/state: _state_file_is_secure
# (lib/state.sh) e seu alias _checkpoint_file_is_secure (lib/checkpoint.sh)
# recusam um arquivo de estado que nao seja do usuario atual ou que tenha
# permissao de grupo/outro. checkpoint_load faz "source" do arquivo, entao
# esta e a barreira que impede que um checkpoint plantado por terceiro
# execute codigo arbitrario.
#
# bats nao estava instalado nesta maquina quando este arquivo foi escrito;
# as mesmas asercoes foram validadas rodando a logica equivalente em bash
# puro fora do bats (ver relatorio da tarefa de dedup).
#
# Todo teste roda com HOME apontando para um diretorio temporario: nunca deve
# tocar em ~/.dotfiles-checkpoint de verdade.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_HOME="$(mktemp -d)"
  HOME="$FAKE_HOME"
  export HOME
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/state.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/checkpoint.sh"
}

teardown() {
  rm -rf "$FAKE_HOME"
}

@test "arquivo 600 do proprio usuario e aceito" {
  local f="$FAKE_HOME/checkpoint_600"
  echo "CHECKPOINT_STAGE=x" > "$f"
  chmod 600 "$f"

  run _state_file_is_secure "$f"
  [ "$status" -eq 0 ]

  run _checkpoint_file_is_secure "$f"
  [ "$status" -eq 0 ]
}

@test "arquivo 644 e recusado" {
  local f="$FAKE_HOME/checkpoint_644"
  echo "CHECKPOINT_STAGE=x" > "$f"
  chmod 644 "$f"

  run _state_file_is_secure "$f"
  [ "$status" -eq 1 ]

  run _checkpoint_file_is_secure "$f"
  [ "$status" -eq 1 ]
}

@test "arquivo 660 e recusado" {
  local f="$FAKE_HOME/checkpoint_660"
  echo "CHECKPOINT_STAGE=x" > "$f"
  chmod 660 "$f"

  run _state_file_is_secure "$f"
  [ "$status" -eq 1 ]

  run _checkpoint_file_is_secure "$f"
  [ "$status" -eq 1 ]
}

@test "arquivo inexistente e recusado" {
  run _state_file_is_secure "$FAKE_HOME/nao-existe"
  [ "$status" -eq 1 ]

  run _checkpoint_file_is_secure "$FAKE_HOME/nao-existe"
  [ "$status" -eq 1 ]
}

@test "checkpoint_load de arquivo inseguro nao executa o conteudo" {
  local marker="$FAKE_HOME/nao-deveria-existir"
  cat > "$CHECKPOINT_FILE" <<EOF
touch "$marker"
CHECKPOINT_STAGE="malicioso"
EOF
  chmod 644 "$CHECKPOINT_FILE"

  run checkpoint_load
  [ "$status" -eq 1 ]
  [ ! -f "$marker" ]
}

@test "checkpoint_load de arquivo seguro executa o conteudo normalmente" {
  local marker="$FAKE_HOME/deveria-existir"
  cat > "$CHECKPOINT_FILE" <<EOF
touch "$marker"
CHECKPOINT_STAGE="ok"
EOF
  chmod 600 "$CHECKPOINT_FILE"

  run checkpoint_load
  [ "$status" -eq 0 ]
  [ -f "$marker" ]
}

@test "ciclo completo: salvar, carregar, conferir e limpar" {
  # Chave fora do conjunto que _sync_globals_to_state conhece (system.*,
  # config.*, selections.*) — checkpoint_save chama essa ponte de
  # compatibilidade antes de salvar, e ela reescreve as chaves que
  # reconhece a partir das globals legadas (ex.: TARGET_OS), o que
  # clobraria uma chave "system.os" setada so para o teste.
  state_clear
  state_set "test.roundtrip.marker" "valor-teste"
  state_set "selections.cli_tools" "fzf,bat,eza"

  checkpoint_save "teste"
  [ -f "$CHECKPOINT_FILE" ]

  state_clear
  ! state_has "test.roundtrip.marker"

  run checkpoint_load
  [ "$status" -eq 0 ]

  [ "$(state_get 'test.roundtrip.marker')" = "valor-teste" ]
  [ "$(state_get 'selections.cli_tools')" = "fzf,bat,eza" ]
  [ "$CHECKPOINT_STAGE" = "teste" ]

  checkpoint_clear
  [ ! -f "$CHECKPOINT_FILE" ]
}
