#!/usr/bin/env bats
#
# Modo doctor (lib/doctor.sh).
#
# A promessa central e nao alterar nada. Um diagnostico que escreve deixa de
# ser diagnostico -- e o teste que garante isso compara a arvore inteira do
# HOME antes e depois, nao so os arquivos que o doctor menciona.
#
# A outra coisa que precisa estar certa e o codigo de saida: 1 quando ha erro,
# 0 quando ha so aviso. E o que permite encadear em CI ou em `&&`. A distincao
# entre os dois nao e cosmetica: erro e coisa que quebra uma etapa da
# instalacao, aviso e coisa opcional ausente ou config divergente.

load helpers/ambiente

setup() {
  ambiente_isolado
  REPO_FALSO="$TEST_HOME/repo"
  mkdir -p "$REPO_FALSO/shared"
}

teardown() {
  ambiente_limpar
}

_doutor() {
  no_ambiente "
    SCRIPT_DIR='$REPO_ROOT'
    CONFIG_SHARED='$REPO_FALSO/shared'
    CONFIG_LINUX='$REPO_FALSO/linux'
    CONFIG_MACOS='$REPO_FALSO/macos'
    TARGET_OS=linux
    LINUX_PKG_MANAGER=apt-get
    . data/config_map.sh
    . lib/doctor.sh
    $1
  " 2>&1
}

# ─── doctor_comparar ───────────────────────────────────────────────────────

@test "comparar: arquivo identico nos dois lados" {
  echo "igual" > "$TEST_HOME/a"; echo "igual" > "$TEST_HOME/b"
  run _doutor "doctor_comparar file '$TEST_HOME/a' '$TEST_HOME/b'"
  [ "$output" = "igual" ]
}

@test "comparar: arquivo com conteudo diferente" {
  echo "um" > "$TEST_HOME/a"; echo "dois" > "$TEST_HOME/b"
  run _doutor "doctor_comparar file '$TEST_HOME/a' '$TEST_HOME/b'"
  [ "$output" = "diferente" ]
}

@test "comparar: so no sistema, so no repo, ausente nos dois" {
  echo "x" > "$TEST_HOME/so_sis"
  run _doutor "doctor_comparar file '$TEST_HOME/so_sis' '$TEST_HOME/nao_existe'"
  [ "$output" = "so_sistema" ]

  echo "x" > "$TEST_HOME/so_rep"
  run _doutor "doctor_comparar file '$TEST_HOME/nao_existe' '$TEST_HOME/so_rep'"
  [ "$output" = "so_repo" ]

  run _doutor "doctor_comparar file '$TEST_HOME/nada1' '$TEST_HOME/nada2'"
  [ "$output" = "ausente" ]
}

@test "comparar: diretorio olha o conteudo, nao so a existencia" {
  mkdir -p "$TEST_HOME/d1/sub" "$TEST_HOME/d2/sub"
  echo "a" > "$TEST_HOME/d1/sub/f"; echo "a" > "$TEST_HOME/d2/sub/f"
  run _doutor "doctor_comparar dir '$TEST_HOME/d1' '$TEST_HOME/d2'"
  [ "$output" = "igual" ]

  echo "b" > "$TEST_HOME/d2/sub/f"
  run _doutor "doctor_comparar dir '$TEST_HOME/d1' '$TEST_HOME/d2'"
  [ "$output" = "diferente" ]

  # Arquivo a mais num dos lados tambem e divergencia.
  echo "b" > "$TEST_HOME/d1/sub/f"
  echo "extra" > "$TEST_HOME/d2/extra"
  run _doutor "doctor_comparar dir '$TEST_HOME/d1' '$TEST_HOME/d2'"
  [ "$output" = "diferente" ]
}

# ─── Contagem e codigo de saida ────────────────────────────────────────────

@test "erro conta como erro, aviso conta como aviso" {
  run _doutor '
    doctor_reiniciar
    doctor_registrar ok    S r v
    doctor_registrar aviso S r v
    doctor_registrar aviso S r v
    doctor_registrar erro  S r v
    echo "$DOCTOR_ERROS $DOCTOR_AVISOS ${#DOCTOR_RESULTADOS[@]}"
  '
  [ "$output" = "1 2 4" ]
}

@test "dependencia obrigatoria ausente vira erro" {
  run _doutor "$(sem_comandos git)
    doctor_reiniciar; doctor_checar_dependencias; echo \"ERROS=\$DOCTOR_ERROS\""
  [[ "$output" == *"ERROS=1"* ]] || { echo "$output" >&2; return 1; }
}

