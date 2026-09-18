#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Diagnostico read-only: nao escreve, nao instala, nao corrige.
#
# Uma ressalva honesta: para saber o PATH de verdade ele inicia o shell de
# login uma vez, e o shell roda o proprio startup. Nao ha como medir sem
# isso, e num HOME real o efeito e nulo.
#
# Sai 1 se houver erro, 0 se houver so aviso: erro e o que quebra uma etapa
# da instalacao, aviso e opcional ausente ou config divergente.

DOCTOR_RESULTADOS=()
DOCTOR_ERROS=0
DOCTOR_AVISOS=0

doctor_reiniciar() {
  DOCTOR_RESULTADOS=()
  DOCTOR_ERROS=0
  DOCTOR_AVISOS=0
}

# estado: ok | aviso | erro
doctor_registrar() {
  local estado="$1" secao="$2" rotulo="$3" valor="$4" dica="${5:-}"
  DOCTOR_RESULTADOS+=("${estado}|${secao}|${rotulo}|${valor}|${dica}")
  case "$estado" in
    erro)  DOCTOR_ERROS=$(( DOCTOR_ERROS + 1 )) ;;
    aviso) DOCTOR_AVISOS=$(( DOCTOR_AVISOS + 1 )) ;;
  esac
}

# ─── Ambiente ──────────────────────────────────────────────────────────────

doctor_checar_ambiente() {
  local secao="Ambiente"

  # O macOS ainda entrega bash 3.2 em /bin/bash, sem array associativo.
  local versao_bash="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
  if (( BASH_VERSINFO[0] >= 4 )); then
    doctor_registrar ok "$secao" "bash" "$versao_bash"
  else
    doctor_registrar erro "$secao" "bash" "$versao_bash" \
      "o script precisa de bash 4+ (array associativo); no macOS use o do Homebrew"
  fi

  local os="${TARGET_OS:-}"
  if [[ -z "$os" ]] && declare -F detect_os >/dev/null 2>&1; then
    detect_os >/dev/null 2>&1
    os="${TARGET_OS:-}"
  fi
  if [[ -n "$os" ]]; then
    doctor_registrar ok "$secao" "sistema" "$os${ARCH:+ ($ARCH)}"
  else
    doctor_registrar erro "$secao" "sistema" "nao detectado" \
      "detect_os nao reconheceu esta plataforma"
  fi

  if [[ "$os" == "linux" ]]; then
    local pm="${LINUX_PKG_MANAGER:-}"
    if [[ -z "$pm" ]] && declare -F detect_linux_pkg_manager >/dev/null 2>&1; then
      detect_linux_pkg_manager >/dev/null 2>&1
      pm="${LINUX_PKG_MANAGER:-}"
    fi
    if [[ -n "$pm" ]]; then
      doctor_registrar ok "$secao" "gerenciador" "$pm"
    else
      doctor_registrar erro "$secao" "gerenciador" "nenhum" \
        "sem apt/dnf/pacman/zypper nao ha como instalar pacote de sistema"
    fi
  fi

  local largura
  largura=$(ui_term_cols)
  if (( largura >= 60 )); then
    doctor_registrar ok "$secao" "terminal" "${largura} colunas"
  else
    doctor_registrar aviso "$secao" "terminal" "${largura} colunas" \
      "abaixo de 60 as telas ficam apertadas, mas nao quebram"
  fi
}

# ─── Dependencias ──────────────────────────────────────────────────────────

# nome|o que se perde sem ela
_DOCTOR_DEPS_OBRIGATORIAS=(
  "git|clonar o repo e configurar as contas"
  "curl|baixar instalador, tema e fonte"
  "tar|extrair pacote baixado"
)
_DOCTOR_DEPS_OPCIONAIS=(
  "unzip|extrair as fontes Nerd (vem em .zip)"
  "fzf|menu de selecao com busca; sem ele cai no modo bash"
  "gum|menu de selecao alternativo"
  "rsync|sincronizar diretorio de config de forma incremental"
  "chafa|previa de tema em imagem no terminal"
)

