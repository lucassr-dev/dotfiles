#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Criptografia de material secreto com age.
#
# Chave privada nao vai para o repositorio em claro, nem em repositorio
# privado: quem clona, quem faz backup e quem vaza o repo leva a chave junto.
#
# DOIS MODOS, e a diferenca entre eles e ovo-e-galinha:
#
#   senha      `age -p`. Nao se carrega nada -- o que destrava e o que se
#              lembra. Unico modo que funciona em maquina nova.
#              EXIGE TERMINAL: o age recusa senha vinda de pipe ou variavel,
#              de proposito, para ela nao vazar em historico, log ou lista de
#              processos. Nao ha como contornar, e nao se deve tentar.
#
#   identidade `age -i`. Nao pede nada, mas o arquivo de identidade passa a
#              ser o segredo a carregar -- e ele nao pode morar no repo.
#              Serve para CI e maquina de confianca, nao para bootstrap.
#
# O arquivo cifrado e armored (-a): texto, nao binario. Um .age binario no git
# vira blob opaco que nao da diff nem merge, e incha a cada rotacao de chave.

CRYPTO_SUFIXO=".age"
CRYPTO_IDENTIDADE="${CRYPTO_IDENTIDADE:-}"

crypto_disponivel() {
  has_cmd age
}

# Conteudo, nao extensao: uma chave privada continua sendo chave privada com
# qualquer nome de arquivo.
crypto_eh_chave_privada() {
  local arquivo="$1"
  [[ -f "$arquivo" ]] || return 1
  head -1 "$arquivo" 2>/dev/null | grep -qE 'BEGIN (OPENSSH|RSA|DSA|EC|PGP) PRIVATE KEY'
}

crypto_eh_cifrado() {
  local arquivo="$1"
  [[ -f "$arquivo" ]] || return 1
  head -1 "$arquivo" 2>/dev/null | grep -q 'BEGIN AGE ENCRYPTED FILE'
}

# Identidade valida = arquivo legivel com a linha AGE-SECRET-KEY.
crypto_identidade_valida() {
  local arquivo="$1"
  [[ -r "$arquivo" ]] || return 1
  grep -q '^AGE-SECRET-KEY-' "$arquivo" 2>/dev/null
}

_crypto_recipiente_da_identidade() {
  local identidade="$1"
  grep -oE '^# public key: (age1[a-z0-9]+)' "$identidade" 2>/dev/null | awk '{print $NF}' | head -1
}

# origem -> destino.age
crypto_cifrar() {
  local origem="$1" destino="$2"

  if ! crypto_disponivel; then
    err "age nao esta instalado; sem ele nao da para cifrar"
    return 1
  fi
  if [[ ! -f "$origem" ]]; then
    err "nada para cifrar em $origem"
    return 1
  fi

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) cifraria $origem -> $destino"
    return 0
  fi

  mkdir -p "$(dirname "$destino")"

  if [[ -n "$CRYPTO_IDENTIDADE" ]]; then
    local recipiente
    recipiente=$(_crypto_recipiente_da_identidade "$CRYPTO_IDENTIDADE")
    if [[ -z "$recipiente" ]]; then
      err "nao achei a chave publica em $CRYPTO_IDENTIDADE"
      return 1
    fi
    age -r "$recipiente" -a -o "$destino" "$origem" || {
      err "falha ao cifrar $origem"
      return 1
    }
  else
    # Sem redirecionar entrada: o prompt precisa do terminal.
    age -p -a -o "$destino" "$origem" || {
      err "falha ao cifrar $origem"
      return 1
    }
  fi

  chmod 600 "$destino" 2>/dev/null || true
  return 0
}

crypto_decifrar() {
  local origem="$1" destino="$2"

  if ! crypto_disponivel; then
    err "age nao esta instalado; sem ele nao da para decifrar"
    return 1
  fi
  if ! crypto_eh_cifrado "$origem"; then
    err "$origem nao parece um arquivo do age"
    return 1
  fi

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) decifraria $origem -> $destino"
    return 0
  fi

  mkdir -p "$(dirname "$destino")"

  # Escreve em temporario e so move depois: senha errada nao pode deixar
  # arquivo truncado no lugar de uma chave que funcionava.
  local tmp
  tmp="$(mktemp "${destino}.XXXXXX")" || return 1
  chmod 600 "$tmp" 2>/dev/null || true

  local ok=0
  if [[ -n "$CRYPTO_IDENTIDADE" ]]; then
    age -d -i "$CRYPTO_IDENTIDADE" -o "$tmp" "$origem" && ok=1
  else
    age -d -o "$tmp" "$origem" && ok=1
  fi

  if (( ok == 0 )); then
    rm -f "$tmp"
    err "nao decifrou $origem"
    return 1
  fi

  mv -f "$tmp" "$destino"
  chmod 600 "$destino" 2>/dev/null || true
  return 0
}

# Todas as chaves privadas de um diretorio, em claro -> cifradas.
# O original e apagado so depois que a copia cifrada e conferida.
crypto_cifrar_diretorio() {
  local dir="$1" arquivo destino cifradas=0

  [[ -d "$dir" ]] || return 0

  for arquivo in "$dir"/*; do
    [[ -f "$arquivo" ]] || continue
    crypto_eh_chave_privada "$arquivo" || continue

    destino="${arquivo}${CRYPTO_SUFIXO}"
    msg "  🔐 $(basename "$arquivo")"

    crypto_cifrar "$arquivo" "$destino" || return 1

    if is_truthy "${DRY_RUN:-0}"; then
      cifradas=$(( cifradas + 1 ))
      continue
    fi

    # Confere antes de apagar o original: um .age que nao decifra e pior que
    # nenhuma criptografia, porque a perda so aparece na proxima maquina.
    if ! crypto_eh_cifrado "$destino"; then
      err "o arquivo cifrado de $(basename "$arquivo") nao tem o cabecalho do age; original preservado"
      return 1
    fi

    rm -f "$arquivo"
    cifradas=$(( cifradas + 1 ))
  done

  (( cifradas > 0 )) && msg "  ✅ ${cifradas} chave(s) cifrada(s)"
  return 0
}

# Cifradas -> em claro, no destino, com 600. Nao apaga o .age.
crypto_decifrar_diretorio() {
  local dir_origem="$1" dir_destino="$2" arquivo nome destino decifradas=0

  [[ -d "$dir_origem" ]] || return 0

  for arquivo in "$dir_origem"/*"$CRYPTO_SUFIXO"; do
    [[ -f "$arquivo" ]] || continue
    nome="$(basename "$arquivo" "$CRYPTO_SUFIXO")"
    destino="$dir_destino/$nome"

    msg "  🔓 $nome"
    crypto_decifrar "$arquivo" "$destino" || return 1
    decifradas=$(( decifradas + 1 ))
  done

  (( decifradas > 0 )) && msg "  ✅ ${decifradas} chave(s) restaurada(s)"
  return 0
}

# Uma unica senha para o lote: o age pede a cada arquivo, e digitar seis vezes
# a mesma senha e o caminho mais curto para alguem guardar em arquivo.
crypto_aviso_de_senha() {
  local quantas="$1"
  (( quantas > 1 )) || return 0
  [[ -n "$CRYPTO_IDENTIDADE" ]] && return 0
  msg ""
  msg "  ${UI_OVERLAY1:-}O age pede a senha uma vez por arquivo — são ${quantas}.${UI_RESET:-}"
}
