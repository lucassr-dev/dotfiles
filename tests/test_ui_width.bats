#!/usr/bin/env bats
#
# Grade de largura da UI.
#
# Antes desta suite cada tela lia `tput cols` por conta propria e aplicava a
# propria regra: 15 pontos de leitura, 5 tetos diferentes (70, 92, 94) e 3
# margens (-2, -4, -6). Numa mesma execucao a barra de progresso saia com 70
# colunas, a revisao de selecao com 92 e o resumo final com 94.
#
# Dois defeitos concretos vinham dai:
#
#   1. UI_MIN_WIDTH=42 era piso sem teto de realidade. Num terminal de 30
#      colunas a caixa saia com 42 e a moldura quebrava a linha.
#   2. ui_box aplicava esse piso; ui_divider, com a mesma formula no mesmo
#      arquivo, nao aplicava. Em 30 colunas: caixa 42, divisor 26.
#
# A tecnica aqui e `tput` de mentira no PATH, devolvendo a largura que o teste
# pedir -- `tput cols` dentro de $( ) sem tty responde 80 e esconde o bug.
#
# Medicao e sempre em COLUNAS DE EXIBICAO (wc -L), nunca em bytes: cada
# caractere de moldura (─ ╭ ╮) ocupa 3 bytes e 1 coluna, entao `awk length`
# e ${#var} dao numero inflado e a conta sai errada.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_BIN="$(mktemp -d)"
}

teardown() {
  rm -rf "$FAKE_BIN"
}

# `tput cols` de mentira. Sem argumento de saida, sai 0 e imprime a largura.
_fake_tput() {
  local cols="$1"
  cat > "$FAKE_BIN/tput" <<SCRIPT
#!/usr/bin/env bash
case "\$1" in
  cols) echo "$cols" ;;
  *)    exit 0 ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/tput"
}

# tput que falha, como num TERM desconhecido ou sem terminfo.
_fake_tput_quebrado() {
  cat > "$FAKE_BIN/tput" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "$FAKE_BIN/tput"
}

# tput que sai 0 mas imprime lixo. O `|| echo 80` dos pontos antigos so pega
# saida diferente de zero: lixo com exit 0 passava direto para a aritmetica.
_fake_tput_lixo() {
  cat > "$FAKE_BIN/tput" <<'SCRIPT'
#!/usr/bin/env bash
echo "nao-e-numero"
SCRIPT
  chmod +x "$FAKE_BIN/tput"
}

# Roda um trecho com os modulos de UI carregados e o tput de mentira no PATH.
_com_ui() {
  PATH="$FAKE_BIN:$PATH" bash -c "
    cd '$REPO_ROOT'
    . lib/core.sh
    . lib/colors.sh 2>/dev/null
    . lib/utils.sh
    . lib/components.sh
    $1
  "
}

# Colunas de exibicao da linha mais larga, sem os codigos de cor.
_colunas() {
  sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' | wc -L
}

@test "ui_term_cols devolve a largura que o terminal informa" {
  _fake_tput 137
  run _com_ui 'ui_term_cols'
  [ "$status" -eq 0 ]
  [ "$output" = "137" ]
}

@test "ui_term_cols cai para 80 quando tput falha" {
  _fake_tput_quebrado
  run _com_ui 'ui_term_cols'
  [ "$status" -eq 0 ]
  [ "$output" = "80" ]
}

@test "ui_term_cols cai para 80 quando tput imprime lixo e sai zero" {
  _fake_tput_lixo
  run _com_ui 'ui_term_cols'
  [ "$status" -eq 0 ]
  [ "$output" = "80" ]
}

@test "ui_width respeita o teto em terminal largo" {
  _fake_tput 200
  run _com_ui "ui_width \$UI_WIDTH_MAX_BOX"
  [ "$status" -eq 0 ]
  [ "$output" -eq 70 ]
}

@test "ui_width usa o teto cheio para telas cheias" {
  _fake_tput 200
  run _com_ui "ui_width \$UI_WIDTH_MAX_FULL"
  [ "$status" -eq 0 ]
  [ "$output" -eq 94 ]
}

@test "ui_width desconta a margem em terminal medio" {
  _fake_tput 60
  run _com_ui "ui_width \$UI_WIDTH_MAX_BOX"
  [ "$status" -eq 0 ]
  [ "$output" -eq 56 ]
}

@test "ui_width nunca devolve mais do que cabe no terminal" {
  local w
  for w in 20 24 30 36 40 46 50; do
    _fake_tput "$w"
    run _com_ui "ui_width \$UI_WIDTH_MAX_BOX"
    [ "$status" -eq 0 ]
    if [ "$output" -gt "$w" ]; then
      echo "terminal de $w colunas recebeu largura $output" >&2
      return 1
    fi
  done
}

