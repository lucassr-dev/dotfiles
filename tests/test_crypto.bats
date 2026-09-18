#!/usr/bin/env bats
#
# Criptografia de chave privada (lib/crypto.sh).
#
# O ciclo completo e testado no modo IDENTIDADE, que e nao-interativo. O modo
# senha nao da para testar aqui: o age recusa senha vinda de pipe, de
# proposito, e exige terminal. Isso e propriedade do age, verificada, nao
# limitacao do teste -- e os dois modos compartilham todo o resto do caminho.
#
# O que precisa estar travado:
#   1. O texto em claro nao sobrevive no arquivo cifrado.
#   2. Decifrar com a identidade errada falha E nao deixa arquivo pela metade.
#   3. Cifrar um diretorio nao apaga o original antes de conferir a copia.
#   4. Arquivo que nao e chave privada nao e tocado.

load helpers/ambiente

setup() {
  ambiente_isolado

  # O ambiente isolado tem PATH proprio; o age precisa entrar nele
  # explicitamente, senao os testes medem a ausencia da ferramenta.
  local age_real age_keygen_real
  age_real=$(command -v age 2>/dev/null) || skip "age nao instalado"
  age_keygen_real=$(command -v age-keygen 2>/dev/null) || skip "age-keygen nao instalado"
  ln -sf "$age_real" "$FAKE_BIN/age"
  ln -sf "$age_keygen_real" "$FAKE_BIN/age-keygen"

  IDENT="$TEST_HOME/id.txt"
  age-keygen -o "$IDENT" 2>/dev/null
  chmod 600 "$IDENT"

  IDENT_OUTRA="$TEST_HOME/outra.txt"
  age-keygen -o "$IDENT_OUTRA" 2>/dev/null
  chmod 600 "$IDENT_OUTRA"

  SEGREDO='-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAA
-----END OPENSSH PRIVATE KEY-----'
}

teardown() { ambiente_limpar; }

_cripto() {
  no_ambiente "
    . lib/crypto.sh
    CRYPTO_IDENTIDADE='${2:-$IDENT}'
    $1
  " 2>&1
}

# ─── Deteccao ──────────────────────────────────────────────────────────────

@test "reconhece chave privada pelo conteudo, nao pela extensao" {
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/sem_extensao_nenhuma"
  run _cripto "crypto_eh_chave_privada '$TEST_HOME/sem_extensao_nenhuma'"
  [ "$status" -eq 0 ]

  # .pub tem o mesmo prefixo de nome e NAO e chave privada.
  echo "ssh-ed25519 AAAAC3Nza... user@host" > "$TEST_HOME/id_ed25519.pub"
  run _cripto "crypto_eh_chave_privada '$TEST_HOME/id_ed25519.pub'"
  [ "$status" -ne 0 ]
}

@test "reconhece arquivo ja cifrado" {
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/k"
  _cripto "crypto_cifrar '$TEST_HOME/k' '$TEST_HOME/k.age'" >/dev/null
  run _cripto "crypto_eh_cifrado '$TEST_HOME/k.age'"
  [ "$status" -eq 0 ]
  run _cripto "crypto_eh_cifrado '$TEST_HOME/k'"
  [ "$status" -ne 0 ]
}

@test "identidade invalida e recusada" {
  echo "isto nao e identidade" > "$TEST_HOME/falsa.txt"
  run _cripto "crypto_identidade_valida '$TEST_HOME/falsa.txt'"
  [ "$status" -ne 0 ]
  run _cripto "crypto_identidade_valida '$IDENT'"
  [ "$status" -eq 0 ]
}

# ─── O que mais importa: o segredo nao vaza ────────────────────────────────

@test "o texto em claro nao sobrevive no arquivo cifrado" {
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/k"
  _cripto "crypto_cifrar '$TEST_HOME/k' '$TEST_HOME/k.age'" >/dev/null

  [ -f "$TEST_HOME/k.age" ]
  if grep -qF "b3BlbnNzaC1rZXktdjEA" "$TEST_HOME/k.age"; then
    echo "o conteudo original aparece no arquivo cifrado" >&2
    return 1
  fi
  grep -q "BEGIN AGE ENCRYPTED FILE" "$TEST_HOME/k.age"
}

@test "o arquivo cifrado e texto, nao binario" {
  # Binario no git vira blob opaco: sem diff, sem merge, inchando a cada
  # rotacao de chave.
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/k"
  _cripto "crypto_cifrar '$TEST_HOME/k' '$TEST_HOME/k.age'" >/dev/null
  run file -b --mime-encoding "$TEST_HOME/k.age"
  [[ "$output" != "binary" ]] || { echo "saiu binario: $output" >&2; return 1; }
}

@test "o arquivo cifrado nasce com 600" {
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/k"
  _cripto "crypto_cifrar '$TEST_HOME/k' '$TEST_HOME/k.age'" >/dev/null
  [ "$(stat -c '%a' "$TEST_HOME/k.age")" = "600" ]
}

# ─── Ciclo completo ────────────────────────────────────────────────────────

