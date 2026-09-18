#!/usr/bin/env bats
#
# export_configs (lib/export.sh), 180 linhas sem teste ate aqui.
#
# Sao testes de caracterizacao: fixam o comportamento ATUAL, para que o mapa
# origem->destino possa ser extraido para uma tabela declarativa sem que
# nenhum par se perca no caminho. O mapa hoje vive espalhado em 33 chamadas
# imperativas dentro da funcao, e e a unica fonte que existe de "qual arquivo
# do sistema corresponde a qual arquivo do repo" -- o modo install faz o
# caminho inverso com copy_file espalhado por install.sh e por 3 libs.
#
# O que importa travar aqui:
#   - cada par vai para o destino certo
#   - o que nao existe no sistema nao cria arquivo no repo
#   - DRY_RUN nao escreve
#   - a contagem de pares, para que adicionar um sem atualizar a tabela falhe

load helpers/ambiente

setup() {
  ambiente_isolado
  REPO_FALSO="$TEST_HOME/repo"
  mkdir -p "$REPO_FALSO"
}

teardown() {
  ambiente_limpar
}

# Roda export_configs com o repo apontando para um diretorio descartavel.
_exportar() {
  no_ambiente "
    . lib/fileops.sh
    . lib/export.sh
    SCRIPT_DIR='$REPO_FALSO'
    CONFIG_SHARED='$REPO_FALSO/shared'
    CONFIG_LINUX='$REPO_FALSO/linux'
    CONFIG_MACOS='$REPO_FALSO/macos'
    TARGET_OS=linux
    DRY_RUN=${1:-0}
    export_configs
  " 2>&1
}

@test "exporta config do fish para shared/fish" {
  mkdir -p "$TEST_HOME/.config/fish"
  echo "set -g fish_greeting ''" > "$TEST_HOME/.config/fish/config.fish"

  _exportar >/dev/null

  [ -f "$REPO_FALSO/shared/fish/config.fish" ]
  grep -q "fish_greeting" "$REPO_FALSO/shared/fish/config.fish"
}

@test "exporta zshrc e, junto, o p10k quando existe" {
  echo "export ZSH=x" > "$TEST_HOME/.zshrc"
  echo "# p10k" > "$TEST_HOME/.p10k.zsh"

  _exportar >/dev/null

  [ -f "$REPO_FALSO/shared/zsh/.zshrc" ]
  [ -f "$REPO_FALSO/shared/zsh/.p10k.zsh" ]
}

@test "p10k sozinho, sem zshrc, nao e exportado" {
  # O p10k esta aninhado dentro do if do zshrc: sem zshrc nao ha export.
  echo "# p10k" > "$TEST_HOME/.p10k.zsh"

  _exportar >/dev/null

  [ ! -f "$REPO_FALSO/shared/zsh/.p10k.zsh" ]
}

@test "o que nao existe no sistema nao vira arquivo no repo" {
  # HOME vazio: nada para exportar, nenhum arquivo criado.
  _exportar >/dev/null

  local criados
  criados=$(find "$REPO_FALSO" -type f 2>/dev/null | wc -l)
  if [ "$criados" -ne 0 ]; then
    echo "esperava 0 arquivos, achei $criados:" >&2
    find "$REPO_FALSO" -type f >&2
    return 1
  fi
}

@test "DRY_RUN nao escreve nada no repo" {
  mkdir -p "$TEST_HOME/.config/fish"
  echo "set -g fish_greeting ''" > "$TEST_HOME/.config/fish/config.fish"
  echo "export ZSH=x" > "$TEST_HOME/.zshrc"

  _exportar 1 >/dev/null

  local criados
  criados=$(find "$REPO_FALSO" -type f 2>/dev/null | wc -l)
  if [ "$criados" -ne 0 ]; then
    echo "DRY_RUN escreveu $criados arquivo(s):" >&2
    find "$REPO_FALSO" -type f >&2
    return 1
  fi
}

@test "diretorio de config vai inteiro, nao so o arquivo raiz" {
  mkdir -p "$TEST_HOME/.config/yazi/plugins"
  echo "# keymap" > "$TEST_HOME/.config/yazi/keymap.toml"
  echo "# plugin" > "$TEST_HOME/.config/yazi/plugins/x.lua"

  _exportar >/dev/null

  [ -f "$REPO_FALSO/shared/yazi/keymap.toml" ]
  [ -f "$REPO_FALSO/shared/yazi/plugins/x.lua" ]
}

@test "chave SSH vai para o destino permitido, nao para outro lugar" {
  # export_file/export_dir carregam a barreira de material secreto
  # (tests/test_secret_export.bats). Aqui o que se trava e o destino: o
  # diretorio .ssh do repo e um dos permitidos, entao a copia acontece.
  mkdir -p "$TEST_HOME/.ssh"
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nxxx\n-----END OPENSSH PRIVATE KEY-----\n' \
    > "$TEST_HOME/.ssh/id_ed25519_teste"
  chmod 600 "$TEST_HOME/.ssh/id_ed25519_teste"

  _exportar >/dev/null

  [ -f "$REPO_FALSO/shared/.ssh/id_ed25519_teste" ]
}

@test "o mapa tem 33 pares -- adicionar um sem atualizar a tabela falha aqui" {
  # Guarda para a extracao do mapa declarativo: se este numero mudar sem que
  # a tabela mude junto, o par novo ficaria de fora do doctor e do diff.
  local pares
  pares=$(awk '/^export_configs\(\)/,/^}/' "$REPO_ROOT/lib/export.sh" \
    | grep -cE 'export_(file|dir) "')
  if [ "$pares" -ne 33 ]; then
    echo "export_configs tem $pares pares, a tabela conhece 33" >&2
    return 1
  fi
}
