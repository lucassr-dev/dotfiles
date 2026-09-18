#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Primitivas compartilhadas. Precisa ser o primeiro source do install.sh.
#
# record_failure depende de CRITICAL_ERRORS, OPTIONAL_ERRORS, FAIL_FAST e
# print_final_summary, todos definidos em install.sh: quem carregar este
# arquivo sozinho precisa fornece-los ou dar um stub.

# Nao imprime nada de proposito: chamar em $(...) rodaria num subshell e a
# atribuicao a BACKUP_DIR se perderia. Leia a global depois de chamar.
BACKUP_DIR=""
_ensure_backup_dir() {
  [[ -n "$BACKUP_DIR" ]] && return 0
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$(mktemp -d "$HOME/.bkp-${stamp}-XXXXXX" 2>/dev/null || echo "$HOME/.bkp-${stamp}-$$")"
  mkdir -p "$BACKUP_DIR"
}

msg() {
  printf '%b\n' "$1"
}

warn() {
  msg "  ⚠️ $1"
}

err() {
  printf '%b\n' "  ❌ $1" >&2
}

# IS_TTY vem de lib/ui.sh, que carrega depois: o default 0 e o que evita
# mexer na tela quando este modulo roda sozinho.
clear_screen() {
  if [[ "${IS_TTY:-0}" -eq 1 ]]; then
    printf '\033[2J\033[H\033[3J' > /dev/tty 2>/dev/null || true
  fi
}

# Grade de largura: fonte unica para tudo que e desenhado. Dois tetos porque
# caixa compacta nao deve esticar numa tela larga e tela cheia deve.
UI_WIDTH_MAX_BOX=70
UI_WIDTH_MAX_FULL=94
UI_WIDTH_MARGIN=4
UI_WIDTH_MIN=24

# O teste de numero nao e excesso de zelo: tput pode sair 0 e imprimir lixo,
# que iria direto para a aritmetica.
ui_term_cols() {
  local cols
  cols=$(tput cols 2>/dev/null) || cols=""
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  (( cols < 1 )) && cols=80
  echo "$cols"
}

# O piso nunca vence a largura real: piso que estoura a tela nao e piso, e
# overflow — a moldura quebra a linha e o desenho se perde.
ui_width() {
  local teto="${1:-$UI_WIDTH_MAX_BOX}" cols largura
  cols=$(ui_term_cols)
  largura=$(( cols - UI_WIDTH_MARGIN ))
  (( largura > teto )) && largura=$teto
  if (( largura < UI_WIDTH_MIN )); then
    largura=$UI_WIDTH_MIN
    (( largura > cols )) && largura=$cols
  fi
  echo "$largura"
}

# Cai para msg sem quebrar quando utils.sh ainda nao carregou: este modulo
# vem antes dele e nao pode depender de _wrap_text.
msg_wrap() {
  local texto="$1" margem="${2:-0}" largura
  if ! declare -F _wrap_text >/dev/null 2>&1; then
    msg "$texto"
    return 0
  fi
  largura=$(ui_term_cols)
  largura=$(( largura - margem ))
  (( largura < 20 )) && largura=20
  local -a partes=()
  _wrap_text "$texto" "$largura" partes
  local linha
  for linha in "${partes[@]}"; do
    msg "$(printf '%*s' "$margem" '')$linha"
  done
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

record_failure() {
  local level="$1"
  local message="$2"
  local fix_hint="${3:-}"
  # A live warn() so mostra a dica na hora -- sem isso ela some do
  # relatorio final, que so tem o array. Guarda a dica junto na mensagem
  # armazenada (nao muda a chamada, so o que fica pra depois) para
  # print_post_install_report poder responder "o que fazer a respeito".
  local stored="$message"
  [[ -n "$fix_hint" ]] && stored="${message} — ${fix_hint}"
  if [[ "$level" == "critical" ]]; then
    CRITICAL_ERRORS+=("$stored")
    warn "❌ $message"
    [[ -n "$fix_hint" ]] && warn "💡 $fix_hint"
    if [[ "$FAIL_FAST" -eq 1 ]]; then
      print_final_summary 1
    fi
  else
    OPTIONAL_ERRORS+=("$stored")
    warn "$message"
    [[ -n "$fix_hint" ]] && warn "💡 $fix_hint"
  fi
  return 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_with_sudo() {
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) sudo $*"
    return 0
  fi
  if [[ $EUID -eq 0 ]]; then
    "$@"
    return $?
  fi

  if ! has_cmd sudo; then
    warn "Comando '$*' requer sudo, mas sudo não está disponível."
    return 1
  fi

  # Distingue "sudo nao autenticou" (126) de "o comando falhou". Sem isso um
  # prompt expirado vira "falha ao instalar X", e se investiga o pacote errado.
  # O -n so DETECTA credencial em cache; o sudo real vem depois, com prompt.
  if ! sudo -n true 2>/dev/null; then
    if ! sudo -v 2>/dev/null; then
      warn "sudo nao autenticou (senha errada, expirada ou cancelada) — '$*' nao foi executado"
      return 126
    fi
  fi

  sudo "$@"
}

# Gate de DRY_RUN para comando que altera a maquina sem sudo.
#
# NAO serve quando a saida e capturada por `>` ou `$(...)` no call site: a
# mensagem de dry-run sai por stdout daqui e seria capturada junto.
run_mutating() {
  local desc="$1"
  shift
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) $desc ($*)"
    return 0
  fi
  "$@"
}
