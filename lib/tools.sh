#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

cargo_smart_install() {
  local crate="$1"
  local display_name="${2:-$crate}"

  if has_cmd cargo-binstall; then
    msg "  📦 Instalando $display_name via binstall (binário)..."
    if cargo binstall -y "$crate"; then
      INSTALLED_MISC+=("binstall: $crate")
      return 0
    fi
  fi

  msg "  🦀 Instalando $display_name via cargo (compilando, pode demorar)..."
  if cargo install "$crate"; then
    INSTALLED_MISC+=("cargo: $crate")
    return 0
  fi

  record_failure "optional" "Falha ao instalar $display_name via cargo"
  return 1
}

ensure_cargo_binstall() {
  has_cmd cargo-binstall && return 0
  has_cmd cargo || return 1

  msg "  📦 Instalando cargo-binstall (acelera instalações futuras)..."
  if download_and_run_script "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh" "cargo-binstall" "bash"; then
    export PATH="$HOME/.cargo/bin:$PATH"
    INSTALLED_MISC+=("cargo-binstall: script")
    return 0
  fi
  record_failure "optional" "Falha ao instalar cargo-binstall"
  return 1
}

cli_tool_installed() {
  local tool="$1"
  case "$tool" in
    bat) has_cmd bat || has_cmd batcat ;;
    fd) has_cmd fd || has_cmd fdfind ;;
    eza) has_cmd eza || has_cmd exa ;;
    ripgrep) has_cmd rg ;;
    delta) has_cmd delta ;;
    tealdeer) has_cmd tldr ;;
    yazi) has_cmd yazi ;;
    dust) has_cmd dust ;;
    *) has_cmd "$tool" ;;
  esac
}

install_selected_cli_tools() {
  [[ ${#SELECTED_CLI_TOOLS[@]} -eq 0 ]] && return 0
  msg "▶ Instalando Ferramentas CLI selecionadas"

  case "$TARGET_OS" in
    linux|wsl2) install_cli_tools_linux ;;
    macos) install_cli_tools_macos ;;
    windows) install_cli_tools_windows ;;
  esac
}

ensure_rust_cargo() {
  if has_cmd cargo; then
    return 0
  fi

  msg "▶ Rust/Cargo não encontrado. Instalando..."

  if download_and_run_script "https://sh.rustup.rs" "Rust" "bash" "" "-y --no-modify-path"; then
    export PATH="$HOME/.cargo/bin:$PATH"
    INSTALLED_MISC+=("rustup: installer script")
    msg "  ✅ Rust/Cargo instalado com sucesso"
    return 0
  else
    record_failure "critical" "Falha ao instalar Rust/Cargo. Algumas ferramentas não estarão disponíveis."
    return 1
  fi
}

install_cli_tools_linux() {
  detect_linux_pkg_manager

  ensure_rust_cargo
  has_cmd cargo && ensure_cargo_binstall

  local apt_batch=()
  local individual_tools=()
  local tool cmd_check

  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    if cli_tool_installed "$tool"; then
      msg "  ✅ $tool já instalado"
      continue
    fi

    if [[ -n "${APP_SOURCES[$tool]:-}" ]]; then
      local best
      best="$(_get_best_install_method "$tool")"
      case "$best" in
        apt:*) apt_batch+=("${best#apt:}") ;;
        *) individual_tools+=("$tool") ;;
      esac
    else
      case "$tool" in
        tmux|jq|direnv) apt_batch+=("$tool") ;;
        *) warn "Ferramenta CLI '$tool' não encontrada no catálogo" ;;
      esac
    fi
  done

  if [[ ${#apt_batch[@]} -gt 0 ]]; then
    msg "  📦 Batch apt: ${#apt_batch[@]} pacotes (${apt_batch[*]})"
    install_linux_packages optional "${apt_batch[@]}"
  fi

  for tool in "${individual_tools[@]}"; do
    case "$tool" in
      ripgrep) cmd_check="rg" ;;
      tealdeer) cmd_check="tldr" ;;
      *) cmd_check="$tool" ;;
    esac
    install_with_priority "$tool" "$cmd_check" optional
  done
}

install_cli_tools_macos() {
  local tool cmd_check
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      ripgrep) cmd_check="rg" ;;
      tealdeer) cmd_check="tldr" ;;
      *) cmd_check="$tool" ;;
    esac

    if cli_tool_installed "$tool"; then
      msg "  ✅ $tool já instalado"
      continue
    fi

    if [[ -n "${APP_SOURCES[$tool]:-}" ]]; then
      install_with_priority "$tool" "$cmd_check" optional
    else
      warn "Ferramenta CLI '$tool' não encontrada no catálogo"
    fi
  done
}

install_cli_tools_windows() {
  local tool cmd_check
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      ripgrep) cmd_check="rg" ;;
      tealdeer) cmd_check="tldr" ;;
      tmux)
        warn "tmux não é suportado nativamente no Windows; use WSL."
        continue
        ;;
      *) cmd_check="$tool" ;;
    esac

    if cli_tool_installed "$tool"; then
      msg "  ✅ $tool já instalado"
      continue
    fi

    if [[ -n "${APP_SOURCES[$tool]:-}" ]]; then
      install_with_priority "$tool" "$cmd_check" optional
    else
      warn "Ferramenta CLI '$tool' não encontrada no catálogo"
    fi
  done
}

