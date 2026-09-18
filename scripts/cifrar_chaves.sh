#!/usr/bin/env bash
set -uo pipefail
#
# Cifra as chaves privadas de shared/.ssh com age, uma vez.
#
# Precisa de terminal: o age recusa senha vinda de pipe. Rode direto, sem
# redirecionar entrada, sem pipe.
#
# Ordem deliberada -- cifra, DECIFRA E COMPARA, e so entao apaga o original.
# Conferir o cabecalho do arquivo cifrado nao basta: um .age com cabecalho
# valido que nao abre com a sua senha e perda total, e a perda so apareceria
# na proxima maquina, quando ja nao houvesse de onde recuperar.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_DIR="$SCRIPT_DIR/shared/.ssh"

source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/colors.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/crypto.sh"

DRY_RUN="${DRY_RUN:-0}"

if ! crypto_disponivel; then
  err "age nao encontrado. Instale com: bash install.sh --only=cli"
  exit 1
fi

if [[ ! -t 0 ]]; then
  err "sem terminal na entrada. O age pede a senha diretamente do terminal;"
  err "rode este script direto, sem pipe e sem redirecionar."
  exit 1
fi

mapfile -t chaves < <(
  for f in "$SSH_DIR"/*; do
    [[ -f "$f" ]] || continue
    crypto_eh_chave_privada "$f" && printf '%s\n' "$f"
  done
)

if (( ${#chaves[@]} == 0 )); then
  msg ""
  msg "  ${UI_GREEN:-}Nenhuma chave em claro em shared/.ssh${UI_RESET:-}"
  ja=$(find "$SSH_DIR" -name '*.age' 2>/dev/null | grep -c . || true)
  (( ja > 0 )) && msg "  ${UI_OVERLAY1:-}${ja} ja estao cifradas.${UI_RESET:-}"
  msg ""
  exit 0
fi

BACKUP="$(mktemp -d "${TMPDIR:-/tmp}/chaves-antes-de-cifrar-XXXXXX")"
chmod 700 "$BACKUP"

# Interrupcao no meio da conferencia (Ctrl-C, timeout, terminal fechado)
# deixaria um .age orfao ao lado do original: nem cifrado de verdade, nem
# limpo. Descoberto testando -- o processo morreu entre cifrar e conferir.
EM_CURSO=""
CONFERINDO=""
_limpar_pela_metade() {
  [[ -n "$CONFERINDO" ]] && rm -f "$CONFERINDO"
  if [[ -n "$EM_CURSO" && -f "$EM_CURSO" ]]; then
    rm -f "$EM_CURSO"
    printf '\n  Interrompido: %s removido, original intacto.\n' "$(basename "$EM_CURSO")" >&2
  fi
}
trap _limpar_pela_metade EXIT INT TERM

msg ""
msg "  ${UI_SKY:-}${UI_BOLD:-}Cifrar chaves privadas${UI_RESET:-}"
msg ""
msg "  ${#chaves[@]} chave(s) em claro:"
for k in "${chaves[@]}"; do
  msg "    ${UI_PEACH:-}$(basename "$k")${UI_RESET:-}"
done
msg ""
msg "  ${UI_OVERLAY1:-}Backup do texto puro: ${BACKUP}${UI_RESET:-}"
msg "  ${UI_OVERLAY1:-}Use a MESMA senha nas ${#chaves[@]}: e ela que abre tudo numa máquina nova.${UI_RESET:-}"
msg ""

for k in "${chaves[@]}"; do
  cp -p "$k" "$BACKUP/$(basename "$k")"
done

falhou=0
for k in "${chaves[@]}"; do
  nome="$(basename "$k")"
  destino="${k}${CRYPTO_SUFIXO}"

  msg "  ${UI_BOLD:-}${nome}${UI_RESET:-}"

  EM_CURSO="$destino"
  if ! crypto_cifrar "$k" "$destino"; then
    err "  falha ao cifrar $nome — original preservado"
    EM_CURSO=""
    falhou=1
    continue
  fi

  # A prova: decifra de volta e compara com o original.
  conferencia="$(mktemp)"
  CONFERINDO="$conferencia"
  chmod 600 "$conferencia"
  msg "    ${UI_OVERLAY1:-}conferindo (a senha e pedida de novo)${UI_RESET:-}"

  if ! crypto_decifrar "$destino" "$conferencia"; then
    err "  o arquivo cifrado de $nome NAO decifrou — original preservado"
    rm -f "$conferencia" "$destino"
    CONFERINDO=""; EM_CURSO=""
    falhou=1
    continue
  fi

  if ! cmp -s "$k" "$conferencia"; then
    err "  o conteudo decifrado de $nome difere do original — original preservado"
    rm -f "$conferencia" "$destino"
    CONFERINDO=""; EM_CURSO=""
    falhou=1
    continue
  fi

  rm -f "$conferencia"
  CONFERINDO=""
  rm -f "$k"
  EM_CURSO=""
  msg "    ${UI_GREEN:-}✓ cifrada e conferida${UI_RESET:-}"
done

msg ""
if (( falhou == 1 )); then
  err "Alguma chave falhou. Nada foi perdido: o texto puro esta em $BACKUP"
  exit 1
fi

msg "  ${UI_GREEN:-}${UI_BOLD:-}Todas cifradas e conferidas.${UI_RESET:-}"
msg ""
msg "  ${UI_OVERLAY1:-}O texto puro continua em ${BACKUP} ate voce apagar.${UI_RESET:-}"
msg "  ${UI_OVERLAY1:-}As chaves em ~/.ssh nao foram tocadas.${UI_RESET:-}"
msg ""
