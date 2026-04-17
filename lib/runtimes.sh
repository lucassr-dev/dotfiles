#!/usr/bin/env bash

ask_runtimes() {
  local runtime_options=(
    "node      - Node.js LTS (JavaScript/TypeScript runtime)"
    "python    - Python latest (linguagem de propósito geral)"
    "php       - PHP latest (desenvolvimento web)"
    "rust      - Rust stable (sistemas e performance)"
    "go        - Go latest (backend e cloud native)"
    "bun       - Bun latest (runtime JS ultrarrápido)"
    "deno      - Deno latest (runtime JS/TS seguro)"
    "elixir    - Elixir latest (funcional e concorrente)"
    "java      - Java LTS (enterprise e Android)"
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

_mise_install_runtime() {
  local runtime="$1"
  local label="$2"
  local version="$3"

  msg "  📦 ${label} (${version}) via mise..."
  if mise use -g -y "${runtime}@${version}"; then
    INSTALLED_MISC+=("${runtime}: mise ${version}")
  else
    record_failure "optional" "Falha ao instalar ${label} (${version}) via mise"
  fi
}

install_selected_runtimes() {
  [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]] || return 0

  msg ""
  msg "▶ Instalando runtimes selecionados (mise)"

  ensure_mise
  if ! has_cmd mise; then
    record_failure "optional" "mise não disponível; pulando instalação de runtimes" "Instale via instalador: ./install.sh"
    return 0
  fi

  mkdir -p "$HOME/.config/mise" >/dev/null 2>&1 || true

  local RUNTIME_MAP=(
    "node:Node.js:lts"
    "python:Python:latest"
    "go:Go:latest"
    "bun:Bun:latest"
    "deno:Deno:latest"
    "elixir:Elixir:latest"
    "java:Java:lts"
    "ruby:Ruby:latest"
  )

  for runtime in "${SELECTED_RUNTIMES[@]}"; do
    case "$runtime" in
      php)
        msg "  📦 PHP (latest) via mise..."
        case "${TARGET_OS:-}" in
          linux|wsl2) install_php_build_deps_linux ;;
          macos) install_php_build_deps_macos ;;
          windows)
            if install_php_windows; then
              continue
            fi
            ;;
        esac

        if mise use -g -y php@latest; then
          INSTALLED_MISC+=("php: mise latest")
        else
          local php_latest=""
          php_latest="$(mise ls-remote php 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -n1 || true)"
          if [[ -n "$php_latest" ]]; then
            msg "  🔄 Tentando PHP ($php_latest) via mise..."
            if mise use -g -y "php@${php_latest}"; then
              INSTALLED_MISC+=("php: mise ${php_latest}")
            else
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
        if mise use -g -y rust@stable; then
          INSTALLED_MISC+=("rust: mise stable")
        elif mise use -g -y rust@latest; then
          INSTALLED_MISC+=("rust: mise latest")
        else
          record_failure "optional" "Falha ao instalar Rust via mise"
        fi
        ;;
      ruby)
        msg "  📦 Ruby (latest) via mise..."
        case "${TARGET_OS:-}" in
          linux|wsl2) install_ruby_build_deps_linux ;;
          macos) install_ruby_build_deps_macos ;;
          windows)
            # No Windows mise não compila Ruby de forma confiável;
            # usar RubyInstaller nativo (já inclui DevKit/MSYS2)
            if install_ruby_windows; then
              continue
            fi
            ;;
        esac
        if mise use -g -y ruby@latest; then
          INSTALLED_MISC+=("ruby: mise latest")
        else
          record_failure "optional" "Falha ao instalar Ruby (latest) via mise"
        fi
        ;;
      *)
        local matched=0
        for entry in "${RUNTIME_MAP[@]}"; do
          local r="${entry%%:*}"
          local rest="${entry#*:}"
          local l="${rest%%:*}"
          local v="${rest#*:}"
          if [[ "$runtime" == "$r" ]]; then
            _mise_install_runtime "$r" "$l" "$v"
            matched=1
            break
          fi
        done
        [[ $matched -eq 0 ]] && _mise_install_runtime "$runtime" "$runtime" "latest"
        ;;
    esac
  done

  return 0
}