@test "dependencia opcional ausente vira aviso, nao erro" {
  # Afirmar um numero total de avisos prenderia o teste ao ambiente: o PATH
  # isolado pode nao ter alguma outra opcional. O que se testa aqui e o
  # ESTADO destas duas, e que nenhuma delas produziu erro.
  run _doutor "$(sem_comandos gum chafa)"'
    doctor_reiniciar; doctor_checar_dependencias
    for e in "${DOCTOR_RESULTADOS[@]}"; do
      IFS="|" read -r estado _ rotulo _ _ <<< "$e"
      case "$rotulo" in gum|chafa) echo "$rotulo=$estado" ;; esac
    done
    echo "ERROS=$DOCTOR_ERROS"
  '
  [[ "$output" == *"gum=aviso"* ]]   || { echo "$output" >&2; return 1; }
  [[ "$output" == *"chafa=aviso"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"ERROS=0"* ]]     || { echo "$output" >&2; return 1; }
}

@test "permissao frouxa em ~/.ssh vira erro" {
  mkdir -p "$TEST_HOME/.ssh"
  chmod 755 "$TEST_HOME/.ssh"
  run _doutor 'doctor_reiniciar; doctor_checar_permissoes; echo "ERROS=$DOCTOR_ERROS"'
  [[ "$output" == *"ERROS=1"* ]]
}

@test "chave privada 644 vira erro; 600 nao" {
  mkdir -p "$TEST_HOME/.ssh"; chmod 700 "$TEST_HOME/.ssh"
  echo "chave" > "$TEST_HOME/.ssh/id_ed25519_x"

  chmod 644 "$TEST_HOME/.ssh/id_ed25519_x"
  run _doutor 'doctor_reiniciar; doctor_checar_permissoes; echo "ERROS=$DOCTOR_ERROS"'
  [[ "$output" == *"ERROS=1"* ]]

  chmod 600 "$TEST_HOME/.ssh/id_ed25519_x"
  run _doutor 'doctor_reiniciar; doctor_checar_permissoes; echo "ERROS=$DOCTOR_ERROS"'
  [[ "$output" == *"ERROS=0"* ]]
}

@test "chave publica 644 nao e cobrada" {
  mkdir -p "$TEST_HOME/.ssh"; chmod 700 "$TEST_HOME/.ssh"
  echo "chave" > "$TEST_HOME/.ssh/id_ed25519_x"; chmod 600 "$TEST_HOME/.ssh/id_ed25519_x"
  echo "pub" > "$TEST_HOME/.ssh/id_ed25519_x.pub"; chmod 644 "$TEST_HOME/.ssh/id_ed25519_x.pub"
  run _doutor 'doctor_reiniciar; doctor_checar_permissoes; echo "ERROS=$DOCTOR_ERROS"'
  [[ "$output" == *"ERROS=0"* ]]
}

@test "diretorio que nao existe nao vira reclamacao de PATH" {
  # Cobrar ~/.cargo/bin de quem nunca instalou Rust seria ruido. A checagem
  # de entrada morta e outra coisa e sempre reporta, entao o que se conta
  # aqui e so o que veio de _DOCTOR_DIRS_PATH.
  run _doutor '
    doctor_reiniciar
    _doctor_path_do_login() { printf "%s\n" "/usr/bin:/bin"; }
    doctor_checar_path
    for e in "${DOCTOR_RESULTADOS[@]}"; do
      IFS="|" read -r _ _ rotulo _ _ <<< "$e"
      case "$rotulo" in *cargo*|*mise*|*local/bin*) echo "DIR=$rotulo" ;; esac
    done
    echo FIM
  '
  [[ "$output" != *"DIR="* ]] || { echo "$output" >&2; return 1; }
}

@test "diretorio que existe e esta fora do PATH vira erro" {
  mkdir -p "$TEST_HOME/.cargo/bin"
  run _doutor 'doctor_reiniciar; doctor_checar_path; echo "ERROS=$DOCTOR_ERROS"'
  [[ "$output" == *"ERROS=1"* ]]
}

# ─── A promessa: nao alterar nada ──────────────────────────────────────────