install_selected_ia_tools() {
  [[ ${#SELECTED_IA_TOOLS[@]} -eq 0 ]] && return 0
  msg "▶ Instalando Ferramentas IA selecionadas"
  print_selection_summary "🤖 Ferramentas IA" "${SELECTED_IA_TOOLS[@]}"

  local tool
  for tool in "${SELECTED_IA_TOOLS[@]}"; do
    case "$tool" in
      spec-kit)
        ensure_uv
        ensure_spec_kit
        ;;
      serena)
        ensure_uv
        msg "▶ Serena (MCP Server) via uvx"
        msg "  ℹ️  Executando comando oficial para disponibilizar o Serena..."
        if uvx --from git+https://github.com/oraios/serena serena start-mcp-server --help; then
          INSTALLED_MISC+=("serena: uvx (cache)")
          msg "  💡 Para iniciar o servidor depois:"
          msg "     uvx --from git+https://github.com/oraios/serena serena start-mcp-server"
        else
          record_failure "optional" "Falha ao executar Serena via uvx"
        fi
        ;;
      codex)
        msg "▶ Codex CLI"
        case "$TARGET_OS" in
          macos)
            if has_cmd brew; then
              brew_install_formula codex optional
            elif has_cmd npm; then
              msg "  📦 Instalando Codex via npm..."
              if npm i -g @openai/codex; then
                INSTALLED_MISC+=("codex: npm")
              else
                record_failure "optional" "Falha ao instalar Codex via npm"
              fi
            else
              warn "Codex requer Homebrew ou npm. Instale Node.js 18+ para usar npm."
            fi
            ;;
          linux|wsl2|windows)
            if has_cmd npm; then
              msg "  📦 Instalando Codex via npm..."
              if npm i -g @openai/codex; then
                INSTALLED_MISC+=("codex: npm")
              else
                record_failure "optional" "Falha ao instalar Codex via npm"
              fi
            else
              warn "Codex requer npm (Node.js 18+). Instale Node.js para usar npm."
            fi
            ;;
        esac
        ;;
      claude-code)
        msg "▶ Claude Code"
        case "$TARGET_OS" in
          macos|linux|wsl2)
            msg "  📦 Instalando Claude Code via script oficial..."
            if download_and_run_script "https://claude.ai/install.sh" "Claude Code" "bash"; then
              INSTALLED_MISC+=("claude-code: install.sh")
            else
              record_failure "optional" "Falha ao instalar Claude Code via script"
            fi
            ;;
          windows)
            if has_cmd powershell; then
              msg "  📦 Instalando Claude Code via PowerShell..."
              if powershell -NoProfile -Command "irm https://claude.ai/install.ps1 | iex"; then
                INSTALLED_MISC+=("claude-code: install.ps1")
              else
                record_failure "optional" "Falha ao instalar Claude Code via PowerShell"
              fi
            else
              warn "PowerShell não encontrado. Instale Claude Code manualmente."
            fi
            ;;
        esac
        ;;
      aider)
        msg "▶ Aider (AI Pair Programming)"
        ensure_uv
        if has_cmd uv; then
          msg "  📦 Instalando Aider via uv..."
          if uv tool install aider-chat; then
            INSTALLED_MISC+=("aider: uv tool")
          else
            record_failure "optional" "Falha ao instalar Aider via uv"
          fi
        elif has_cmd pipx; then
          msg "  📦 Instalando Aider via pipx..."
          if pipx install aider-chat; then
            INSTALLED_MISC+=("aider: pipx")
          else
            record_failure "optional" "Falha ao instalar Aider via pipx"
          fi
        else
          warn "Aider requer uv ou pipx. Instale Python e uv primeiro."
        fi
        ;;
      continue)
        msg "▶ Continue (Open-source AI Assistant)"
        msg "  ℹ️  Continue é uma extensão de IDE (VS Code/JetBrains)"
        msg "     Instale via marketplace do seu editor:"
        msg "     - VS Code: ext install Continue.continue"
        msg "     - JetBrains: Plugin Marketplace → Continue"
        INSTALLED_MISC+=("continue: IDE extension (manual)")
        ;;
      goose)
        msg "▶ Goose (AI Agent Framework)"
        ensure_uv
        if has_cmd uv; then
          msg "  📦 Instalando Goose via uv..."
          if uv tool install goose-ai; then
            INSTALLED_MISC+=("goose: uv tool")
          else
            record_failure "optional" "Falha ao instalar Goose via uv"
          fi
        elif has_cmd pipx; then
          msg "  📦 Instalando Goose via pipx..."
          if pipx install goose-ai; then
            INSTALLED_MISC+=("goose: pipx")
          else
            record_failure "optional" "Falha ao instalar Goose via pipx"
          fi
        else
          warn "Goose requer uv ou pipx. Instale Python e uv primeiro."
        fi
        ;;
    esac
  done
}