@test "ui_box nunca estoura a largura do terminal" {
  local w largura
  for w in 20 24 30 36 40 46 60 80 200; do
    _fake_tput "$w"
    largura=$(_com_ui 'ui_box "Titulo" "conteudo"' | _colunas)
    if [ "$largura" -gt "$w" ]; then
      echo "terminal de $w colunas: caixa saiu com $largura colunas" >&2
      return 1
    fi
  done
}

@test "ui_divider acompanha ui_box em qualquer largura" {
  local w caixa divisor
  for w in 20 24 30 36 40 46 60 80 120 200; do
    _fake_tput "$w"
    caixa=$(_com_ui 'ui_box "Titulo" "conteudo"' | _colunas)
    divisor=$(_com_ui 'ui_divider' | _colunas)
    if [ "$caixa" -ne "$divisor" ]; then
      echo "terminal de $w colunas: caixa $caixa, divisor $divisor" >&2
      return 1
    fi
  done
}

@test "ui_divider nunca estoura a largura do terminal" {
  local w largura
  for w in 20 24 30 36 40 60 200; do
    _fake_tput "$w"
    largura=$(_com_ui 'ui_divider' | _colunas)
    if [ "$largura" -gt "$w" ]; then
      echo "terminal de $w colunas: divisor saiu com $largura colunas" >&2
      return 1
    fi
  done
}

# ─── Barra de progresso (step_begin / step_end) ────────────────────────────
#
# A moldura de progresso e desenhada a mao, sem passar por ui_box: o topo sai
# em step_begin e a base em step_end, com a saida da etapa no meio. Por ser
# montada em dois lugares, as duas pontas podiam divergir sem que nada
# reclamasse -- e divergiam, em quatro frentes:
#
#   topo  = box_w + 2  (o preenchimento descontava 6 onde precisava de 8)
#   base  = box_w - 1  SO no ramo que mostra o tempo decorrido; o ramo sem
#           tempo estava certo, o que escondia o defeito em teste rapido
#   meio  = a linha de detalhe abria o "│" e nunca fechava
#   e ${#header} contava BYTES: "Extensões VS Code" e "Padrões do Sistema"
#   saiam 1 coluna mais estreitos que os outros 11 passos

_com_ui_completo() {
  PATH="$FAKE_BIN:$PATH" bash -c "
    cd '$REPO_ROOT'
    . lib/core.sh
    . lib/colors.sh 2>/dev/null
    . lib/utils.sh
    . lib/components.sh
    . lib/ui.sh
    INSTALL_TOTAL_STEPS=10
    INSTALL_STEP=2
    STEP_BEGIN_TIME=0
    $1
  "
}

@test "topo da barra de progresso tem a largura da grade" {
  local w esperado real
  for w in 40 60 80 120 200; do
    _fake_tput "$w"
    esperado=$(_com_ui 'ui_width "$UI_WIDTH_MAX_BOX"')
    real=$(_com_ui_completo 'step_begin "Instalando ferramentas"' | _colunas)
    if [ "$real" -ne "$esperado" ]; then
      echo "terminal $w: topo saiu com $real, grade manda $esperado" >&2
      return 1
    fi
  done
}

@test "base da barra bate com o topo, com e sem tempo decorrido" {
  local w topo base_sem base_com
  for w in 40 60 80 120; do
    _fake_tput "$w"
    topo=$(_com_ui_completo 'step_begin "Instalando ferramentas"' | _colunas)
    base_sem=$(_com_ui_completo 'step_end success' | _colunas)
    base_com=$(_com_ui_completo 'STEP_BEGIN_TIME=1; SECONDS=75; step_end success' | _colunas)
    if [ "$base_sem" -ne "$topo" ]; then
      echo "terminal $w: topo $topo, base sem tempo $base_sem" >&2
      return 1
    fi
    if [ "$base_com" -ne "$topo" ]; then
      echo "terminal $w: topo $topo, base com tempo $base_com" >&2
      return 1
    fi
  done
}

@test "linha de detalhe fecha a moldura" {
  local w topo linhas
  for w in 60 80 120; do
    _fake_tput "$w"
    topo=$(_com_ui_completo 'step_begin "Instalando" "baixando pacotes"' | _colunas)
    linhas=$(_com_ui_completo 'step_begin "Instalando" "baixando pacotes"' \
      | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' | grep -c '│.*│')
    if [ "$linhas" -ne 1 ]; then
      echo "terminal $w: linha de detalhe nao fecha a moldura" >&2
      return 1
    fi
    if [ "$topo" -ne "$(_com_ui 'ui_width "$UI_WIDTH_MAX_BOX"')" ]; then
      echo "terminal $w: largura do bloco divergiu" >&2
      return 1
    fi
  done
}

@test "rotulo com acento nao encolhe a barra" {
  _fake_tput 80
  local ascii acentuado
  ascii=$(_com_ui_completo 'step_begin "Extensoes VS Code"' | _colunas)
  acentuado=$(_com_ui_completo 'step_begin "Extensões VS Code"' | _colunas)
  [ "$ascii" -eq "$acentuado" ]
}