doctor_checar_dependencias() {
  local secao="Dependências" entrada nome porque versao

  for entrada in "${_DOCTOR_DEPS_OBRIGATORIAS[@]}"; do
    nome="${entrada%%|*}"; porque="${entrada#*|}"
    if has_cmd "$nome"; then
      versao=$(_doctor_versao "$nome")
      doctor_registrar ok "$secao" "$nome" "$versao"
    else
      doctor_registrar erro "$secao" "$nome" "ausente" "necessário para $porque"
    fi
  done

  for entrada in "${_DOCTOR_DEPS_OPCIONAIS[@]}"; do
    nome="${entrada%%|*}"; porque="${entrada#*|}"
    if has_cmd "$nome"; then
      versao=$(_doctor_versao "$nome")
      doctor_registrar ok "$secao" "$nome" "$versao"
    else
      doctor_registrar aviso "$secao" "$nome" "ausente" "sem ele nao da para $porque"
    fi
  done
}

# Tolerante: binario que nao entende --version nao derruba o diagnostico.
_doctor_versao() {
  local nome="$1" saida
  # `nvim --version` cria ~/.local/state/nvim/log so por ser invocado, e um
  # diagnostico nao pode deixar rastro.
  saida=$(NVIM_LOG_FILE=/dev/null "$nome" --version 2>/dev/null | head -1) || saida=""
  [[ -z "$saida" ]] && { echo "instalado"; return 0; }
  local numero
  numero=$(printf '%s' "$saida" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  printf '%s\n' "${numero:-instalado}"
}

# ─── Permissoes ────────────────────────────────────────────────────────────

doctor_checar_permissoes() {
  local secao="Permissões"

  # Rotulo de tela, nao caminho: quem age usa $HOME. Absoluto vazaria o nome
  # do usuario numa saida que se cola em chamado.
  # shellcheck disable=SC2088
  local rotulo_ssh="~/.ssh"

  if [[ -d "$HOME/.ssh" ]]; then
    local modo
    modo=$(_doctor_modo "$HOME/.ssh")
    if [[ "$modo" == "700" ]]; then
      doctor_registrar ok "$secao" "$rotulo_ssh" "$modo"
    else
      doctor_registrar erro "$secao" "$rotulo_ssh" "$modo" \
        "o ssh recusa a chave se o diretorio for mais permissivo que 700"
    fi

    local chave nome_chave modo_chave frouxas=0
    for chave in "$HOME"/.ssh/id_*; do
      [[ -f "$chave" ]] || continue
      [[ "$chave" == *.pub ]] && continue
      nome_chave="$(basename "$chave")"
      modo_chave=$(_doctor_modo "$chave")
      if [[ "$modo_chave" != "600" && "$modo_chave" != "400" ]]; then
        doctor_registrar erro "$secao" "$rotulo_ssh/$nome_chave" "$modo_chave" \
          "chave privada precisa ser 600; o ssh ignora a chave e cai para senha"
        frouxas=$(( frouxas + 1 ))
      fi
    done
    (( frouxas == 0 )) && doctor_registrar ok "$secao" "chaves privadas" "600"
  else
    doctor_registrar aviso "$secao" "$rotulo_ssh" "ausente" \
      "nenhuma chave configurada nesta maquina"
  fi

  local checkpoint="$HOME/.dotfiles-checkpoint"
  if [[ -f "$checkpoint" ]]; then
    local modo_cp
    modo_cp=$(_doctor_modo "$checkpoint")
    if [[ "$modo_cp" == "600" ]]; then
      doctor_registrar aviso "$secao" "checkpoint" "existe ($modo_cp)" \
        "ha uma instalacao pela metade; rodar install.sh retoma de onde parou"
    else
      doctor_registrar erro "$secao" "checkpoint" "$modo_cp" \
        "o checkpoint e executado como shell; com permissao frouxa vira vetor"
    fi
  fi
}

_doctor_modo() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%OLp' "$1" 2>/dev/null || echo "?"
}

# ─── PATH ──────────────────────────────────────────────────────────────────