@test "o doctor nao cria, altera nem apaga ARQUIVO nenhum" {
  # A comparacao e de arquivos, nao da arvore inteira: _doctor_path_do_login
  # inicia o shell de login uma vez para ler o PATH real, e o shell cria os
  # proprios diretorios de cache na primeira execucao (~/.cache/fish,
  # ~/.local/share/fish). Sao diretorios vazios, do shell, que ele criaria ao
  # abrir qualquer terminal -- num HOME de verdade ja existem.
  #
  # O que nao pode acontecer e arquivo aparecer ou mudar, e e forte o
  # suficiente: foi assim que se descobriu que `nvim --version` gravava
  # ~/.local/state/nvim/log so por ser invocado.
  mkdir -p "$TEST_HOME/.config/fish" "$TEST_HOME/.ssh"
  chmod 700 "$TEST_HOME/.ssh"
  echo "cfg" > "$TEST_HOME/.config/fish/config.fish"
  echo "zsh" > "$TEST_HOME/.zshrc"

  local antes depois
  antes=$(find "$TEST_HOME" -type f -printf '%p %s %m\n' 2>/dev/null | sort | md5sum)
  _doutor 'run_doctor' >/dev/null 2>&1 || true
  depois=$(find "$TEST_HOME" -type f -printf '%p %s %m\n' 2>/dev/null | sort | md5sum)

  if [ "$antes" != "$depois" ]; then
    echo "arquivo criado ou alterado durante o diagnostico:" >&2
    find "$TEST_HOME" -type f -printf '%p %s %m\n' 2>/dev/null | sort >&2
    return 1
  fi
}

@test "sai 1 quando ha erro e 0 quando ha so aviso" {
  # Erro garantido: diretorio existente fora do PATH.
  mkdir -p "$TEST_HOME/.cargo/bin"
  run _doutor 'run_doctor'
  [ "$status" -eq 1 ]

  # Sem esse diretorio sobram so avisos (configs divergentes), e ai sai 0.
  rm -rf "$TEST_HOME/.cargo"
  run _doutor 'run_doctor'
  [ "$status" -eq 0 ]
}

# ─── Layout ────────────────────────────────────────────────────────────────

