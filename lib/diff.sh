#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Mostra o que difere entre repositorio e sistema. O doctor diz o QUE
# divergiu; este diz divergiu NO QUE, que e o que decide a acao.
#
# SENTIDO, valido em toda a saida:  "-" repositorio,  "+" sistema.
#
# Nao e detalhe de apresentacao: as duas leituras sao plausiveis e levam a
# acoes opostas -- quem le "+" como "o repo tem isto" roda install quando
# devia rodar export, e sobrescreve o que queria salvar.

DIFF_DIVERGENTES=0
DIFF_SO_SISTEMA=0
DIFF_SO_REPO=0
DIFF_IGUAIS=0

diff_reiniciar() {
  DIFF_DIVERGENTES=0
  DIFF_SO_SISTEMA=0
  DIFF_SO_REPO=0
  DIFF_IGUAIS=0
}

# Quantas linhas (arquivo) ou quantos arquivos (diretorio) diferem.
_diff_tamanho() {
  local tipo="$1" sistema="$2" repo="$3"
  if [[ "$tipo" == "dir" ]]; then
    local n
    n=$(diff -rq "$repo" "$sistema" 2>/dev/null | grep -c .)
    printf '%s arquivo(s)' "$n"
  else
    local n
    n=$(diff "$repo" "$sistema" 2>/dev/null | grep -cE '^[<>]')
    printf '%s linha(s)' "$n"
  fi
}

# O conteudo da diferenca, ja no sentido repo(-) -> sistema(+).
_diff_conteudo() {
  local tipo="$1" sistema="$2" repo="$3" limite="${4:-40}"
  if [[ "$tipo" == "dir" ]]; then
    diff -rq "$repo" "$sistema" 2>/dev/null | head -"$limite"
  else
    diff -u "$repo" "$sistema" 2>/dev/null | tail -n +3 | head -"$limite"
  fi
}

_diff_linha_colorida() {
  local linha="$1"
  case "$linha" in
    -*) printf '%b\n' "${UI_RED}${linha}${UI_RESET}" ;;
    +*) printf '%b\n' "${UI_GREEN}${linha}${UI_RESET}" ;;
    @*) printf '%b\n' "${UI_SKY}${linha}${UI_RESET}" ;;
    *)  printf '%b\n' "${UI_OVERLAY1}${linha}${UI_RESET}" ;;
  esac
}

run_diff() {
  diff_reiniciar

  local largura
  largura=$(ui_width "$UI_WIDTH_MAX_FULL")

  clear_screen
  msg ""
  msg "  ${UI_SKY}${UI_BOLD}Repositório × Sistema${UI_RESET}"
  msg "  ${UI_RED}−${UI_RESET}${UI_OVERLAY1} repositório${UI_RESET}   ${UI_GREEN}+${UI_RESET}${UI_OVERLAY1} sistema${UI_RESET}"
  msg ""

  local detalhado=0
  is_truthy "${VERBOSE:-0}" && detalhado=1

  local entrada tipo sistema repo rotulo estado
  while IFS= read -r entrada; do
    [[ -n "$entrada" ]] || continue
    IFS='|' read -r tipo sistema repo rotulo _ <<< "$entrada"
    estado=$(doctor_comparar "$tipo" "$sistema" "$repo")

    case "$estado" in
      igual)
        DIFF_IGUAIS=$(( DIFF_IGUAIS + 1 ))
        ;;
      diferente)
        DIFF_DIVERGENTES=$(( DIFF_DIVERGENTES + 1 ))
        msg "  ${UI_YELLOW}~${UI_RESET} ${UI_BOLD}${rotulo}${UI_RESET}${UI_OVERLAY1} — $(_diff_tamanho "$tipo" "$sistema" "$repo")${UI_RESET}"
        if (( detalhado == 1 )); then
          local linha
          while IFS= read -r linha; do
            msg "      $(_diff_linha_colorida "$linha")"
          done < <(_diff_conteudo "$tipo" "$sistema" "$repo")
          msg ""
        fi
        ;;
      so_sistema)
        DIFF_SO_SISTEMA=$(( DIFF_SO_SISTEMA + 1 ))
        msg "  ${UI_GREEN}+${UI_RESET} ${UI_BOLD}${rotulo}${UI_RESET}${UI_OVERLAY1} — só no sistema${UI_RESET}"
        ;;
      so_repo)
        DIFF_SO_REPO=$(( DIFF_SO_REPO + 1 ))
        msg "  ${UI_RED}−${UI_RESET} ${UI_BOLD}${rotulo}${UI_RESET}${UI_OVERLAY1} — só no repositório${UI_RESET}"
        ;;
    esac
  done < <(config_map_do_os "${TARGET_OS:-linux}"; config_map_skills)

  msg ""
  if (( DIFF_DIVERGENTES == 0 && DIFF_SO_SISTEMA == 0 && DIFF_SO_REPO == 0 )); then
    msg "  ${UI_GREEN}${UI_BOLD}Nada a sincronizar${UI_RESET}${UI_TEXT} — ${DIFF_IGUAIS} config(s) em dia.${UI_RESET}"
    msg ""
    return 0
  fi

  msg "  ${UI_TEXT}${DIFF_DIVERGENTES} divergente(s), ${DIFF_SO_SISTEMA} só no sistema, ${DIFF_SO_REPO} só no repositório, ${DIFF_IGUAIS} em dia.${UI_RESET}"
  if (( detalhado == 0 )); then
    msg "  ${UI_OVERLAY1}--verbose mostra o conteúdo de cada diferença.${UI_RESET}"
  fi
  msg "  ${UI_OVERLAY1}'install.sh' aplica o repositório; 'install.sh export' recolhe do sistema.${UI_RESET}"
  msg ""
  return 0
}