# O PATH que importa e o do SHELL DE LOGIN, nao o do processo que rodou este
# script: `bash install.sh doctor` herda o PATH de quem chamou, que pode nao
# ser o que o dono da maquina tem no terminal. Medir o processo errado da
# tanto falso positivo quanto falso negativo.
# $SHELL nao e confiavel: ela viaja com o processo e pode ficar obsoleta.
# Nesta maquina dizia zsh enquanto o login era fish, e a diferenca importa --
# os dois montam PATH de formas diferentes. O passwd e a fonte autoritativa.
_doctor_shell_de_login() {
  local sh=""
  if has_cmd getent; then
    sh=$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7)
  fi
  if [[ -z "$sh" && -r /etc/passwd ]]; then
    sh=$(grep "^${USER:-$(id -un)}:" /etc/passwd 2>/dev/null | head -1 | cut -d: -f7)
  fi
  if [[ -z "$sh" && "$(uname -s)" == "Darwin" ]] && has_cmd dscl; then
    sh=$(dscl . -read "/Users/${USER:-$(id -un)}" UserShell 2>/dev/null | awk '{print $2}')
  fi
  [[ -x "$sh" ]] || sh="${SHELL:-/bin/bash}"
  [[ -x "$sh" ]] || sh=/bin/bash
  printf '%s\n' "$sh"
}

# `env -i` e o que separa "o PATH que o dono tem" de "o PATH que herdei de
# quem me chamou". Sem ele o shell de login parte do PATH do processo pai e
# o diagnostico acusa entradas que nao sao da maquina.
_doctor_path_do_login() {
  local sh caminho
  sh=$(_doctor_shell_de_login)
  caminho=$(env -i HOME="$HOME" USER="${USER:-$(id -un)}" TERM=dumb SHELL="$sh" \
    "$sh" -l -c 'env' 2>/dev/null | grep '^PATH=' | head -1 | cut -d'=' -f2-)
  # Shell que nao monta PATH proprio a partir do zero devolve quase nada;
  # nesse caso o do processo atual e a melhor aproximacao disponivel.
  if (( $(printf '%s' "$caminho" | tr ':' '\n' | grep -c .) < 3 )); then
    printf '%s\n' "$PATH"
    return 0
  fi
  printf '%s\n' "$caminho"
}

# So reclama de diretorio que EXISTE e esta fora do PATH.
#
# O shims do mise NAO entra nesta lista. Ha dois jeitos validos de o mise
# chegar ao PATH -- `mise activate` poe os installs/*/bin, `activate --shims`
# poe o shims -- e cobrar um diretorio especifico reprova metade das
# instalacoes corretas. O que importa e se a ferramenta resolve, e e isso que
# doctor_checar_runtimes pergunta.
_DOCTOR_DIRS_PATH=(
  "$HOME/.local/bin|instaladores por script (uv, pipx, binario solto)"
  "$HOME/.cargo/bin|binario instalado por cargo install"
)

# Um comando resolve no shell de login? E a unica pergunta que nao depende de
# como o PATH foi montado.
_doctor_resolve_no_login() {
  local cmd="$1" sh
  sh=$(_doctor_shell_de_login)
  env -i HOME="$HOME" USER="${USER:-$(id -un)}" TERM=dumb SHELL="$sh" \
    "$sh" -l -i -c "command -v $cmd" >/dev/null 2>&1
}

# O nome do runtime nem sempre e o nome do comando: "neovim" da `nvim`,
# "java" da `java`/`jar`, "rust" nao instala binario proprio. Quando nao da
# para determinar, esta funcao nao devolve nada e o runtime e PULADO -- e
# melhor nao reportar do que reportar errado.
_doctor_binario_do_runtime() {
  local nome="$1" caminho bindir primeiro
  caminho=$(mise which "$nome" 2>/dev/null)
  if [[ -n "$caminho" && -x "$caminho" ]]; then
    basename "$caminho"
    return 0
  fi
  bindir=$(find "$HOME/.local/share/mise/installs/$nome" -maxdepth 2 -type d -name bin 2>/dev/null | head -1)
  [[ -n "$bindir" ]] || return 1
  if [[ -x "$bindir/$nome" ]]; then
    printf '%s\n' "$nome"
    return 0
  fi
  primeiro=$(find "$bindir" -maxdepth 1 -type f -executable 2>/dev/null | head -1)
  [[ -n "$primeiro" ]] || return 1
  basename "$primeiro"
}

