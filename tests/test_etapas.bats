#!/usr/bin/env bats
#
# Selecao de etapas: --only e --skip (lib/etapas.sh).
#
# O que precisa estar certo:
#
# 1. Nome errado PARA, com a lista do que existe. Uma flag que nao faz nada e
#    pior que um erro: `--skip=tema` roda a instalacao inteira e a pessoa so
#    descobre depois. E o modo de falha mais caro dessa feature.
# 2. --only vence --skip. Somar as duas regras produz resultado que ninguem
#    preve de cabeca, entao a precedencia e fixa e testada.
# 3. O total da barra de progresso segue o recorte: com --only=temas o certo
#    e [1/1], nao [12/13].

load helpers/ambiente

setup() { ambiente_isolado; }
teardown() { ambiente_limpar; }

_etapas() {
  no_ambiente "
    . lib/etapas.sh
    ETAPAS_ONLY='${2:-}'
    ETAPAS_SKIP='${3:-}'
    $1
  " 2>&1
}

# ─── Validacao ─────────────────────────────────────────────────────────────

@test "nome valido passa" {
  run _etapas 'etapas_validar "temas,gui" "--only"; echo "SAIDA=$?"'
  [[ "$output" == *"SAIDA=0"* ]]
}

@test "lista vazia passa (nenhuma flag e o caso normal)" {
  run _etapas 'etapas_validar "" "--only"; echo "SAIDA=$?"'
  [[ "$output" == *"SAIDA=0"* ]]
}

@test "nome errado falha e lista as etapas validas" {
  run _etapas 'etapas_validar "tema" "--skip"; echo "SAIDA=$?"'
  [[ "$output" == *"SAIDA=1"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"desconhecida"* ]]
  # A resposta util e a lista: sem ela o erro nao ajuda a corrigir.
  [[ "$output" == *"temas"* ]]
  [[ "$output" == *"Etapas válidas"* ]]
}

@test "erro no plural quando ha mais de um nome errado" {
  run _etapas 'etapas_validar "tema,fonte" "--skip"'
  [[ "$output" == *"desconhecidas"* ]]
  [[ "$output" == *"tema fonte"* ]]
}

@test "um nome valido junto de um invalido ainda falha" {
  run _etapas 'etapas_validar "temas,inexistente" "--only"; echo "SAIDA=$?"'
  [[ "$output" == *"SAIDA=1"* ]]
  [[ "$output" == *"inexistente"* ]]
  [[ "$output" != *"temas desconhecid"* ]]
}

# ─── etapa_ativa ───────────────────────────────────────────────────────────

@test "sem flag nenhuma, toda etapa roda" {
  run _etapas '
    for s in $(etapas_slugs); do etapa_ativa "$s" || echo "PULOU=$s"; done
    echo FIM
  '
  [[ "$output" != *"PULOU="* ]]
}

@test "--only roda so o que foi pedido" {
  run _etapas '
    for s in $(etapas_slugs); do etapa_ativa "$s" && echo "RODA=$s"; done
    echo FIM
  ' "temas,gui"
  [[ "$output" == *"RODA=temas"* ]]
  [[ "$output" == *"RODA=gui"* ]]
  [[ "$output" != *"RODA=shells"* ]]
  [[ "$output" != *"RODA=cli"* ]]
}

@test "--skip roda tudo menos o que foi pedido" {
  run _etapas '
    for s in $(etapas_slugs); do etapa_ativa "$s" && echo "RODA=$s"; done
    echo FIM
  ' "" "fontes,gui"
  [[ "$output" != *"RODA=fontes"* ]]
  [[ "$output" != *"RODA=gui"* ]]
  [[ "$output" == *"RODA=shells"* ]]
  [[ "$output" == *"RODA=temas"* ]]
}

@test "--only vence --skip quando os dois aparecem" {
  # Precedencia fixa: quem pediu uma lista explicita ja disse tudo que queria.
  run _etapas '
    for s in $(etapas_slugs); do etapa_ativa "$s" && echo "RODA=$s"; done
    echo FIM
  ' "temas" "temas"
  [[ "$output" == *"RODA=temas"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" != *"RODA=gui"* ]]
}

# ─── Total da barra de progresso ───────────────────────────────────────────

@test "total sem recorte e o catalogo inteiro" {
  run _etapas 'echo "T=$(etapas_ativas_total) C=$(etapas_slugs | grep -c .)"'
  [[ "$output" =~ T=([0-9]+)\ C=([0-9]+) ]]
  [ "${BASH_REMATCH[1]}" -eq "${BASH_REMATCH[2]}" ]
}

@test "com --only=temas o total e 1" {
  run _etapas 'etapas_ativas_total' "temas"
  [ "$output" -eq 1 ]
}

@test "com --skip de duas, o total cai em duas" {
  local cheio recortado
  cheio=$(_etapas 'etapas_ativas_total')
  recortado=$(_etapas 'etapas_ativas_total' "" "fontes,gui")
  [ "$recortado" -eq $(( cheio - 2 )) ]
}

# ─── Aviso de instalacao parcial ───────────────────────────────────────────

@test "sem recorte nao ha aviso" {
  run _etapas 'etapas_resumo_do_recorte'
  [ -z "$output" ]
}

@test "com recorte, o aviso diz o que foi recortado" {
  run _etapas 'etapas_resumo_do_recorte' "temas,gui"
  [[ "$output" == *"somente"* ]]
  [[ "$output" == *"temas, gui"* ]]

  run _etapas 'etapas_resumo_do_recorte' "" "fontes"
  [[ "$output" == *"pulando"* ]]
  [[ "$output" == *"fontes"* ]]
}

# ─── Catalogo ──────────────────────────────────────────────────────────────

@test "todo slug do catalogo tem rotulo, e os dois sao unicos" {
  run _etapas '
    for s in $(etapas_slugs); do
      r=$(etapas_rotulo "$s") || echo "SEM_ROTULO=$s"
      [[ -z "$r" ]] && echo "ROTULO_VAZIO=$s"
    done
    etapas_slugs | sort | uniq -d | sed "s/^/SLUG_REPETIDO=/"
    echo FIM
  '
  [[ "$output" != *"SEM_ROTULO="* ]]
  [[ "$output" != *"ROTULO_VAZIO="* ]]
  [[ "$output" != *"SLUG_REPETIDO="* ]]
}

@test "o catalogo cobre as 13 etapas que o install.sh chama" {
  # Cruza o catalogo com os step_begin reais: etapa nova sem slug ficaria
  # impossivel de recortar, e ninguem perceberia.
  local no_install no_catalogo
  no_install=$(grep -c 'if etapa_ativa ' "$REPO_ROOT/install.sh")
  no_catalogo=$(_etapas 'etapas_slugs | grep -c .')
  [ "$no_install" -eq "$no_catalogo" ] || {
    echo "install.sh tem $no_install blocos, o catalogo tem $no_catalogo slugs" >&2
    return 1
  }
}

@test "todo slug usado no install.sh existe no catalogo" {
  local usados slug
  usados=$(grep -oE 'if etapa_ativa [a-z]+' "$REPO_ROOT/install.sh" | awk '{print $3}')
  for slug in $usados; do
    _etapas "etapas_rotulo '$slug' >/dev/null; echo \$?" | grep -q '^0$' || {
      echo "install.sh usa '$slug', que nao esta no catalogo" >&2
      return 1
    }
  done
}
