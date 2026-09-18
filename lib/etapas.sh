#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Selecao de etapas: --only e --skip.
#
# O nome e validado na entrada, nao ignorado: `--skip=tema`, sem o "s",
# rodaria a instalacao inteira e so se descobriria depois.

# slug|rotulo, o mesmo rotulo que aparece na barra de progresso.
ETAPAS_CATALOGO=(
  "shells|Shells"
  "cli|Ferramentas CLI"
  "gui|Apps GUI"
  "ia|Ferramentas IA"
  "vscode|Extensões VS Code"
  "configs|Configs Compartilhados"
  "git|Git"
  "plataforma|Configs de Plataforma"
  "runtimes|Runtimes"
  "editores|Editores"
  "fontes|Fontes Nerd"
  "temas|Temas"
  "padroes|Padrões do Sistema"
)

ETAPAS_ONLY=""
ETAPAS_SKIP=""

etapas_slugs() {
  local entrada
  for entrada in "${ETAPAS_CATALOGO[@]}"; do
    printf '%s\n' "${entrada%%|*}"
  done
}

etapas_rotulo() {
  local alvo="$1" entrada
  for entrada in "${ETAPAS_CATALOGO[@]}"; do
    [[ "${entrada%%|*}" == "$alvo" ]] && { printf '%s\n' "${entrada#*|}"; return 0; }
  done
  return 1
}

_etapa_existe() {
  local alvo="$1" entrada
  for entrada in "${ETAPAS_CATALOGO[@]}"; do
    [[ "${entrada%%|*}" == "$alvo" ]] && return 0
  done
  return 1
}

# Devolve 1 para quem chamou decidir se sai; em install.sh, sai.
etapas_validar() {
  local lista="$1" origem="$2" nome invalidos=()
  local IFS=','
  for nome in $lista; do
    [[ -z "$nome" ]] && continue
    _etapa_existe "$nome" || invalidos+=("$nome")
  done
  unset IFS

  (( ${#invalidos[@]} == 0 )) && return 0

  local plural="etapa desconhecida"
  (( ${#invalidos[@]} > 1 )) && plural="etapas desconhecidas"
  err "$origem: $plural: ${invalidos[*]}"

  # Sem o carimbo do err(): repetir ❌ na lista vira ruido de alarme.
  printf '\n%b\n' "${UI_BOLD:-}Etapas válidas:${UI_RESET:-}" >&2
  local slug rotulo
  while IFS= read -r slug; do
    rotulo=$(etapas_rotulo "$slug")
    printf '  %b%-12s%b %s\n' "${UI_SKY:-}" "$slug" "${UI_RESET:-}" "$rotulo" >&2
  done < <(etapas_slugs)
  printf '\n' >&2
  return 1
}

# --only vence --skip: somar as duas regras da resultado imprevisivel.
etapa_ativa() {
  local etapa="$1" nome

  if [[ -n "$ETAPAS_ONLY" ]]; then
    local IFS=','
    for nome in $ETAPAS_ONLY; do
      [[ "$nome" == "$etapa" ]] && return 0
    done
    return 1
  fi

  if [[ -n "$ETAPAS_SKIP" ]]; then
    local IFS=','
    for nome in $ETAPAS_SKIP; do
      [[ "$nome" == "$etapa" ]] && return 1
    done
  fi

  return 0
}

# Com --only=temas a barra tem que dizer [1/1], nao [12/13].
etapas_ativas_total() {
  local slug total=0
  while IFS= read -r slug; do
    etapa_ativa "$slug" && total=$(( total + 1 ))
  done < <(etapas_slugs)
  printf '%s\n' "$total"
}

# Instalacao parcial tem que se anunciar como parcial.
etapas_resumo_do_recorte() {
  if [[ -n "$ETAPAS_ONLY" ]]; then
    printf 'somente: %s\n' "${ETAPAS_ONLY//,/, }"
  elif [[ -n "$ETAPAS_SKIP" ]]; then
    printf 'pulando: %s\n' "${ETAPAS_SKIP//,/, }"
  fi
}
