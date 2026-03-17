#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_APPS="$ROOT_DIR/data/apps.sh"
CATALOG_FILE="$ROOT_DIR/lib/install_priority.sh"

if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) é necessário para esta auditoria." >&2
  exit 2
fi

declare -a DATA_ITEMS=()
declare -a CATALOG_ITEMS=()
declare -a MANAGED_NON_CATALOG=(
  # Linux
  ghostty
  kitty
  alacritty
  gnome-terminal
  pgadmin
  mongodb
  # macOS (via Brewfile dinâmico / instaladores dedicados)
  iterm2
  intellij-idea
  pycharm
  webstorm
  phpstorm
  goland
  rubymine
  clion
  rider
  datagrip
  android-studio
  rectangle
  alfred
  bartender
  cleanmymac
  istat-menus
  rclone
  # Windows
  windows-terminal
  # IA tools (instaladores dedicados em lib/tools.sh)
  aider
  claude-code
  codex
  continue
  goose
  serena
  spec-kit
)

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

load_data_items() {
  # shellcheck disable=SC1090
  source "$DATA_APPS"
  local group
  for group in CLI_TOOLS IA_TOOLS SHELLS TERMINALS IDES BROWSERS DEV_TOOLS DATABASE_APPS PRODUCTIVITY_APPS COMMUNICATION_APPS MEDIA_APPS UTILITIES_APPS; do
    local -n ref="$group"
    local item
    for item in "${ref[@]}"; do
      DATA_ITEMS+=("$item")
    done
    unset -n ref
  done
}

load_catalog_items() {
  mapfile -t CATALOG_ITEMS < <(
    rg -No '^\s*APP_SOURCES\[([^\]]+)\]' "$CATALOG_FILE" \
      | sed -E 's/.*\[([^]]+)\].*/\1/' \
      | sort -u
  )
}

print_list() {
  local title="$1"
  shift
  local arr=("$@")
  echo "$title (${#arr[@]}):"
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "  (none)"
    return
  fi
  local item
  for item in "${arr[@]}"; do
    echo "  - $item"
  done
}

main() {
  local strict=0
  [[ "${1:-}" == "--strict" ]] && strict=1

  load_data_items
  load_catalog_items

  mapfile -t DATA_ITEMS < <(printf '%s\n' "${DATA_ITEMS[@]}" | sort -u)

  local app
  local -a AUTOMATED=()
  local -a MANUAL_OR_MISSING=()
  local -a CATALOG_NOT_IN_DATA=()

  for app in "${DATA_ITEMS[@]}"; do
    if contains "$app" "${CATALOG_ITEMS[@]}" || contains "$app" "${MANAGED_NON_CATALOG[@]}"; then
      AUTOMATED+=("$app")
    else
      MANUAL_OR_MISSING+=("$app")
    fi
  done

  for app in "${CATALOG_ITEMS[@]}"; do
    if ! contains "$app" "${DATA_ITEMS[@]}"; then
      CATALOG_NOT_IN_DATA+=("$app")
    fi
  done

  print_list "Automatizados (catálogo + handlers extras)" "${AUTOMATED[@]}"
  echo
  print_list "Selecionáveis sem automação completa (manual/pendente)" "${MANUAL_OR_MISSING[@]}"
  echo
  print_list "No catálogo mas fora de data/apps.sh" "${CATALOG_NOT_IN_DATA[@]}"

  if [[ $strict -eq 1 && ${#MANUAL_OR_MISSING[@]} -gt 0 ]]; then
    echo
    echo "Falha: existem apps selecionáveis sem automação completa." >&2
    exit 1
  fi
}

main "${1:-}"
