#!/usr/bin/env bats
#
# Perfil de instalacao (lib/perfil.sh).
#
# A garantia que mais importa aqui e NEGATIVA: o arquivo de perfil e lido,
# nunca executado.
#
# A tentacao de implementar com `source` e forte, porque o formato ja e quase
# bash e sairia de graca. Mas perfil e arquivo que se baixa, se copia de um
# colega e se compartilha entre maquinas; source transforma qualquer um deles
# em execucao de codigo arbitrario com o PATH e o HOME de quem rodou -- e o
# instalador tambem usa sudo. Os testes de "nao executa" existem para que
# ninguem troque o parser por um source achando que simplifica.
#
# Depois disso, em ordem: chave desconhecida para com a lista, e cada tipo
# (flag, lista, texto) chega na variavel certa.

load helpers/ambiente

setup() {
  ambiente_isolado
  PERFIS="$TEST_HOME/profiles"
  mkdir -p "$PERFIS"
}

teardown() { ambiente_limpar; }

_perfil() {
  no_ambiente "
    SCRIPT_DIR='$TEST_HOME'
    . lib/perfil.sh
    $1
  " 2>&1
}

_escrever() {
  local nome="$1"; shift
  printf '%s\n' "$@" > "$PERFIS/$nome.conf"
  chmod 644 "$PERFIS/$nome.conf"
}

# ─── A garantia negativa ───────────────────────────────────────────────────

@test "comando no valor nao e executado" {
  _escrever evil 'starship_preset = $(touch '"$TEST_HOME"'/EXECUTOU)'
  run _perfil 'perfil_aplicar evil; echo "PRESET=[$SELECTED_STARSHIP_PRESET]"'

  [ ! -f "$TEST_HOME/EXECUTOU" ] || {
    echo "o perfil executou um comando" >&2
    return 1
  }
  # E o valor chega literal, como dado.
  [[ "$output" == *'PRESET=[$(touch'* ]] || { echo "$output" >&2; return 1; }
}

@test "crase no valor nao e executada" {
  _escrever evil2 'omp_theme = `touch '"$TEST_HOME"'/EXECUTOU2`'
  run _perfil 'perfil_aplicar evil2'
  [ ! -f "$TEST_HOME/EXECUTOU2" ]
}

@test "linha que parece comando de shell e recusada como chave desconhecida" {
  _escrever evil3 'rm -rf /tmp/algo' 'install_zsh = 1'
  run _perfil 'perfil_aplicar evil3; echo "SAIDA=$?"'
  # Sem "=" na primeira linha, o parser para antes de qualquer outra coisa.
  [[ "$output" == *"sem '='"* ]] || { echo "$output" >&2; return 1; }
}

@test "atribuicao a variavel fora do catalogo nao passa" {
  _escrever evil4 'PATH = /caminho/malicioso'
  run _perfil 'perfil_aplicar evil4; echo "SAIDA=$?"'
  [[ "$output" == *"desconhecida"* ]]
  [[ "$output" == *"SAIDA=1"* ]]
}

# ─── Permissao ─────────────────────────────────────────────────────────────

@test "perfil com escrita para outros e recusado" {
  _escrever aberto 'install_zsh = 1'
  chmod 646 "$PERFIS/aberto.conf"
  run _perfil 'perfil_aplicar aberto; echo "SAIDA=$?"'
  [[ "$output" == *"permissao de escrita"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"SAIDA=1"* ]]
}

@test "perfil com escrita para o grupo e recusado" {
  _escrever grupo 'install_zsh = 1'
  chmod 664 "$PERFIS/grupo.conf"
  run _perfil 'perfil_aplicar grupo; echo "SAIDA=$?"'
  [[ "$output" == *"SAIDA=1"* ]]
}

@test "perfil 644 e aceito" {
  _escrever normal 'install_zsh = 1'
  run _perfil 'perfil_aplicar normal; echo "SAIDA=$?"'
  [[ "$output" == *"SAIDA=0"* ]] || { echo "$output" >&2; return 1; }
}

# ─── Parsing ───────────────────────────────────────────────────────────────

@test "flag vira 0 ou 1, aceitando as formas de is_truthy" {
  _escrever flags \
    'install_zsh = 1' \
    'install_fish = true' \
    'install_nushell = 0' \
    'install_base_deps = no'
  run _perfil 'perfil_aplicar flags
    echo "Z=$INSTALL_ZSH F=$INSTALL_FISH N=$INSTALL_NUSHELL B=$INSTALL_BASE_DEPS"'
  [[ "$output" == *"Z=1 F=1 N=0 B=0"* ]] || { echo "$output" >&2; return 1; }
}

