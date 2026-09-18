#!/usr/bin/env bats
#
# Modo diff (lib/diff.sh).
#
# O que precisa estar certo aqui, em ordem de consequencia:
#
# 1. O SENTIDO. "-" e repositorio, "+" e sistema. Um diff de config com o
#    sentido trocado nao parece errado -- as duas leituras sao plausiveis --
#    e leva a acao oposta: quem le "+" como "o repo tem isto" roda `install`
#    quando devia rodar `export`, e sobrescreve o que queria salvar.
# 2. A contagem, que e o resumo em que se decide se vale olhar o detalhe.
# 3. Nao escrever nada, mesma promessa do doctor.

load helpers/ambiente

setup() {
  ambiente_isolado
  REPO_FALSO="$TEST_HOME/repo"
  mkdir -p "$REPO_FALSO/shared"
}

teardown() {
  ambiente_limpar
}

_diff() {
  local verbose="${2:-0}"
  no_ambiente "
    SCRIPT_DIR='$REPO_ROOT'
    CONFIG_SHARED='$REPO_FALSO/shared'
    CONFIG_LINUX='$REPO_FALSO/linux'
    CONFIG_MACOS='$REPO_FALSO/macos'
    TARGET_OS=linux
    VERBOSE=$verbose
    . data/config_map.sh
    . lib/doctor.sh
    . lib/diff.sh
    $1
  " 2>&1
}

# Cria o par zshrc nos dois lados, com o conteudo que o teste pedir. String
# vazia significa "nao criar deste lado".
#
# O `return 0` no fim nao e decoracao: com `[[ -n "$x" ]] && cmd`, um $x vazio
# faz a funcao inteira devolver 1, e o bats le o retorno da ultima linha como
# resultado do teste -- que passa a falhar no helper, sem nunca chegar na
# assercao.
_par_zshrc() {
  local no_sistema="$1" no_repo="$2"
  mkdir -p "$REPO_FALSO/shared/zsh"
  if [[ -n "$no_sistema" ]]; then
    printf '%s\n' "$no_sistema" > "$TEST_HOME/.zshrc"
  fi
  if [[ -n "$no_repo" ]]; then
    printf '%s\n' "$no_repo" > "$REPO_FALSO/shared/zsh/.zshrc"
  fi
  return 0
}

@test "sentido: o que so existe no sistema aparece com +" {
  _par_zshrc "so na maquina" ""
  run _diff 'run_diff'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '+.*Zsh.*só no sistema' || { echo "$output" >&2; return 1; }
}

@test "sentido: o que so existe no repo aparece com −" {
  _par_zshrc "" "so no repo"
  run _diff 'run_diff'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '−.*Zsh.*só no repositório' || { echo "$output" >&2; return 1; }
}

@test "sentido: no conteudo, - e a linha do repo e + e a do sistema" {
  _par_zshrc "LINHA_DO_SISTEMA=1" "LINHA_DO_REPO=1"
  run _diff 'run_diff' 1
  [ "$status" -eq 0 ]
  # A linha do repo tem que sair prefixada por "-", e a do sistema por "+".
  echo "$output" | grep -qE '^\s*-LINHA_DO_REPO=1' || {
    echo "linha do repo nao saiu como remocao:" >&2; echo "$output" >&2; return 1; }
  echo "$output" | grep -qE '^\s*\+LINHA_DO_SISTEMA=1' || {
    echo "linha do sistema nao saiu como adicao:" >&2; echo "$output" >&2; return 1; }
}

@test "o cabecalho declara a convencao de sentido" {
  # Sem isso declarado na tela, o diff e ambiguo para quem le.
  run _diff 'run_diff'
  echo "$output" | grep -q 'repositório' || { echo "$output" >&2; return 1; }
  echo "$output" | grep -q 'sistema' || { echo "$output" >&2; return 1; }
}

@test "conteudo identico nao aparece na lista" {
  _par_zshrc "mesma coisa" "mesma coisa"
  run _diff 'run_diff'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'Zsh' && { echo "$output" >&2; return 1; }
  return 0
}

@test "tudo igual diz nada a sincronizar" {
  _par_zshrc "igual" "igual"
  run _diff 'run_diff'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nada a sincronizar"* ]] || { echo "$output" >&2; return 1; }
}

@test "as quatro contagens batem com o que existe" {
  mkdir -p "$REPO_FALSO/shared/zsh" "$REPO_FALSO/shared/fish" "$TEST_HOME/.config/fish"
  # divergente
  echo "sis" > "$TEST_HOME/.zshrc"; echo "rep" > "$REPO_FALSO/shared/zsh/.zshrc"
  # igual
  echo "x" > "$TEST_HOME/.config/fish/config.fish"; echo "x" > "$REPO_FALSO/shared/fish/config.fish"
  # so no sistema
  echo "y" > "$TEST_HOME/.ripgreprc"
  # so no repo
  echo "z" > "$REPO_FALSO/shared/.p10k-nao"; mkdir -p "$REPO_FALSO/shared"
  echo "z" > "$REPO_FALSO/shared/zsh/.p10k.zsh"

  run _diff 'run_diff; echo "D=$DIFF_DIVERGENTES S=$DIFF_SO_SISTEMA R=$DIFF_SO_REPO I=$DIFF_IGUAIS"'
  [[ "$output" == *"D=1"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"S=1"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"R=1"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"I=1"* ]] || { echo "$output" >&2; return 1; }
}

@test "sem verbose nao mostra conteudo; com verbose mostra" {
  _par_zshrc "SEGREDO_DO_SISTEMA=1" "OUTRA_COISA=1"

  run _diff 'run_diff' 0
  [[ "$output" != *"SEGREDO_DO_SISTEMA"* ]] || {
    echo "mostrou conteudo sem --verbose:" >&2; echo "$output" >&2; return 1; }
  [[ "$output" == *"linha(s)"* ]]

  run _diff 'run_diff' 1
  [[ "$output" == *"SEGREDO_DO_SISTEMA"* ]] || {
    echo "nao mostrou conteudo com --verbose:" >&2; echo "$output" >&2; return 1; }
}

@test "diretorio conta arquivos, arquivo conta linhas" {
  mkdir -p "$TEST_HOME/.config/yazi" "$REPO_FALSO/shared/yazi"
  echo "a" > "$TEST_HOME/.config/yazi/keymap.toml"
  echo "b" > "$REPO_FALSO/shared/yazi/keymap.toml"
  _par_zshrc $'l1\nl2\nl3' $'l1\nDIFERENTE\nl3'

  run _diff 'run_diff'
  echo "$output" | grep -q 'Yazi.*arquivo(s)' || { echo "$output" >&2; return 1; }
  echo "$output" | grep -q 'Zsh.*linha(s)' || { echo "$output" >&2; return 1; }
}

@test "o diff nao escreve, nao cria e nao apaga nada" {
  _par_zshrc "sis" "rep"
  mkdir -p "$TEST_HOME/.config/fish"
  echo "cfg" > "$TEST_HOME/.config/fish/config.fish"

  local antes depois
  antes=$(find "$TEST_HOME" -printf '%p %s %m\n' 2>/dev/null | sort | md5sum)
  _diff 'run_diff' 1 >/dev/null 2>&1 || true
  depois=$(find "$TEST_HOME" -printf '%p %s %m\n' 2>/dev/null | sort | md5sum)

  [ "$antes" = "$depois" ] || {
    echo "a arvore do HOME mudou durante o diff" >&2
    return 1
  }
}
