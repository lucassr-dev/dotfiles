#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Primitivas usadas por install.sh e por ate 18 modulos de lib/: mensagem,
# checagem de comando, flag booleana, registro de falha, execucao com/sem
# sudo e o diretorio de backup sob demanda. Antes viviam soltas no topo do
# install.sh; qualquer lib/*.sh que quisesse rodar sozinho (teste incluido)
# tinha que redefinir todas a mao. Este arquivo e a fonte unica delas — deve
# ser o primeiro "source" em install.sh, antes de qualquer outro e antes de
# qualquer chamada a estas funcoes.
#
# Dependencias que NAO viajaram para ca por serem estado amplo do install.sh
# (usado por muito mais coisa que so as funcoes abaixo), nao especificas de
# uma unica funcao:
#   - record_failure() le/grava CRITICAL_ERRORS, OPTIONAL_ERRORS e FAIL_FAST,
#     e chama print_final_summary() quando level=critical e FAIL_FAST=1.
#     Todos os quatro sao declarados/definidos em install.sh. Quem sourcing
#     este arquivo sozinho (ex.: teste) e exercita o caminho critico precisa
#     fornecer esses globals/funcao ou substituir record_failure por um stub.

# BACKUP_DIR e criado sob demanda: nenhuma execucao deve deixar um diretorio
# vazio em $HOME quando nada precisa ser copiado (ex.: DRY_RUN=1).
# _ensure_backup_dir NAO imprime nada de proposito: chamar em $(...) rodaria
# num subshell e a atribuicao a BACKUP_DIR se perderia ao sair dele. Use a
# variavel global diretamente depois de chamar a funcao.
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

# err era definida so em scripts/set_theme.sh, mas lib/theme_assets.sh a chama.
# Enquanto aquele script for o unico a carregar esse modulo, funciona; qualquer
# outro consumidor estouraria "err: command not found" no caminho de erro — que
# e justamente onde um "command not found" passa despercebido. Mora aqui agora,
# pelo mesmo motivo que msg e warn moram.
err() {
  printf '%b\n' "  ❌ $1" >&2
}

# Como msg, mas quebra o texto na largura do terminal em vez de deixar vazar
# para a linha seguinte. Usa _wrap_text de lib/utils.sh quando ele ja estiver
# carregado; senao imprime sem quebrar, que e o comportamento antigo — este
# modulo carrega antes do utils.sh e nao pode depender dele.
#
# A largura vem de `tput cols`, e a medicao de _wrap_text e em COLUNAS de
# exibicao (_visible_len), nao em bytes. Isso importa: uma frase com acento e
# emoji tem bem mais bytes do que colunas, e medir errado faz o texto quebrar
# cedo demais.
msg_wrap() {
  local texto="$1" margem="${2:-0}" largura
  if ! declare -F _wrap_text >/dev/null 2>&1; then
    msg "$texto"
    return 0
  fi
  largura=$(tput cols 2>/dev/null || echo 80)
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

  # Distingue "o sudo nao autenticou" de "o comando falhou". Sem isso, um
  # prompt de senha que expira vira uma mensagem enganosa: numa instalacao real
  # de 17/set o sudo deu "timed out" e o relatorio final acusou "Falha ao
  # instalar (apt) kitty" — sendo que o kitty ja estava instalado e o apt nunca
  # chegou a rodar. Quem le o relatorio vai investigar o pacote errado.
  #
  # -n falha na hora se a credencial nao estiver em cache, sem abrir prompt;
  # usamos isso so para DETECTAR, e em seguida rodamos normalmente para que o
  # prompt apareca de verdade quando for o caso.
  if ! sudo -n true 2>/dev/null; then
    if ! sudo -v 2>/dev/null; then
      warn "sudo nao autenticou (senha errada, expirada ou cancelada) — '$*' nao foi executado"
      return 126
    fi
  fi

  sudo "$@"
}

# Ponto de estrangulamento para comando externo que altera a maquina do
# usuario sem precisar de sudo (git clone, cargo install, fisher install,
# instalador via curl | sh chamado direto). Mesmo espirito do run_with_sudo:
# em DRY_RUN, imprime o que faria e devolve sucesso simulado sem tocar em
# nada; fora de DRY_RUN, executa o comando normalmente.
#
# Nao serve para comando cuja saida e capturada via `>` ou `$(...)` no
# proprio call site: a redirecao encostaria na mensagem de dry-run tambem,
# porque ela sai por stdout dentro desta funcao. Esses casos usam gate local.
run_mutating() {
  local desc="$1"
  shift
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) $desc ($*)"
    return 0
  fi
  "$@"
}