@test "o valor comeca na mesma coluna, mesmo com rotulo longo" {
  run _doutor '
    doctor_reiniciar
    doctor_registrar ok S "curto" "v1"
    doctor_registrar ok S "~/.local/share/mise/shims" "v2"
    doctor_registrar ok S "medio aqui" "v3"
    doctor_imprimir
  '
  [ "$status" -eq 0 ]

  local colunas
  colunas=$(echo "$output" | grep -E '^    . ' | python3 -c "
import sys, re
pos = set()
for l in sys.stdin:
    m = re.match(r'^(    . \S+(?: \S+)*?)(\s{2,})(\S.*)\$', l.rstrip('\n'))
    if m: pos.add(len(m.group(1)) + len(m.group(2)))
print(len(pos))
")
  if [ "$colunas" -ne 1 ]; then
    echo "valores comecam em $colunas colunas diferentes:" >&2
    echo "$output" >&2
    return 1
  fi
}

# ─── PATH: qual shell, e qual ambiente ─────────────────────────────────────
#
# Dois erros de medicao, os dois encontrados rodando o doctor na maquina real:
#
#   1. $SHELL viaja com o processo e fica obsoleta. Aqui ela dizia zsh
#      enquanto o login do passwd era fish, e os dois montam PATH de formas
#      diferentes -- o doctor acusava um diretorio ausente que estava la.
#   2. Sem `env -i`, o shell de login parte do PATH de quem chamou, e o
#      diagnostico lista entradas injetadas por quem rodou o script, nao pela
#      maquina.

@test "o shell de login vem do passwd, nao de \$SHELL" {
  # $SHELL apontando para um binario valido mas que nao e o do passwd: o
  # passwd tem que vencer.
  run no_ambiente "
    . lib/core.sh
    . data/config_map.sh
    . lib/doctor.sh
    SHELL=/bin/sh
    _doctor_shell_de_login
  "
  [ "$status" -eq 0 ]
  local do_passwd
  do_passwd=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
  if [ -n "$do_passwd" ] && [ -x "$do_passwd" ]; then
    [ "$output" = "$do_passwd" ] || { echo "devolveu $output, passwd diz $do_passwd" >&2; return 1; }
  fi
}

@test "\$SHELL e o fallback quando o passwd nao resolve" {
  run no_ambiente '
    . lib/core.sh
    . data/config_map.sh
    . lib/doctor.sh
    has_cmd() { [[ "$1" != "getent" ]]; }
    USER="usuario-que-nao-existe-em-lugar-nenhum"
    SHELL=/bin/sh
    _doctor_shell_de_login
  '
  [ "$status" -eq 0 ]
  [ "$output" = "/bin/sh" ]
}

@test "entrada de PATH que aponta para diretorio inexistente vira aviso" {
  run _doutor '
    doctor_reiniciar
    _doctor_path_do_login() { printf "%s\n" "/usr/bin:/caminho/que/nao/existe:/bin"; }
    doctor_checar_path
    for e in "${DOCTOR_RESULTADOS[@]}"; do echo "$e"; done
  '
  [[ "$output" == *"/caminho/que/nao/existe|não existe"* ]] || { echo "$output" >&2; return 1; }
  # Entrada morta e aviso, nao erro: nao quebra nada sozinha.
  [[ "$output" == aviso\|* || "$output" == *$'\n'aviso\|* ]]
}

@test "sem entrada morta, o doctor diz isso explicitamente" {
  run _doutor '
    doctor_reiniciar
    _doctor_path_do_login() { printf "%s\n" "/usr/bin:/bin"; }
    doctor_checar_path
    for e in "${DOCTOR_RESULTADOS[@]}"; do echo "$e"; done
  '
  [[ "$output" == *"entradas mortas|nenhuma"* ]] || { echo "$output" >&2; return 1; }
}

@test "a checagem usa o PATH do login, nao o do processo" {
  # O diretorio existe e esta no PATH do processo, mas nao no do login:
  # quem manda e o do login.
  mkdir -p "$TEST_HOME/.cargo/bin"
  run _doutor "
    doctor_reiniciar
    _doctor_path_do_login() { printf '%s\n' '/usr/bin:/bin'; }
    PATH=\"\$PATH:$TEST_HOME/.cargo/bin\"
    doctor_checar_path
    echo \"ERROS=\$DOCTOR_ERROS\"
  "
  [[ "$output" == *"ERROS=1"* ]] || { echo "$output" >&2; return 1; }
}

# ─── Runtimes: checar resultado, nao mecanismo ─────────────────────────────
#
# A checagem anterior cobrava que ~/.local/share/mise/shims estivesse no PATH.
# Isso reprova metade das instalacoes corretas: `mise activate` poe os
# installs/*/bin no PATH e NAO usa o shims; so `activate --shims` usa. As duas
# formas funcionam. O que importa e se a ferramenta resolve.

@test "runtime cujo binario nao da para determinar e pulado, nao reprovado" {
  run _doutor '
    doctor_reiniciar
    has_cmd() { [[ "$1" == "mise" ]]; }
    mise() { echo "runtime-fantasma  1.0  ~/.config/mise"; }
    _doctor_resolve_no_login() { return 0; }
    doctor_checar_runtimes
    echo "ERROS=$DOCTOR_ERROS"
    for e in "${DOCTOR_RESULTADOS[@]}"; do echo "$e"; done
  '
  [[ "$output" == *"ERROS=0"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"sem binário próprio"* ]] || { echo "$output" >&2; return 1; }
}

@test "runtime que nao resolve no login vira erro" {
  # Binario determinavel (mise which devolve caminho) mas que nao resolve.
  mkdir -p "$TEST_HOME/bin"
  printf '#!/bin/sh\nexit 0\n' > "$TEST_HOME/bin/fakeruntime"
  chmod +x "$TEST_HOME/bin/fakeruntime"
  run _doutor "
    doctor_reiniciar
    has_cmd() { [[ \"\$1\" == \"mise\" ]]; }
    mise() { if [[ \"\$1\" == \"which\" ]]; then echo '$TEST_HOME/bin/fakeruntime'; else echo 'fakeruntime 1.0'; fi; }
    _doctor_resolve_no_login() { return 1; }
    doctor_checar_runtimes
    echo \"ERROS=\$DOCTOR_ERROS\"
  "
  [[ "$output" == *"ERROS=1"* ]] || { echo "$output" >&2; return 1; }
}

@test "runtime que resolve nao vira erro, independente de qual diretorio usa" {
  mkdir -p "$TEST_HOME/bin"
  printf '#!/bin/sh\nexit 0\n' > "$TEST_HOME/bin/fakeruntime"
  chmod +x "$TEST_HOME/bin/fakeruntime"
  run _doutor "
    doctor_reiniciar
    has_cmd() { [[ \"\$1\" == \"mise\" ]]; }
    mise() { if [[ \"\$1\" == \"which\" ]]; then echo '$TEST_HOME/bin/fakeruntime'; else echo 'fakeruntime 1.0'; fi; }
    _doctor_resolve_no_login() { return 0; }
    doctor_checar_runtimes
    echo \"ERROS=\$DOCTOR_ERROS\"
  "
  [[ "$output" == *"ERROS=0"* ]] || { echo "$output" >&2; return 1; }
}

@test "sem runtime instalado, o mise vira aviso e nao erro" {
  run _doutor '
    doctor_reiniciar
    has_cmd() { [[ "$1" == "mise" ]]; }
    mise() { printf ""; }
    doctor_checar_runtimes
    echo "E=$DOCTOR_ERROS A=$DOCTOR_AVISOS"
  '
  [[ "$output" == *"E=0"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"A=1"* ]] || { echo "$output" >&2; return 1; }
}

@test "o shims do mise nao e mais cobrado como diretorio obrigatorio" {
  # Guarda contra a regressao: se alguem devolver o shims para a lista, esta
  # maquina (que usa `mise activate` sem shims) volta a reprovar.
  run _doutor '
    for e in "${_DOCTOR_DIRS_PATH[@]}"; do echo "$e"; done
  '
  [[ "$output" != *"mise/shims"* ]] || { echo "$output" >&2; return 1; }
}

# ─── Backup acumulado ──────────────────────────────────────────────────────
#
# O instalador e o set_theme.sh criam um diretorio de backup por execucao e
# nunca limpam. Aqui se acumularam 21 antes de alguem reparar.
#
# A checagem NAO apaga nada: backup e rede de seguranca e quem decide quando
# ela pode cair e o dono. Ela so diz quanto ha, de quando, e o comando.

@test "sem backup nenhum, diz nenhum" {
  run _doutor 'doctor_reiniciar; doctor_checar_backups
    for e in "${DOCTOR_RESULTADOS[@]}"; do echo "$e"; done'
  [[ "$output" == *"acumulados|nenhum"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == ok\|* ]]
}

@test "poucos backups recentes nao viram aviso" {
  mkdir -p "$TEST_HOME"/.bkp-a "$TEST_HOME"/.bkp-b
  run _doutor 'doctor_reiniciar; doctor_checar_backups; echo "A=$DOCTOR_AVISOS"'
  [[ "$output" == *"A=0"* ]] || { echo "$output" >&2; return 1; }
}

@test "acima do limite vira aviso com a contagem" {
  local i
  for i in 1 2 3 4 5 6 7; do mkdir -p "$TEST_HOME/.bkp-$i"; done
  run _doutor 'doctor_reiniciar; doctor_checar_backups
    echo "A=$DOCTOR_AVISOS"
    for e in "${DOCTOR_RESULTADOS[@]}"; do echo "$e"; done'
  [[ "$output" == *"A=1"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"7 diretório(s)"* ]] || { echo "$output" >&2; return 1; }
}

@test "backup antigo vira aviso mesmo sendo poucos" {
  mkdir -p "$TEST_HOME/.bkp-velho"
  touch -d "60 days ago" "$TEST_HOME/.bkp-velho"
  run _doutor 'doctor_reiniciar; doctor_checar_backups
    echo "A=$DOCTOR_AVISOS"
    for e in "${DOCTOR_RESULTADOS[@]}"; do echo "$e"; done'
  [[ "$output" == *"A=1"* ]] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"mais de 30 dias"* ]] || { echo "$output" >&2; return 1; }
}

@test "o limite e configuravel" {
  local i
  for i in 1 2 3; do mkdir -p "$TEST_HOME/.bkp-$i"; done
  run _doutor 'doctor_reiniciar; DOCTOR_BACKUPS_LIMITE=2; doctor_checar_backups; echo "A=$DOCTOR_AVISOS"'
  [[ "$output" == *"A=1"* ]] || { echo "$output" >&2; return 1; }
}

@test "a checagem de backup nao apaga nada" {
  mkdir -p "$TEST_HOME"/.bkp-um "$TEST_HOME"/.bkp-dois
  echo "conteudo" > "$TEST_HOME/.bkp-um/arquivo"
  local antes
  antes=$(find "$TEST_HOME" -name '.bkp-*' -o -path '*/.bkp-*' | sort | md5sum)
  _doutor 'doctor_reiniciar; doctor_checar_backups' >/dev/null 2>&1
  [ "$(find "$TEST_HOME" -name '.bkp-*' -o -path '*/.bkp-*' | sort | md5sum)" = "$antes" ]
  [ -f "$TEST_HOME/.bkp-um/arquivo" ]
}
