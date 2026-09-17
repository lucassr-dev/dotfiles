#!/usr/bin/env bats
#
# Windows (lib/os_windows.sh) e macOS (lib/os_macos.sh) nunca rodam nesta
# maquina: sao quase 1.000 linhas sem teste. A tecnica e binario-isca no PATH
# -- um "winget"/"choco"/"scoop"/"brew" que so registra os argumentos
# recebidos num log e sai com o codigo que o teste pedir. Isso deixa rodar o
# caminho de instalacao inteiro no Linux e travar o COMANDO EXATO: o ID do
# pacote batendo com o catalogo, as flags que evitam travar esperando input
# num runner sem tty, e a falha sendo tratada como falha.
#
# Todo teste isola HOME e os quatro XDG_* num mktemp -d -- sobrescrever so
# HOME nao basta (achado desta sessao). Nenhum teste aqui instala nada de
# verdade nem toca em ~ real.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  TEST_HOME="$(mktemp -d)"
  TEST_XDG_CONFIG="$TEST_HOME/.config"
  TEST_XDG_DATA="$TEST_HOME/.local/share"
  TEST_XDG_CACHE="$TEST_HOME/.cache"
  TEST_XDG_STATE="$TEST_HOME/.local/state"
  mkdir -p "$TEST_XDG_CONFIG" "$TEST_XDG_DATA" "$TEST_XDG_CACHE" "$TEST_XDG_STATE"

  FAKE_BIN="$(mktemp -d)"
  MOCK_LOG="$(mktemp -u)"
  : > "$MOCK_LOG"
}

teardown() {
  rm -rf "$TEST_HOME" "$FAKE_BIN"
  rm -f "$MOCK_LOG"
}

# Instala um binario-isca generico: registra "$0 $*" no MOCK_LOG (uma linha
# por chamada) e sai com $FAKE_EXIT (default 0). "list"/"status" de qualquer
# gerenciador nao imprime nada em stdout, entao o codigo sob teste sempre ve
# "pacote nao instalado" e segue para o comando de instalacao real -- e esse
# comando que os testes travam.
_fake_bin() {
  local name="$1"
  cat > "$FAKE_BIN/$name" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
exit "\${FAKE_EXIT:-0}"
SCRIPT
  chmod +x "$FAKE_BIN/$name"
}

_run_env() {
  run env \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_XDG_CONFIG" \
    XDG_DATA_HOME="$TEST_XDG_DATA" \
    XDG_CACHE_HOME="$TEST_XDG_CACHE" \
    XDG_STATE_HOME="$TEST_XDG_STATE" \
    PATH="$FAKE_BIN:$PATH" \
    MOCK_LOG="$MOCK_LOG" \
    bash -c "$1"
}

# ═══════════════════════════════════════════════════════════
# winget_install (lib/os_windows.sh)
# ═══════════════════════════════════════════════════════════