doctor_checar_runtimes() {
  local secao="Runtimes"
  has_cmd mise || return 0

  local instalados
  instalados=$(mise ls --installed 2>/dev/null | awk '{print $1}' | sort -u | grep -vE '^$')
  if [[ -z "$instalados" ]]; then
    doctor_registrar aviso "$secao" "mise" "nenhum runtime" \
      "o mise esta instalado mas nao gerencia nada ainda"
    return 0
  fi

  local nome binario faltam=() total=0 pulados=0
  while IFS= read -r nome; do
    [[ -n "$nome" ]] || continue
    if ! binario=$(_doctor_binario_do_runtime "$nome"); then
      pulados=$(( pulados + 1 ))
      continue
    fi
    total=$(( total + 1 ))
    _doctor_resolve_no_login "$binario" || faltam+=("${nome} (${binario})")
  done <<< "$instalados"

  if (( ${#faltam[@]} == 0 )); then
    local valor="${total} resolvem"
    (( pulados > 0 )) && valor+=", ${pulados} sem binário próprio"
    doctor_registrar ok "$secao" "gerenciados pelo mise" "$valor"
  else
    doctor_registrar erro "$secao" "não resolvem" "${faltam[*]}" \
      "o mise instalou, mas o shell de login nao alcanca; falta ativar o mise no shell"
  fi
}

doctor_checar_path() {
  local secao="PATH" entrada dir porque
  local caminho
  caminho=$(_doctor_path_do_login)
  [[ -n "$caminho" ]] || caminho="$PATH"

  for entrada in "${_DOCTOR_DIRS_PATH[@]}"; do
    dir="${entrada%%|*}"; porque="${entrada#*|}"
    [[ -d "$dir" ]] || continue
    case ":$caminho:" in
      *":$dir:"*) doctor_registrar ok "$secao" "${dir/#$HOME/\~}" "no PATH" ;;
      *) doctor_registrar erro "$secao" "${dir/#$HOME/\~}" "fora do PATH" \
           "o diretorio existe mas nao e consultado: $porque" ;;
    esac
  done

  # Entrada que aponta para diretorio inexistente. Nao quebra nada sozinha,
  # mas quase sempre e rastro de renomeacao de usuario ou de imagem reusada --
  # e, quando o caminho e parecido com um valido, esconde que o valido falta.
  local mortas=0 item
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    [[ -d "$item" ]] && continue
    mortas=$(( mortas + 1 ))
    doctor_registrar aviso "$secao" "${item/#$HOME/\~}" "não existe" \
      "entrada morta no PATH do shell de login"
  done < <(printf '%s' "$caminho" | tr ':' '\n' | sort -u)

  (( mortas == 0 )) && doctor_registrar ok "$secao" "entradas mortas" "nenhuma"
}

# ─── Backup acumulado ──────────────────────────────────────────────────────

# O instalador e o set_theme.sh criam um diretorio de backup por execucao e
# nunca limpam. Cada um sozinho e barato; vinte deles sao lixo que ninguem
# olha, e que some no meio dos arquivos do home.
#
# Nao apaga nada: diz quanto ha, de quando, e o comando. Backup e rede de
# seguranca -- quem decide quando ela pode cair e o dono.
DOCTOR_BACKUPS_LIMITE="${DOCTOR_BACKUPS_LIMITE:-5}"
DOCTOR_BACKUPS_DIAS="${DOCTOR_BACKUPS_DIAS:-30}"

doctor_checar_backups() {
  local secao="Backups" padrao quantos
  local -a achados=()

  for padrao in "$HOME"/.bkp-* ; do
    [[ -d "$padrao" ]] && achados+=("$padrao")
  done

  quantos=${#achados[@]}
  if (( quantos == 0 )); then
    doctor_registrar ok "$secao" "acumulados" "nenhum"
    return 0
  fi

  local tamanho antigos=0 dir
  tamanho=$(du -ch "${achados[@]}" 2>/dev/null | tail -1 | cut -f1)

  for dir in "${achados[@]}"; do
    if [[ -n "$(find "$dir" -maxdepth 0 -mtime "+${DOCTOR_BACKUPS_DIAS}" 2>/dev/null)" ]]; then
      antigos=$(( antigos + 1 ))
    fi
  done

  if (( quantos > DOCTOR_BACKUPS_LIMITE )) || (( antigos > 0 )); then
    local detalhe="${quantos} diretório(s), ${tamanho}"
    (( antigos > 0 )) && detalhe+=", ${antigos} com mais de ${DOCTOR_BACKUPS_DIAS} dias"
    doctor_registrar aviso "$secao" "acumulados" "$detalhe" \
      "revise e apague o que nao precisa mais: ls -dt ~/.bkp-*"
  else
    doctor_registrar ok "$secao" "acumulados" "${quantos} diretório(s), ${tamanho}"
  fi
}

# ─── Divergencia entre repositorio e sistema ───────────────────────────────

# igual | diferente | so_sistema | so_repo | ausente
doctor_comparar() {
  local tipo="$1" sistema="$2" repo="$3"
  local tem_sistema=0 tem_repo=0
  if [[ "$tipo" == "dir" ]]; then
    [[ -d "$sistema" ]] && tem_sistema=1
    [[ -d "$repo" ]] && tem_repo=1
  else
    [[ -f "$sistema" ]] && tem_sistema=1
    [[ -f "$repo" ]] && tem_repo=1
  fi

  if (( tem_sistema == 0 && tem_repo == 0 )); then echo "ausente"; return 0; fi
  if (( tem_sistema == 1 && tem_repo == 0 )); then echo "so_sistema"; return 0; fi
  if (( tem_sistema == 0 && tem_repo == 1 )); then echo "so_repo"; return 0; fi

  if [[ "$tipo" == "dir" ]]; then
    if diff -rq "$repo" "$sistema" >/dev/null 2>&1; then echo "igual"; else echo "diferente"; fi
  else
    if cmp -s "$repo" "$sistema"; then echo "igual"; else echo "diferente"; fi
  fi
}

doctor_checar_divergencia() {
  local secao="Configs" entrada tipo sistema repo rotulo estado
  local iguais=0 diferentes=0

  while IFS= read -r entrada; do
    [[ -n "$entrada" ]] || continue
    IFS='|' read -r tipo sistema repo rotulo _ <<< "$entrada"
    estado=$(doctor_comparar "$tipo" "$sistema" "$repo")
    case "$estado" in
      igual)      iguais=$(( iguais + 1 )) ;;
      diferente)  diferentes=$(( diferentes + 1 ))
                  doctor_registrar aviso "$secao" "$rotulo" "divergente" \
                    "sistema e repo diferem; 'install.sh diff' mostra o que" ;;
      so_sistema) doctor_registrar aviso "$secao" "$rotulo" "só no sistema" \
                    "existe na maquina e nao no repo; 'install.sh export' traz" ;;
      so_repo)    doctor_registrar aviso "$secao" "$rotulo" "só no repo" \
                    "esta versionado mas nao aplicado; 'install.sh' aplica" ;;
    esac
  done < <(config_map_do_os "${TARGET_OS:-linux}"; config_map_skills)

  doctor_registrar ok "$secao" "em dia" "$iguais config(s) idêntica(s)"
}

