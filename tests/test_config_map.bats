#!/usr/bin/env bats
#
# Tabela de correspondencia sistema <-> repositorio (data/config_map.sh).
#
# O risco desta tabela e envelhecer em silencio: alguem adiciona um par novo
# no export_configs, esquece a tabela, e o arquivo novo simplesmente nao
# aparece no doctor nem no diff -- sem erro, sem aviso. O teste que cruza as
# duas listas e o que transforma esse esquecimento em falha.

load helpers/ambiente

setup() {
  ambiente_isolado
  REPO_FALSO="$TEST_HOME/repo"
  mkdir -p "$REPO_FALSO"
}

teardown() {
  ambiente_limpar
}

_com_mapa() {
  no_ambiente "
    CONFIG_SHARED='$REPO_FALSO/shared'
    CONFIG_LINUX='$REPO_FALSO/linux'
    CONFIG_MACOS='$REPO_FALSO/macos'
    TARGET_OS=${2:-linux}
    . data/config_map.sh
    $1
  "
}

@test "a tabela carrega e tem 32 entradas" {
  run _com_mapa 'config_map_carregar; echo "${#CONFIG_MAP[@]}"'
  [ "$status" -eq 0 ]
  [ "$output" -eq 32 ]
}

@test "toda entrada tem os cinco campos" {
  run _com_mapa '
    config_map_carregar
    for e in "${CONFIG_MAP[@]}"; do
      n=$(awk -F"|" "{print NF}" <<< "$e")
      [[ "$n" -ne 5 ]] && echo "CAMPOS=$n: $e"
    done
    echo FIM
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *"CAMPOS="* ]]
}

@test "tipo e sempre file ou dir, os e sempre todos/linux/macos" {
  run _com_mapa '
    config_map_carregar
    for e in "${CONFIG_MAP[@]}"; do
      t="${e%%|*}"; o="${e##*|}"
      case "$t" in file|dir) ;; *) echo "TIPO=$t: $e" ;; esac
      case "$o" in todos|linux|macos) ;; *) echo "OS=$o: $e" ;; esac
    done
    echo FIM
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *"TIPO="* ]]
  [[ "$output" != *"OS="* ]]
}

@test "nenhum caminho de sistema aparece duas vezes" {
  run _com_mapa '
    config_map_carregar
    for e in "${CONFIG_MAP[@]}"; do
      IFS="|" read -r _ sis _ _ _ <<< "$e"
      echo "$sis"
    done | sort | uniq -d
    echo FIM
  '
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -vc '^FIM$')" -eq 0 ]
}

@test "todo par do export_configs esta na tabela" {
  # A checagem que importa: cruzar as duas listas pelo caminho no SISTEMA.
  # O export usa $export_git_dir e $export_ssh_dir no lado do repo, entao
  # comparar o lado do repo daria falso negativo; o lado do sistema e
  # escrito literal nos dois lugares.
  local do_export do_mapa faltando
  do_export=$(awk '/^export_configs\(\)/,/^}/' "$REPO_ROOT/lib/export.sh" \
    | grep -oE 'export_(file|dir) "\$HOME[^"]*"' \
    | sed -E 's/export_(file|dir) "//; s/"$//' \
    | grep -v 'skills/\$_skill_name' \
    | sort -u)

  do_mapa=$(_com_mapa '
    config_map_carregar
    for e in "${CONFIG_MAP[@]}"; do
      IFS="|" read -r _ sis _ _ _ <<< "$e"
      echo "${sis/#$HOME/\$HOME}"
    done' | sort -u)

  faltando=$(comm -23 <(echo "$do_export") <(echo "$do_mapa"))
  if [ -n "$faltando" ]; then
    echo "pares do export_configs que a tabela nao conhece:" >&2
    echo "$faltando" >&2
    return 1
  fi
}

@test "config_map_do_os filtra ghostty pelo sistema" {
  local linux macos
  linux=$(_com_mapa 'config_map_do_os linux' linux | grep -c 'Ghostty')
  macos=$(_com_mapa 'config_map_do_os macos' macos | grep -c 'Ghostty')
  [ "$linux" -eq 1 ]
  [ "$macos" -eq 1 ]

  # E cada um aponta para o diretorio do seu sistema.
  _com_mapa 'config_map_do_os linux' linux | grep 'Ghostty' | grep -q '/linux/ghostty'
  _com_mapa 'config_map_do_os macos' macos | grep 'Ghostty' | grep -q '/macos/ghostty'
}

@test "config_map_do_os devolve menos entradas que a tabela inteira" {
  local total do_linux
  total=$(_com_mapa 'config_map_carregar; echo "${#CONFIG_MAP[@]}"')
  do_linux=$(_com_mapa 'config_map_do_os linux' linux | grep -c .)
  [ "$do_linux" -lt "$total" ]
  [ "$do_linux" -eq $((total - 1)) ]
}

@test "config_map_skills lista o que existe, e nada quando nao ha skills" {
  run _com_mapa 'config_map_skills'
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  mkdir -p "$TEST_HOME/.claude/skills/graphify" "$TEST_HOME/.claude/skills/impeccable"
  run _com_mapa 'config_map_skills'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c .)" -eq 2 ]
  [[ "$output" == *"Skill graphify"* ]]
  [[ "$output" == *"Skill impeccable"* ]]
}