@test "winget_install: pacote nao instalado usa o ID exato e as duas flags obrigatorias" {
  _fake_bin winget

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    winget_install "Microsoft.VisualStudioCode" "VS Code" critical
    printf "%s\n" "${INSTALLED_MISC[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"winget: VS Code"* ]]

  # comando de install tem que ter o ID literal do chamador (o que o
  # catalogo/caller pede) e as duas flags que evitam travar num runner sem tty
  run grep -F 'install --id Microsoft.VisualStudioCode' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  run grep -F -- '--accept-source-agreements' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  run grep -F -- '--accept-package-agreements' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "winget_install: pacote ja instalado atualiza (upgrade) com o mesmo ID exato" {
  cat > "$FAKE_BIN/winget" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
if [[ "\$1" == "list" ]]; then
  echo "Microsoft.VisualStudioCode"
  exit 0
fi
exit "\${FAKE_EXIT:-0}"
SCRIPT
  chmod +x "$FAKE_BIN/winget"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    winget_install "Microsoft.VisualStudioCode" "VS Code" critical
    printf "%s\n" "${INSTALLED_MISC[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"winget: VS Code (upgrade)"* ]]

  run grep -F 'upgrade --id Microsoft.VisualStudioCode' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  run grep -Eq 'upgrade.*--accept-source-agreements.*--accept-package-agreements' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "winget_install: falha do winget e tratada (record_failure) e nao vira sucesso" {
  cat > "$FAKE_BIN/winget" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
exit 1
SCRIPT
  chmod +x "$FAKE_BIN/winget"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    winget_install "Microsoft.VisualStudioCode" "VS Code" optional
    ret=$?
    printf "RET=%s\n" "$ret"
    printf "MISC=%s\n" "${INSTALLED_MISC[@]:-<vazio>}"
    printf "ERR=%s\n" "${OPTIONAL_ERRORS[@]:-<vazio>}"
  '
  [[ "$output" == *"RET=1"* ]]
  [[ "$output" == *"MISC=<vazio>"* ]]
  [[ "$output" == *"ERR="*"VS Code"* ]]
}

# ═══════════════════════════════════════════════════════════
# _choco_install_or_upgrade / _scoop_install_or_update (lib/os_windows.sh)
# ═══════════════════════════════════════════════════════════

@test "_choco_install_or_upgrade: pacote nao instalado chama choco install com o pacote exato e -y" {
  _fake_bin choco

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    _choco_install_or_upgrade "lazygit"
  '
  [ "$status" -eq 0 ]
  run grep -F 'install lazygit -y' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "_scoop_install_or_update: pacote nao instalado chama scoop install com o pacote exato" {
  _fake_bin scoop

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    _scoop_install_or_update "lazygit"
  '
  [ "$status" -eq 0 ]
  run grep -F 'install lazygit' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════
# _windows_install_fallback_pkg (lib/os_windows.sh)
# ═══════════════════════════════════════════════════════════

@test "_windows_install_fallback_pkg: sucesso via choco registra INSTALLED_MISC com o pacote exato" {
  cat > "$FAKE_BIN/choco" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
if [[ "\$1" == "list" ]]; then
  exit 1
fi
if [[ "\$1" == "install" ]]; then
  cat > "$FAKE_BIN/faketool_xyz" <<'STUB'
#!/bin/sh
exit 0
STUB
  chmod +x "$FAKE_BIN/faketool_xyz"
fi
exit 0
SCRIPT
  chmod +x "$FAKE_BIN/choco"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    _windows_install_fallback_pkg "FakeTool" faketool_xyz faketool_xyz "" optional
    ret=$?
    printf "RET=%s\n" "$ret"
    printf "MISC=%s\n" "${INSTALLED_MISC[@]:-<vazio>}"
  '
  [[ "$output" == *"RET=0"* ]]
  [[ "$output" == *"MISC=choco: FakeTool"* ]]
  run grep -F 'install faketool_xyz -y' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "_windows_install_fallback_pkg: falha em choco e scoop registra failure e retorna erro" {
  _fake_bin choco
  cat > "$FAKE_BIN/choco" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
exit 1
SCRIPT
  chmod +x "$FAKE_BIN/choco"
  cat > "$FAKE_BIN/scoop" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
exit 1
SCRIPT
  chmod +x "$FAKE_BIN/scoop"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    _windows_install_fallback_pkg "FakeTool" faketool_never faketool_never faketool_never optional
    ret=$?
    printf "RET=%s\n" "$ret"
    printf "MISC=%s\n" "${INSTALLED_MISC[@]:-<vazio>}"
    printf "ERR=%s\n" "${OPTIONAL_ERRORS[@]:-<vazio>}"
  '
  [[ "$output" == *"RET=1"* ]]
  [[ "$output" == *"MISC=<vazio>"* ]]
  [[ "$output" == *"ERR="*"Falha ao instalar FakeTool via choco/scoop"* ]]
}

# ═══════════════════════════════════════════════════════════
# _install_windows_app (lib/os_windows.sh) -- delega para
# install_with_priority (lib/install_priority.sh) quando o app esta no
# catalogo, entao cobre tambem o resolvedor de prioridade no caminho Windows.
# ═══════════════════════════════════════════════════════════

@test "_install_windows_app: app no catalogo usa o ID winget exato do catalogo (via install_with_priority)" {
  _fake_bin winget

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/install_priority.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    declare -A APPS_PROCESSED
    is_app_processed() { [[ "${APPS_PROCESSED[$1]:-0}" == "1" ]]; }
    mark_app_processed() { APPS_PROCESSED["$1"]=1; }
    is_app_installed() { return 1; }
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()
    TARGET_OS="windows"
    INSTALL_PRIORITY_WINDOWS="winget"
    # No fluxo real, o catalogo ja foi carregado pelo is_app_installed() de
    # install.sh chamado durante os menus de selecao (lazy-load por efeito
    # colateral); aqui replicamos isso explicitamente.
    _ensure_catalog_loaded

    _install_windows_app lazygit lazygit
  '
  [ "$status" -eq 0 ]
  # lib/install_priority.sh: APP_SOURCES[lazygit] contem winget:jesseduffield.lazygit
  # -- tem que estar especificamente no comando de "install" (a linha de
  # "list" tambem leva o ID e nao provaria nada sobre o comando que instala).
  run grep -F 'install --id jesseduffield.lazygit' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "_install_windows_app: app fora do catalogo usa o winget_id de fallback exato" {
  _fake_bin winget

  # android-studio nao tem entrada em APP_SOURCES (lib/install_priority.sh) --
  # confirmado por leitura do catalogo nesta sessao.
  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/install_priority.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    declare -A APPS_PROCESSED
    is_app_processed() { [[ "${APPS_PROCESSED[$1]:-0}" == "1" ]]; }
    mark_app_processed() { APPS_PROCESSED["$1"]=1; }
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()
    TARGET_OS="windows"

    [[ -z "${APP_SOURCES[android-studio]:-}" ]] || { echo "android-studio ENTROU no catalogo -- ajuste este teste"; exit 99; }

    _install_windows_app android-studio studio "Google.AndroidStudio" "Android Studio"
  '
  [ "$status" -eq 0 ]
  run grep -F 'install --id Google.AndroidStudio' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════
# Catalogo inteiro: todo APP_SOURCES com fonte winget:/choco:/scoop: tem que
# resultar no ID literal declarado sendo passado ao binario real. Este e o
# teste que teria pego um ID inventado (winget nao existe) entrando no
# catalogo -- ele nao valida que o pacote existe de verdade no repositorio da
# fonte, so que o codigo nao troca/perde/reescreve o ID entre o catalogo e a
# chamada real.
# ═══════════════════════════════════════════════════════════

@test "catalogo: cada entrada winget:/choco:/scoop: de APP_SOURCES chega intacta no comando real" {
  _fake_bin winget
  _fake_bin choco
  _fake_bin scoop

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/install_priority.sh"
    msg() { :; }
    warn() { :; }
    record_failure() { :; }
    is_app_installed() { return 1; }
    TARGET_OS="windows"
    INSTALLED_MISC=()
    _ensure_catalog_loaded

    fail=0
    checked=0
    for app in "${!APP_SOURCES[@]}"; do
      IFS="," read -ra entries <<< "${APP_SOURCES[$app]}"
      for entry in "${entries[@]}"; do
        method="${entry%%:*}"
        pkg="${entry#*:}"
        case "$method" in
          winget) INSTALL_PRIORITY_WINDOWS="winget" ;;
          choco)  INSTALL_PRIORITY_WINDOWS="choco" ;;
          scoop)  INSTALL_PRIORITY_WINDOWS="scoop" ;;
          *) continue ;;
        esac
        checked=$((checked + 1))
        : > "$MOCK_LOG"
        install_with_priority "$app" "$app" optional >/dev/null 2>&1
        # A linha de "list"/"status" tambem leva o pkg (e usada so pra
        # detectar se ja esta instalado) -- checar o log inteiro provaria so
        # que o ID aparece em ALGUM lugar, nao que o comando que INSTALA usa
        # o ID certo. Isola so a linha de install/upgrade real.
        action_line="$(grep -E " (install|upgrade) " "$MOCK_LOG" || true)"
        if [[ -z "$action_line" ]]; then
          echo "SEM-ACAO app=$app method=$method pkg=[$pkg] logged=[$(cat "$MOCK_LOG")]"
          fail=1
        elif [[ " $action_line " != *" $pkg "* ]]; then
          echo "MISMATCH app=$app method=$method pkg=[$pkg] action_line=[$action_line]"
          fail=1
        fi
      done
    done
    echo "CHECKED=$checked"
    exit "$fail"
  '
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHECKED="* ]]
  [[ "$output" != *"CHECKED=0"* ]]
}

# ═══════════════════════════════════════════════════════════
# brew_install_batch (lib/os_macos.sh, ~linha 41) -- assercao 5 do brief:
# todas as formulas selecionadas tem que aparecer numa unica invocacao.
# ═══════════════════════════════════════════════════════════

@test "brew_install_batch: formulas nao instaladas vao todas numa unica chamada de brew install" {
  cat > "$FAKE_BIN/brew" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
if [[ "\$1" == "list" ]]; then
  exit 1
fi
exit 0
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    brew_install_batch critical git curl wget imagemagick
    printf "MISC_COUNT=%s\n" "${#INSTALLED_MISC[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"MISC_COUNT=4"* ]]

  # exatamente uma linha de "install" no log, com as quatro formulas juntas
  run grep -c '/brew install ' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -F 'install git curl wget imagemagick' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "brew_install_batch: se o install em lote falha, cai para brew_install_formula individual (uma chamada por formula)" {
  cat > "$FAKE_BIN/brew" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
if [[ "\$1" == "list" ]]; then
  exit 1
fi
if [[ "\$1" == "install" ]]; then
  shift
  if [[ "\$#" -gt 1 ]]; then
    exit 1
  fi
  exit 0
fi
exit 0
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    brew_install_batch optional fzf gum
    printf "MISC_COUNT=%s\n" "${#INSTALLED_MISC[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"MISC_COUNT=2"* ]]

  # o lote falhou (1 chamada com as 2 formulas juntas); o fallback tem que
  # ser individual: mais duas chamadas de install, uma formula por vez --
  # total 3 linhas de install (1 lote que falhou + 2 individuais que deram certo)
  run grep -c '/brew install ' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
  run grep -Fx -- "$FAKE_BIN/brew install fzf" "$MOCK_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx -- "$FAKE_BIN/brew install gum" "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════
# brew_install_formula (lib/os_macos.sh)
# ═══════════════════════════════════════════════════════════

@test "brew_install_formula: formula nao instalada chama brew install com o nome exato" {
  cat > "$FAKE_BIN/brew" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
if [[ "\$1" == "list" ]]; then
  exit 1
fi
exit 0
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    brew_install_formula "starship" optional
    printf "MISC=%s\n" "${INSTALLED_MISC[@]:-<vazio>}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"MISC=brew formula: starship"* ]]
  run grep -Fx -- "$FAKE_BIN/brew install starship" "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "brew_install_formula: falha do brew install e tratada e nao vira sucesso" {
  cat > "$FAKE_BIN/brew" <<SCRIPT
#!/usr/bin/env bash
echo "\$0 \$*" >> "$MOCK_LOG"
exit 1
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()

    brew_install_formula "starship" optional
    ret=$?
    printf "RET=%s\n" "$ret"
    printf "MISC=%s\n" "${INSTALLED_MISC[@]:-<vazio>}"
    printf "ERR=%s\n" "${OPTIONAL_ERRORS[@]:-<vazio>}"
  '
  [[ "$output" == *"RET=1"* ]]
  [[ "$output" == *"MISC=<vazio>"* ]]
  [[ "$output" == *"ERR="*"starship"* ]]
}

# ═══════════════════════════════════════════════════════════
# DRY_RUN=1 nao chama nenhum binario -- valido apenas onde o gate de fato
# existe (install.sh:install_prerequisites, extraida via sed do arquivo real
# sem alterar/sourcing o install.sh inteiro, que rodaria main() interativo).
#
# ACHADO desta sessao (documentado tambem em report.md): winget_install,
# _choco_install_or_upgrade, _scoop_install_or_update,
# _windows_install_fallback_pkg, _install_windows_app, brew_install_batch e
# brew_install_formula NAO verificam $DRY_RUN por conta propria -- o gate so
# existe uma camada acima, em install_prerequisites(), e so cobre a etapa de
# dependencias base. O caminho de apps GUI (install_selected_gui_apps ->
# install_windows_selected_apps/install_macos_selected_apps ->
# _install_windows_app/_install_macos_app) chama estas funcoes sem gate
# nenhum. Nao alterado por instrucao explicita do brief (nao mexer na logica
# de instalacao); ver report.md para detalhes.
# ═══════════════════════════════════════════════════════════

@test "DRY_RUN=1: install_prerequisites (Windows) nao chama winget e marca base deps ok" {
  _fake_bin winget

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    eval "$(sed -n "/^install_prerequisites() {/,/^}/p" "'"$REPO_ROOT"'/install.sh")"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()
    TARGET_OS="windows"
    DRY_RUN=1
    INSTALL_BASE_DEPS=1
    BASE_DEPS_INSTALLED=0

    install_prerequisites
    printf "BASE_DEPS_INSTALLED=%s\n" "$BASE_DEPS_INSTALLED"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"BASE_DEPS_INSTALLED=1"* ]]
  [ ! -s "$MOCK_LOG" ]
}

@test "DRY_RUN=1: install_prerequisites (macOS) nao chama brew e marca base deps ok" {
  _fake_bin brew

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    eval "$(sed -n "/^install_prerequisites() {/,/^}/p" "'"$REPO_ROOT"'/install.sh")"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=()
    TARGET_OS="macos"
    DRY_RUN=1
    INSTALL_BASE_DEPS=1
    BASE_DEPS_INSTALLED=0

    install_prerequisites
    printf "BASE_DEPS_INSTALLED=%s\n" "$BASE_DEPS_INSTALLED"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"BASE_DEPS_INSTALLED=1"* ]]
  [ ! -s "$MOCK_LOG" ]
}

@test "DRY_RUN=1 nao chama o gerenciador em nenhuma funcao de app GUI" {
  # Este teste nasceu como skip, documentando o gap: nenhuma das funcoes de
  # instalacao de app GUI em Windows/macOS checava DRY_RUN. O gate so existia
  # uma camada acima, em install_prerequisites, que cobre so as dependencias
  # base — entao um DRY_RUN=1 interativo com apps selecionados instalava de
  # verdade. No Linux nao acontecia, porque tudo passa por run_with_sudo.
  _fake_bin winget
  _fake_bin choco
  _fake_bin scoop
  _fake_bin brew

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=(); INSTALLED_PACKAGES=()
    DRY_RUN=1

    winget_install "Fake.Pacote" "Fake" optional
    _choco_install_or_upgrade fakepkg
    _scoop_install_or_update fakepkg
    brew_install_formula fakeformula optional
    brew_install_batch optional fake1 fake2
  '
  [ ! -s "$MOCK_LOG" ]
}

@test "DRY_RUN=0 chama o gerenciador -- o gate nao matou as funcoes" {
  # Sem este lado, um gate quebrado (que sempre retorna cedo) seria
  # indistinguivel de um gate correto.
  _fake_bin winget
  _fake_bin brew

  _run_env '
    source "'"$REPO_ROOT"'/lib/core.sh"
    source "'"$REPO_ROOT"'/lib/os_windows.sh"
    source "'"$REPO_ROOT"'/lib/os_macos.sh"
    CRITICAL_ERRORS=(); OPTIONAL_ERRORS=(); FAIL_FAST=0
    INSTALLED_MISC=(); INSTALLED_PACKAGES=()
    DRY_RUN=0

    winget_install "Fake.Pacote" "Fake" optional || true
    brew_install_formula fakeformula optional || true
  '
  [ -s "$MOCK_LOG" ]
}