# ─── Neovim ────────────────────────────────────────────────────────────────

doctor_checar_neovim() {
  local secao="Neovim"
  if ! has_cmd nvim; then
    doctor_registrar aviso "$secao" "nvim" "ausente" "nenhuma config para verificar"
    return 0
  fi
  doctor_registrar ok "$secao" "nvim" "$(_doctor_versao nvim)"

  local verificador="${SCRIPT_DIR:-.}/scripts/verify_nvim.sh"
  if [[ -x "$verificador" || -f "$verificador" ]]; then
    doctor_registrar ok "$secao" "verificação detalhada" \
      "bash scripts/verify_nvim.sh (16 critérios)"
  fi
}

# ─── Saida ─────────────────────────────────────────────────────────────────

_doctor_simbolo() {
  case "$1" in
    ok)    printf '%b' "${UI_GREEN}✓${UI_RESET}" ;;
    aviso) printf '%b' "${UI_YELLOW}!${UI_RESET}" ;;
    erro)  printf '%b' "${UI_RED}✗${UI_RESET}" ;;
  esac
}

doctor_imprimir() {
  local largura rotulo_w
  largura=$(ui_width "$UI_WIDTH_MAX_FULL")

  # Coluna adaptativa: fixa em 22, "~/.local/share/mise/shims" quebrava o
  # alinhamento da secao inteira.
  local entrada rotulo comprimento
  rotulo_w=0
  for entrada in "${DOCTOR_RESULTADOS[@]}"; do
    IFS='|' read -r _ _ rotulo _ _ <<< "$entrada"
    comprimento=$(_visible_len "$rotulo")
    (( comprimento > rotulo_w )) && rotulo_w=$comprimento
  done
  rotulo_w=$(( rotulo_w + 2 ))
  local teto=$(( largura - 34 ))
  (( rotulo_w > teto )) && rotulo_w=$teto
  (( rotulo_w < 12 )) && rotulo_w=12

  local secao_atual="" estado secao valor dica
  for entrada in "${DOCTOR_RESULTADOS[@]}"; do
    IFS='|' read -r estado secao rotulo valor dica <<< "$entrada"

    if [[ "$secao" != "$secao_atual" ]]; then
      secao_atual="$secao"
      msg ""
      msg "  ${UI_MAUVE}${UI_BOLD}▸ ${secao}${UI_RESET}"
    fi

    local pad=$(( rotulo_w - $(_visible_len "$rotulo") ))
    (( pad < 1 )) && pad=1
    msg "$(printf '    %s %s%*s%b%s%b' \
      "$(_doctor_simbolo "$estado")" "$rotulo" "$pad" '' \
      "${UI_TEXT}" "$valor" "${UI_RESET}")"

    if [[ -n "$dica" && "$estado" != "ok" ]]; then
      msg_wrap "${UI_OVERLAY1}${dica}${UI_RESET}" 8
    fi
  done

  msg ""
  local resumo
  if (( DOCTOR_ERROS > 0 )); then
    resumo="${UI_RED}${UI_BOLD}${DOCTOR_ERROS} erro(s)${UI_RESET}"
    (( DOCTOR_AVISOS > 0 )) && resumo+="${UI_TEXT}, ${UI_YELLOW}${DOCTOR_AVISOS} aviso(s)${UI_RESET}"
  elif (( DOCTOR_AVISOS > 0 )); then
    resumo="${UI_YELLOW}${UI_BOLD}${DOCTOR_AVISOS} aviso(s)${UI_RESET}${UI_TEXT}, nenhum erro${UI_RESET}"
  else
    resumo="${UI_GREEN}${UI_BOLD}tudo em ordem${UI_RESET}"
  fi
  msg "  ${resumo}"
  msg ""
}

# ─── Entrada ───────────────────────────────────────────────────────────────

run_doctor() {
  doctor_reiniciar

  clear_screen
  msg ""
  msg "  ${UI_SKY}${UI_BOLD}Diagnóstico${UI_RESET}"
  msg "  ${UI_OVERLAY1}Nada aqui altera o sistema.${UI_RESET}"

  doctor_checar_ambiente
  doctor_checar_dependencias
  doctor_checar_permissoes
  doctor_checar_path
  doctor_checar_runtimes
  doctor_checar_backups
  doctor_checar_divergencia
  doctor_checar_neovim

  doctor_imprimir

  (( DOCTOR_ERROS > 0 )) && return 1
  return 0
}
