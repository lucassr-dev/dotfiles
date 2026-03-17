#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "install_linux_packages retorna erro quando apt falha" {
  run bash -c '
    source "'"$REPO_ROOT"'/lib/os_linux.sh"
    has_cmd() { [[ "$1" == "apt-get" ]]; }
    run_with_sudo() { return 1; }
    record_failure() { :; }
    LINUX_PKG_MANAGER="apt-get"
    LINUX_PKG_UPDATED=1
    INSTALLED_PACKAGES=()
    install_linux_packages optional git
  '
  [ "$status" -eq 1 ]
}

@test "install_linux_packages retorna sucesso quando apt instala" {
  run bash -c '
    source "'"$REPO_ROOT"'/lib/os_linux.sh"
    has_cmd() { [[ "$1" == "apt-get" ]]; }
    run_with_sudo() { return 0; }
    record_failure() { :; }
    LINUX_PKG_MANAGER="apt-get"
    LINUX_PKG_UPDATED=1
    INSTALLED_PACKAGES=()
    install_linux_packages optional git
  '
  [ "$status" -eq 0 ]
}

@test "_install_via_winget nao cai para install quando app ja existe e upgrade falha" {
  local mock_dir="$BATS_TMPDIR/mock-winget-1"
  mkdir -p "$mock_dir"
  cat > "$mock_dir/winget" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_LOG"
case "${MOCK_WINGET_MODE}:${1}" in
  installed-upgrade-fails:list)
    echo "Microsoft.VisualStudioCode"
    exit 0
    ;;
  installed-upgrade-fails:upgrade)
    exit 1
    ;;
  installed-upgrade-fails:install)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$mock_dir/winget"

  local log_file="$BATS_TMPDIR/winget-1.log"
  : > "$log_file"

  run bash -c '
    source "'"$REPO_ROOT"'/lib/install_priority.sh"
    msg() { :; }
    record_failure() { :; }
    has_cmd() { command -v "$1" >/dev/null 2>&1; }
    INSTALLED_MISC=()
    export PATH="'"$mock_dir"':$PATH"
    export MOCK_LOG="'"$log_file"'"
    export MOCK_WINGET_MODE="installed-upgrade-fails"

    _install_via_winget vscode Microsoft.VisualStudioCode optional || exit 10

    if grep -Eq "^install " "$MOCK_LOG"; then
      exit 11
    fi
  '
  [ "$status" -eq 0 ]
}

@test "_install_via_winget instala quando app nao existe" {
  local mock_dir="$BATS_TMPDIR/mock-winget-2"
  mkdir -p "$mock_dir"
  cat > "$mock_dir/winget" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_LOG"
case "${MOCK_WINGET_MODE}:${1}" in
  not-installed-install-ok:list)
    exit 1
    ;;
  not-installed-install-ok:install)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$mock_dir/winget"

  local log_file="$BATS_TMPDIR/winget-2.log"
  : > "$log_file"

  run bash -c '
    source "'"$REPO_ROOT"'/lib/install_priority.sh"
    msg() { :; }
    record_failure() { :; }
    has_cmd() { command -v "$1" >/dev/null 2>&1; }
    INSTALLED_MISC=()
    export PATH="'"$mock_dir"':$PATH"
    export MOCK_LOG="'"$log_file"'"
    export MOCK_WINGET_MODE="not-installed-install-ok"

    _install_via_winget vscode Microsoft.VisualStudioCode optional || exit 20

    grep -Eq "^install " "$MOCK_LOG" || exit 21
  '
  [ "$status" -eq 0 ]
}

@test "install_with_priority nao tenta proxima fonte quando app ficou instalado apos tentativa anterior" {
  run bash -c '
    source "'"$REPO_ROOT"'/lib/install_priority.sh"

    msg() { :; }
    warn() { :; }
    record_failure() { :; }

    declare -A APP_SOURCES
    APP_SOURCES[testapp]="winget:Pkg.Test,choco:testapp"
    _CATALOG_LOADED=1
    TARGET_OS="windows"
    INSTALL_PRIORITY_WINDOWS="winget,choco"

    state_installed=0
    called_choco=0

    is_app_installed() {
      [[ "$state_installed" -eq 1 ]]
    }
    _install_via_winget() {
      state_installed=1
      return 1
    }
    _install_via_choco() {
      called_choco=1
      return 0
    }

    install_with_priority testapp testapp optional || exit 30
    [[ "$called_choco" -eq 0 ]] || exit 31
  '
  [ "$status" -eq 0 ]
}
