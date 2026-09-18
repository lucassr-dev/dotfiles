#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
#
# Ambiente isolado para os testes.
#
# Onze arquivos de teste repetiam pedacos deste setup, e so um deles
# (test_crossplat) isolava de verdade. Isolar so o HOME nao basta: o script
# escreve em ~/.config, ~/.local/share, ~/.local/state e ~/.cache por caminho
# derivado das XDG_*, entao um teste que sobrescreve apenas HOME ainda suja o
# diretorio real do dono da maquina.
#
# Para funcao interativa, o que destrava e que os 36 `read` do codebase leem
# da ENTRADA PADRAO -- nenhum de /dev/tty. Roteirizar stdin funciona, desde
# que FORCE_UI_MODE=bash tire fzf e gum do caminho (os dois pegam o terminal
# direto e ignorariam o roteiro).

ambiente_isolado() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  TEST_HOME="$(mktemp -d)"
  TEST_XDG_CONFIG="$TEST_HOME/.config"
  TEST_XDG_DATA="$TEST_HOME/.local/share"
  TEST_XDG_CACHE="$TEST_HOME/.cache"
  TEST_XDG_STATE="$TEST_HOME/.local/state"
  mkdir -p "$TEST_XDG_CONFIG" "$TEST_XDG_DATA" "$TEST_XDG_CACHE" "$TEST_XDG_STATE"

  FAKE_BIN="$(mktemp -d)"
  # Fora do TEST_HOME de proposito: ha teste que compara a arvore do HOME
  # antes e depois (o doctor promete nao escrever), e o log de chamadas
  # morando la dentro apareceria como alteracao.
  MOCK_LOG="$FAKE_BIN/.chamadas.log"
  : > "$MOCK_LOG"
}

ambiente_limpar() {
  [[ -n "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
  [[ -n "${FAKE_BIN:-}" ]] && rm -rf "$FAKE_BIN"
}

# Binario-isca: registra "$0 $*" no log de chamadas e sai com $FAKE_EXIT.
# Sem stdout, entao quem consulta ("list", "status") sempre ve "nao instalado"
# e segue para o comando de instalacao -- que e o que os testes travam.
bin_falso() {
  local nome="$1"
  cat > "$FAKE_BIN/$nome" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
exit "\${FAKE_EXIT:-0}"
SCRIPT
  chmod +x "$FAKE_BIN/$nome"
}

# Como bin_falso, mas com stdout fixo -- para quem e consultado por valor
# (`--version`, `which`, `list`).
bin_falso_com_saida() {
  local nome="$1" saida="$2" codigo="${3:-0}"
  cat > "$FAKE_BIN/$nome" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
printf '%s\n' "$saida"
exit $codigo
SCRIPT
  chmod +x "$FAKE_BIN/$nome"
}

# Binario que existe mas falha em tudo que fizer. Serve para o caminho "a
# ferramenta esta instalada e quebrou", que e diferente de "nao esta
# instalada".
bin_quebrado() {
  local nome="$1"
  cat > "$FAKE_BIN/$nome" <<SCRIPT
#!/usr/bin/env bash
exit 127
SCRIPT
  chmod +x "$FAKE_BIN/$nome"
}

# "Esta maquina nao tem X."
#
# Nao da para fazer isso criando arquivo: has_cmd chama `command -v`, que
# encontra qualquer executavel no PATH -- inclusive um que so sai 127. E
# tirar do PATH tambem nao serve, porque o binario real continua em /usr/bin.
# O jeito honesto e substituir has_cmd, que e onde a decisao mora.
#
# Devolve um trecho de codigo para ser colado antes do que se quer testar.
sem_comandos() {
  local padrao
  padrao=$(printf '%s' "$*" | tr ' ' '|')
  printf 'has_cmd() { case "$1" in %s) return 1 ;; esac; command -v "$1" >/dev/null 2>&1; }\n' "$padrao"
}

# Linhas do log de chamadas que batem com o padrao.
chamadas() {
  grep -E "$1" "$MOCK_LOG" 2>/dev/null || true
}

quantas_chamadas() {
  chamadas "$1" | grep -c . || true
}

# Ordem de carregamento igual a do install.sh: core primeiro (define msg,
# warn, err, clear_screen e a grade de largura), depois o resto.
_preambulo_libs() {
  cat <<'PRE'
set +e
. lib/core.sh
. lib/colors.sh 2>/dev/null
. lib/utils.sh
. lib/components.sh
. lib/ui.sh
PRE
}

# Roda um trecho de codigo com os modulos carregados, no ambiente isolado.
# `libs_extra` e uma lista separada por espaco de caminhos relativos a raiz.
no_ambiente() {
  local codigo="$1" libs_extra="${2:-}"
  local extras=""
  local l
  for l in $libs_extra; do
    extras+=". $l"$'\n'
  done
  env -i \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_XDG_CONFIG" \
    XDG_DATA_HOME="$TEST_XDG_DATA" \
    XDG_CACHE_HOME="$TEST_XDG_CACHE" \
    XDG_STATE_HOME="$TEST_XDG_STATE" \
    PATH="$FAKE_BIN:/usr/local/bin:/usr/bin:/bin" \
    TERM="${TERM:-dumb}" \
    LANG="${LANG:-C.UTF-8}" \
    FORCE_UI_MODE=bash \
    NO_COLOR=1 \
    MOCK_LOG="$MOCK_LOG" \
    bash -c "
      cd '$REPO_ROOT'
      $(_preambulo_libs)
      $extras
      $codigo
    "
}

# Como no_ambiente, mas com respostas roteirizadas na entrada padrao. Cada
# argumento a partir do terceiro e uma linha de resposta, na ordem em que os
# `read -r -p` vao consumi-las.
#
# Uma linha vazia significa "so Enter", que e como se aceita o default -- por
# isso as respostas viajam como argumentos, nao como uma string separada por
# espaco: "" seria perdido no word splitting.
no_ambiente_com_respostas() {
  local codigo="$1" libs_extra="${2:-}"
  shift 2 2>/dev/null || shift $#
  local entrada=""
  local r
  for r in "$@"; do
    entrada+="$r"$'\n'
  done
  printf '%s' "$entrada" | no_ambiente "$codigo" "$libs_extra"
}
