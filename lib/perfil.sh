#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Perfil: instalacao sem pergunta nenhuma (--profile).
#
# O ARQUIVO E LIDO, NUNCA EXECUTADO. `source` sairia de graca, mas perfil e
# arquivo que se baixa e se compartilha: viraria execucao de codigo arbitrario
# num script que usa sudo. Se for mexer aqui, mantenha o parse.
#
# Formato: `chave = valor`, "#" comenta. Lista vazia significa nenhum, que e
# diferente da chave nao aparecer (ai vale o default do instalador).

# chave|variavel|tipo
#   flag   0 ou 1
#   lista  CSV que vira array
#   texto  valor unico
PERFIL_CHAVES=(
  "install_zsh|INSTALL_ZSH|flag"
  "install_fish|INSTALL_FISH|flag"
  "install_nushell|INSTALL_NUSHELL|flag"
  "install_base_deps|INSTALL_BASE_DEPS|flag"
  "install_oh_my_zsh|INSTALL_OH_MY_ZSH|flag"
  "install_starship|INSTALL_STARSHIP|flag"
  "install_oh_my_posh|INSTALL_OH_MY_POSH|flag"
  "git_configure|GIT_CONFIGURE|flag"
  "copy_terminal|COPY_TERMINAL_CONFIG|flag"
  "copy_vscode|COPY_VSCODE_SETTINGS|flag"
  "copy_ssh|COPY_SSH_KEYS|flag"
  "cli_tools|SELECTED_CLI_TOOLS|lista"
  "ia_tools|SELECTED_IA_TOOLS|lista"
  "terminals|SELECTED_TERMINALS|lista"
  "runtimes|SELECTED_RUNTIMES|lista"
  "fonts|SELECTED_NERD_FONTS|lista"
  "browsers|SELECTED_BROWSERS|lista"
  "ides|SELECTED_IDES|lista"
  "dev_tools|SELECTED_DEV_TOOLS|lista"
  "databases|SELECTED_DATABASES|lista"
  "communication|SELECTED_COMMUNICATION|lista"
  "media|SELECTED_MEDIA|lista"
  "productivity|SELECTED_PRODUCTIVITY|lista"
  "utilities|SELECTED_UTILITIES|lista"
  "fish_plugins|SELECTED_FISH_PLUGINS|lista"
  "omz_plugins|SELECTED_OMZ_PLUGINS|lista"
  "omz_external_plugins|SELECTED_OMZ_EXTERNAL_PLUGINS|lista"
  "starship_preset|SELECTED_STARSHIP_PRESET|texto"
  "omp_theme|SELECTED_OMP_THEME|texto"
)

PERFIL_ARQUIVO=""
PERFIL_NOME=""

_perfil_campo() {
  local chave="$1" indice="$2" entrada
  for entrada in "${PERFIL_CHAVES[@]}"; do
    if [[ "${entrada%%|*}" == "$chave" ]]; then
      printf '%s\n' "$entrada" | cut -d'|' -f"$indice"
      return 0
    fi
  done
  return 1
}