@test "lista vira array, ignorando espaco em volta da virgula" {
  _escrever listas 'cli_tools = fzf,  ripgrep ,bat'
  run _perfil 'perfil_aplicar listas
    echo "N=${#SELECTED_CLI_TOOLS[@]} [${SELECTED_CLI_TOOLS[0]}][${SELECTED_CLI_TOOLS[1]}][${SELECTED_CLI_TOOLS[2]}]"'
  [[ "$output" == *"N=3 [fzf][ripgrep][bat]"* ]] || { echo "$output" >&2; return 1; }
}

@test "lista vazia significa nenhum, nao default" {
  _escrever vazio 'ia_tools ='
  run _perfil 'perfil_aplicar vazio; echo "N=${#SELECTED_IA_TOOLS[@]}"'
  [[ "$output" == *"N=0"* ]]
}

@test "comentario e linha em branco sao ignorados" {
  _escrever comentado \
    '# tudo isto e comentario' \
    '' \
    'install_zsh = 1  # ate aqui' \
    '   ' \
    '# fim'
  run _perfil 'perfil_aplicar comentado; echo "Z=[$INSTALL_ZSH] SAIDA=$?"'
  [[ "$output" == *"Z=[1]"* ]] || { echo "$output" >&2; return 1; }
}

@test "texto chega inteiro, com espaco no meio" {
  _escrever txt 'omp_theme = tema com espaco'
  run _perfil 'perfil_aplicar txt; echo "[$SELECTED_OMP_THEME]"'
  [[ "$output" == *"[tema com espaco]"* ]]
}

@test "item com espaco na lista e preservado" {
  _escrever esp 'ides = VS Code, IntelliJ IDEA'
  run _perfil 'perfil_aplicar esp; echo "N=${#SELECTED_IDES[@]} [${SELECTED_IDES[0]}][${SELECTED_IDES[1]}]"'
  [[ "$output" == *"N=2 [VS Code][IntelliJ IDEA]"* ]] || { echo "$output" >&2; return 1; }
}

# ─── Resolucao e listagem ──────────────────────────────────────────────────

@test "resolve por nome e por caminho" {
  _escrever porta 'install_zsh = 1'
  run _perfil 'perfil_resolver porta'
  [[ "$output" == *"/profiles/porta.conf"* ]]

  run _perfil "perfil_resolver '$PERFIS/porta.conf'"
  [[ "$output" == *"porta.conf"* ]]
}

@test "perfil inexistente lista os disponiveis" {
  _escrever um 'install_zsh = 1'
  _escrever dois 'install_zsh = 0'
  run _perfil 'perfil_aplicar naoexiste; echo "SAIDA=$?"'
  [[ "$output" == *"nao encontrado"* ]]
  [[ "$output" == *"um"* ]]
  [[ "$output" == *"dois"* ]]
  [[ "$output" == *"SAIDA=1"* ]]
}

@test "perfil_listar devolve um nome por linha, sem extensao" {
  _escrever alfa 'install_zsh = 1'
  _escrever beta 'install_zsh = 1'
  run _perfil 'perfil_listar'
  [ "$(echo "$output" | grep -c .)" -eq 2 ]
  [[ "$output" == *"alfa"* ]]
  [[ "$output" == *"beta"* ]]
  [[ "$output" != *".conf"* ]]
}

# ─── Os perfis que vao no repositorio ──────────────────────────────────────

@test "os perfis versionados carregam sem erro" {
  local nome
  for nome in minimo completo; do
    run no_ambiente "
      SCRIPT_DIR='$REPO_ROOT'
      . lib/perfil.sh
      perfil_aplicar $nome
      echo \"SAIDA=\$?\"
    "
    [[ "$output" == *"SAIDA=0"* ]] || {
      echo "perfil '$nome' falhou:" >&2; echo "$output" >&2; return 1; }
  done
}

@test "toda chave usada nos perfis versionados existe no catalogo" {
  # O contrario do teste acima: pega chave escrita a mao que o parser
  # recusaria so na hora de usar.
  local arquivo chave
  for arquivo in "$REPO_ROOT"/profiles/*.conf; do
    while IFS= read -r chave; do
      [[ -n "$chave" ]] || continue
      run _perfil "_perfil_campo '$chave' 1 >/dev/null; echo \$?"
      [[ "$output" == "0" ]] || {
        echo "$(basename "$arquivo"): chave '$chave' nao existe no catalogo" >&2
        return 1
      }
    done < <(grep -oE '^[a-z_]+[[:space:]]*=' "$arquivo" | sed 's/[[:space:]]*=$//')
  done
}
