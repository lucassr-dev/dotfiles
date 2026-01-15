#!/usr/bin/env bash
# Seleção e instalação de runtimes (mise)

ask_runtimes() {
  local runtime_options=(
    "node      - Node.js LTS (JavaScript/TypeScript runtime)"
    "python    - Python 3.12 (linguagem de propósito geral)"
    "php       - PHP latest (desenvolvimento web)"
    "rust      - Rust stable (sistemas e performance)"
    "go        - Go latest (backend e cloud native)"
    "bun       - Bun latest (runtime JS ultrarrápido)"
    "deno      - Deno latest (runtime JS/TS seguro)"
    "elixir    - Elixir latest (funcional e concorrente)"
    "java      - Java latest (enterprise e Android)"
    "ruby      - Ruby latest (Rails e scripts)"
  )

  while true; do
    SELECTED_RUNTIMES=()
    clear_screen
    show_section_header "🧰 RUNTIMES - Gerenciador de Versões (mise)"

    msg "Selecione os runtimes/linguagens que deseja instalar."
    msg "O mise gerencia versões por projeto (similar ao nvm, pyenv, etc.)"
    msg ""

    local selected_desc=()
    select_multiple_items "🧰 Selecione os Runtimes" selected_desc "${runtime_options[@]}"

    for item in "${selected_desc[@]}"; do
      local runtime_name
      runtime_name="$(echo "$item" | awk '{print $1}')"
      SELECTED_RUNTIMES+=("$runtime_name")
    done

    if confirm_selection "🧰 Runtimes" "${SELECTED_RUNTIMES[@]}"; then
      break
    fi
  done
}

install_selected_runtimes() {
  [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] || return 0

  msg ""
  msg "▶ Instalando runtimes selecionados (mise)"

  ensure_mise
  if ! has_cmd mise; then
    record_failure "optional" "mise não disponível; pulando instalação de runtimes"
    return 0
  fi

  mkdir -p "$HOME/.config/mise" >/dev/null 2>&1 || true

  for runtime in "${SELECTED_RUNTIMES[@]}"; do
    case "$runtime" in
      node)
        msg "  📦 Node.js (LTS) via mise..."
        mise use -g -y node@lts >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Node.js (LTS) via mise"
        ;;
      python)
        msg "  📦 Python (3.12) via mise..."
        mise use -g -y python@3.12 >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Python 3.12 via mise"
        ;;
      php)
        msg "  📦 PHP (latest) via mise..."
        case "${TARGET_OS:-}" in
          linux|wsl2)
            install_php_build_deps_linux
            ;;
          macos)
            install_php_build_deps_macos
            ;;
          windows)
            if install_php_windows; then
              continue
            fi
            ;;
        esac

        if ! mise use -g -y php@latest >/dev/null 2>&1; then
          local php_latest=""
          php_latest="$(mise ls-remote php 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -n1 || true)"
          if [[ -n "$php_latest" ]]; then
            msg "  🔄 Tentando PHP ($php_latest) via mise..."
            if ! mise use -g -y "php@${php_latest}" >/dev/null 2>&1; then
              record_failure "optional" "Falha ao instalar PHP (${php_latest}) via mise"
            fi
          else
            record_failure "optional" "Falha ao instalar PHP via mise (nenhuma versão alternativa encontrada)"
          fi
        fi

        if has_cmd php; then
          install_composer_and_laravel
        fi
        ;;
      rust)
        msg "  📦 Rust (stable) via mise..."
        if ! mise use -g -y rust@stable >/dev/null 2>&1; then
          mise use -g -y rust@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Rust via mise"
        fi
        ;;
      go)
        msg "  📦 Go (latest) via mise..."
        mise use -g -y go@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Go via mise"
        ;;
      bun)
        msg "  📦 Bun (latest) via mise..."
        mise use -g -y bun@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Bun via mise"
        ;;
      deno)
        msg "  📦 Deno (latest) via mise..."
        mise use -g -y deno@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Deno via mise"
        ;;
      elixir)
        msg "  📦 Elixir (latest) via mise..."
        mise use -g -y elixir@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Elixir via mise"
        ;;
      java)
        msg "  📦 Java (latest) via mise..."
        mise use -g -y java@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Java via mise"
        ;;
      ruby)
        msg "  📦 Ruby (latest) via mise..."
        mise use -g -y ruby@latest >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Ruby via mise"
        ;;
    esac
  done

  return 0
}