perfil_listar() {
  local dir="${SCRIPT_DIR:-.}/profiles" arquivo
  [[ -d "$dir" ]] || return 0
  for arquivo in "$dir"/*.conf; do
    [[ -f "$arquivo" ]] || continue
    basename "$arquivo" .conf
  done
}

# Aceita tanto um nome ("minimo") quanto um caminho ("./meu.conf").
perfil_resolver() {
  local pedido="$1"
  if [[ -f "$pedido" ]]; then
    printf '%s\n' "$pedido"
    return 0
  fi
  local candidato="${SCRIPT_DIR:-.}/profiles/${pedido}.conf"
  if [[ -f "$candidato" ]]; then
    printf '%s\n' "$candidato"
    return 0
  fi
  return 1
}

# Quem escreve no perfil escolhe o que a maquina instala. Mesma postura do
# checkpoint.
_perfil_seguro() {
  local arquivo="$1" modo
  modo=$(stat -c '%a' "$arquivo" 2>/dev/null || stat -f '%OLp' "$arquivo" 2>/dev/null || echo "")
  [[ -z "$modo" ]] && return 0
  # Ultimo digito e "outros": 2, 3, 6 e 7 incluem escrita.
  case "${modo: -1}" in
    2|3|6|7) return 1 ;;
  esac
  # Penultimo e "grupo".
  case "${modo: -2:1}" in
    2|3|6|7) return 1 ;;
  esac
  return 0
}

# Le o arquivo e devolve "chave=valor" por linha, ja normalizado. Recusa
# chave desconhecida, mostrando as validas.
perfil_analisar() {
  local arquivo="$1"
  local numero=0 linha chave valor invalidas=()

  while IFS= read -r linha || [[ -n "$linha" ]]; do
    numero=$(( numero + 1 ))
    linha="${linha%%#*}"
    linha="${linha#"${linha%%[![:space:]]*}"}"
    linha="${linha%"${linha##*[![:space:]]}"}"
    [[ -z "$linha" ]] && continue

    if [[ "$linha" != *=* ]]; then
      err "$arquivo:$numero: linha sem '=': $linha"
      return 1
    fi

    chave="${linha%%=*}"
    valor="${linha#*=}"
    chave="${chave%"${chave##*[![:space:]]}"}"
    chave="${chave#"${chave%%[![:space:]]*}"}"
    valor="${valor#"${valor%%[![:space:]]*}"}"
    valor="${valor%"${valor##*[![:space:]]}"}"

    if ! _perfil_campo "$chave" 1 >/dev/null; then
      invalidas+=("$numero:$chave")
      continue
    fi

    printf '%s=%s\n' "$chave" "$valor"
  done < "$arquivo"

  if (( ${#invalidas[@]} > 0 )); then
    err "$arquivo: chave(s) desconhecida(s)"
    local par
    for par in "${invalidas[@]}"; do
      printf '  linha %s: %b%s%b\n' "${par%%:*}" "${UI_RED:-}" "${par#*:}" "${UI_RESET:-}" >&2
    done
    printf '\n%bChaves válidas:%b\n' "${UI_BOLD:-}" "${UI_RESET:-}" >&2
    local entrada
    for entrada in "${PERFIL_CHAVES[@]}"; do
      printf '  %b%-18s%b %s\n' "${UI_SKY:-}" "${entrada%%|*}" "${UI_RESET:-}" \
        "$(printf '%s' "$entrada" | cut -d'|' -f3)" >&2
    done
    printf '\n' >&2
    return 1
  fi
  return 0
}

# Aplica o perfil nas globais. Nao chama nenhum ask_*.
perfil_aplicar() {
  local pedido="$1" arquivo

  if ! arquivo=$(perfil_resolver "$pedido"); then
    err "perfil nao encontrado: $pedido"
    local disponiveis
    disponiveis=$(perfil_listar | paste -sd', ')
    if [[ -n "$disponiveis" ]]; then
      printf '\n%bPerfis disponíveis:%b %s\n\n' "${UI_BOLD:-}" "${UI_RESET:-}" "$disponiveis" >&2
    else
      printf '\n  Nenhum perfil em %s/profiles/\n\n' "${SCRIPT_DIR:-.}" >&2
    fi
    return 1
  fi

  if ! _perfil_seguro "$arquivo"; then
    err "perfil com permissao de escrita para grupo ou outros: $arquivo"
    err "quem escreve no perfil escolhe o que esta maquina instala; use chmod 644"
    return 1
  fi

  local pares
  pares=$(perfil_analisar "$arquivo") || return 1

  PERFIL_ARQUIVO="$arquivo"
  PERFIL_NOME="$(basename "$arquivo" .conf)"

  local par chave valor variavel tipo
  while IFS= read -r par; do
    [[ -n "$par" ]] || continue
    chave="${par%%=*}"
    valor="${par#*=}"
    variavel=$(_perfil_campo "$chave" 2)
    tipo=$(_perfil_campo "$chave" 3)

    case "$tipo" in
      flag)
        if is_truthy "$valor"; then
          printf -v "$variavel" '%s' 1
        else
          printf -v "$variavel" '%s' 0
        fi
        ;;
      texto)
        printf -v "$variavel" '%s' "$valor"
        ;;
      lista)
        local -a itens=()
        if [[ -n "$valor" ]]; then
          local item
          local IFS=','
          for item in $valor; do
            item="${item#"${item%%[![:space:]]*}"}"
            item="${item%"${item##*[![:space:]]}"}"
            [[ -n "$item" ]] && itens+=("$item")
          done
          unset IFS
        fi
        # eval e o unico jeito de atribuir array por nome em bash 4. O nome
        # vem do catalogo, nunca do arquivo, e os itens vao com %q.
        local citados=""
        local i
        for i in "${itens[@]}"; do
          citados+=" $(printf '%q' "$i")"
        done
        eval "$variavel=($citados)"
        ;;
    esac
  done <<< "$pares"

  return 0
}

perfil_resumo() {
  [[ -n "$PERFIL_NOME" ]] || return 0
  printf 'perfil: %s\n' "$PERFIL_NOME"
}