@test "cifrar e decifrar devolve o conteudo byte a byte" {
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/k"
  local antes
  antes=$(md5sum < "$TEST_HOME/k")

  _cripto "crypto_cifrar '$TEST_HOME/k' '$TEST_HOME/k.age'" >/dev/null
  rm -f "$TEST_HOME/k"
  _cripto "crypto_decifrar '$TEST_HOME/k.age' '$TEST_HOME/k'" >/dev/null

  [ -f "$TEST_HOME/k" ]
  [ "$(md5sum < "$TEST_HOME/k")" = "$antes" ]
  [ "$(stat -c '%a' "$TEST_HOME/k")" = "600" ]
}

@test "identidade errada nao decifra E nao deixa arquivo pela metade" {
  # O caso que destroi dado: falhar DEPOIS de truncar o destino. Por isso
  # crypto_decifrar escreve em temporario e so move no fim.
  printf '%s\n' "$SEGREDO" > "$TEST_HOME/k"
  _cripto "crypto_cifrar '$TEST_HOME/k' '$TEST_HOME/k.age'" >/dev/null

  echo "CHAVE QUE FUNCIONAVA" > "$TEST_HOME/destino_existente"
  run _cripto "crypto_decifrar '$TEST_HOME/k.age' '$TEST_HOME/destino_existente'" "$IDENT_OUTRA"
  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_HOME/destino_existente")" = "CHAVE QUE FUNCIONAVA" ] || {
    echo "o destino foi destruido por uma decifragem que falhou" >&2
    return 1
  }
}

@test "decifrar algo que nao e do age falha com mensagem" {
  echo "arquivo qualquer" > "$TEST_HOME/nao_age"
  run _cripto "crypto_decifrar '$TEST_HOME/nao_age' '$TEST_HOME/saida'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"nao parece um arquivo do age"* ]]
  [ ! -f "$TEST_HOME/saida" ]
}

# ─── Diretorio ─────────────────────────────────────────────────────────────

@test "cifra so as chaves privadas e deixa o resto intacto" {
  local d="$TEST_HOME/ssh"; mkdir -p "$d"
  printf '%s\n' "$SEGREDO" > "$d/id_ed25519_pessoal"
  printf '%s\n' "$SEGREDO" > "$d/id_ed25519_trabalho"
  echo "ssh-ed25519 AAAA... user@host" > "$d/id_ed25519_pessoal.pub"
  echo "Host github.com" > "$d/config"
  echo "github.com ssh-ed25519 AAAA..." > "$d/known_hosts"

  _cripto "crypto_cifrar_diretorio '$d'" >/dev/null

  [ -f "$d/id_ed25519_pessoal.age" ]
  [ -f "$d/id_ed25519_trabalho.age" ]
  # Originais sumiram.
  [ ! -f "$d/id_ed25519_pessoal" ]
  [ ! -f "$d/id_ed25519_trabalho" ]
  # O que nao e segredo ficou em claro, que e onde ele serve.
  [ -f "$d/id_ed25519_pessoal.pub" ]
  [ -f "$d/config" ]
  [ -f "$d/known_hosts" ]
  [ "$(cat "$d/config")" = "Host github.com" ]
}

@test "o diretorio faz a volta completa" {
  local d="$TEST_HOME/ssh" h="$TEST_HOME/destino"
  mkdir -p "$d" "$h"
  printf '%s\n' "$SEGREDO" > "$d/id_ed25519_pessoal"
  local antes
  antes=$(md5sum < "$d/id_ed25519_pessoal")

  _cripto "crypto_cifrar_diretorio '$d'" >/dev/null
  _cripto "crypto_decifrar_diretorio '$d' '$h'" >/dev/null

  [ -f "$h/id_ed25519_pessoal" ]
  [ "$(md5sum < "$h/id_ed25519_pessoal")" = "$antes" ]
  [ "$(stat -c '%a' "$h/id_ed25519_pessoal")" = "600" ]
  # O .age continua la: decifrar nao consome a fonte.
  [ -f "$d/id_ed25519_pessoal.age" ]
}

@test "diretorio sem chave privada nao faz nada e nao falha" {
  local d="$TEST_HOME/vazio"; mkdir -p "$d"
  echo "so config" > "$d/config"
  run _cripto "crypto_cifrar_diretorio '$d'"
  [ "$status" -eq 0 ]
  [ ! -f "$d/config.age" ]
}

# ─── DRY_RUN ───────────────────────────────────────────────────────────────

@test "DRY_RUN nao cifra, nao apaga e nao escreve" {
  local d="$TEST_HOME/ssh"; mkdir -p "$d"
  printf '%s\n' "$SEGREDO" > "$d/id_ed25519_pessoal"
  local antes
  antes=$(find "$d" -type f | sort | md5sum)

  run no_ambiente "
    . lib/crypto.sh
    CRYPTO_IDENTIDADE='$IDENT'
    DRY_RUN=1
    crypto_cifrar_diretorio '$d'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  [ "$(find "$d" -type f | sort | md5sum)" = "$antes" ]
  [ -f "$d/id_ed25519_pessoal" ]
  [ ! -f "$d/id_ed25519_pessoal.age" ]
}
