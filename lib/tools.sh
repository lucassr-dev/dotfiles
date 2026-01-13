#!/usr/bin/env bash
# Instalação de CLI Tools e IA Tools selecionadas
# shellcheck disable=SC2034,SC2329,SC1091

cli_tool_installed() {
  local tool="$1"
  case "$tool" in
    bat) has_cmd bat || has_cmd batcat ;;
    fd) has_cmd fd || has_cmd fdfind ;;
    eza) has_cmd eza || has_cmd exa ;;
    ripgrep) has_cmd rg ;;
    delta) has_cmd delta ;;
    *) has_cmd "$tool" ;;
  esac
}

install_selected_cli_tools() {
  [[ ${#SELECTED_CLI_TOOLS[@]} -eq 0 ]] && return 0
  msg "▶ Instalando CLI Tools selecionadas"

  case "$TARGET_OS" in
    linux|wsl2) install_cli_tools_linux ;;
    macos) install_cli_tools_macos ;;
    windows) install_cli_tools_windows ;;
  esac
}

install_cli_tools_linux() {
  detect_linux_pkg_manager

  local tool pkg
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      atuin)
        ensure_atuin
        continue
        ;;
      lazygit|btop|gh)
        # Instalados via PPA, snap ou método especial no segundo loop
        continue
        ;;
      starship)
        # starship também pode ser instalado via tema; aqui só respeita a seleção
        ;;
    esac

    if cli_tool_installed "$tool"; then
      continue
    fi

    pkg="$tool"
    case "$LINUX_PKG_MANAGER" in
      apt-get)
        case "$tool" in
          fd) pkg="fd-find" ;;
          delta) pkg="git-delta" ;;
        esac
        ;;
      pacman)
        case "$tool" in
          gh) pkg="github-cli" ;;
          delta) pkg="git-delta" ;;
        esac
        ;;
      dnf|zypper)
        case "$tool" in
          delta) pkg="git-delta" ;;
        esac
        ;;
    esac

    install_linux_packages optional "$pkg" 2>/dev/null
  done

  # Fallback via cargo para ferramentas selecionadas sem pacote
  local need_cargo=0
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      eza|zoxide|bat|delta|starship|ripgrep|fd)
        if ! cli_tool_installed "$tool"; then
          need_cargo=1
        fi
        ;;
    esac
  done

  if [[ $need_cargo -eq 1 ]]; then
    ensure_rust_cargo
    if has_cmd cargo; then
      for tool in "${SELECTED_CLI_TOOLS[@]}"; do
        case "$tool" in
          eza)
            if ! cli_tool_installed "$tool"; then
              msg "  🦀 Instalando eza via cargo..."
              cargo install eza >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: eza")
            fi
            ;;
          zoxide)
            if ! cli_tool_installed "$tool"; then
              msg "  🦀 Instalando zoxide via cargo..."
              cargo install zoxide >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: zoxide")
            fi
            ;;
          bat)
            if ! cli_tool_installed "$tool"; then
              msg "  🦀 Instalando bat via cargo..."
              cargo install bat >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: bat")
            fi
            ;;
          ripgrep)
            if ! cli_tool_installed "rg"; then
              msg "  🦀 Instalando ripgrep via cargo..."
              cargo install ripgrep >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: ripgrep")
            fi
            ;;
          fd)
            if ! cli_tool_installed "$tool"; then
              msg "  🦀 Instalando fd via cargo..."
              cargo install fd-find >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: fd-find")
            fi
            ;;
          delta)
            if ! cli_tool_installed "$tool"; then
              msg "  🦀 Instalando git-delta via cargo..."
              cargo install git-delta >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: git-delta")
            fi
            ;;
          starship)
            if ! cli_tool_installed "$tool"; then
              msg "  🦀 Instalando starship via cargo..."
              cargo install starship >/dev/null 2>&1 && INSTALLED_MISC+=("cargo: starship")
            fi
            ;;
        esac
      done
    fi
  fi

  # Ferramentas específicas com instalação manual
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      gh)
        if ! cli_tool_installed "$tool"; then
          msg "  📦 Instalando GitHub CLI (gh)..."
          if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg 2>/dev/null | run_with_sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
            run_with_sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | run_with_sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            run_with_sudo apt-get update -qq >/dev/null 2>&1
            run_with_sudo apt-get install -qq -y gh >/dev/null 2>&1 && INSTALLED_MISC+=("gh")
          fi
        fi
        ;;
      lazygit)
        if ! cli_tool_installed "$tool"; then
          if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]] && has_cmd add-apt-repository; then
            msg "  📦 Instalando lazygit via PPA..."
            run_with_sudo add-apt-repository -y ppa:lazygit-team/release >/dev/null 2>&1
            run_with_sudo apt-get update -qq >/dev/null 2>&1
            run_with_sudo apt-get install -qq -y lazygit >/dev/null 2>&1 && INSTALLED_MISC+=("apt: lazygit")
          elif has_cmd snap; then
            msg "  📦 Instalando lazygit via snap..."
            run_with_sudo snap install lazygit >/dev/null 2>&1 && INSTALLED_MISC+=("snap: lazygit")
          fi
        fi
        ;;
      btop)
        if ! cli_tool_installed "$tool"; then
          msg "  📦 Instalando btop via snap..."
          if has_cmd snap; then
            run_with_sudo snap install btop >/dev/null 2>&1 && INSTALLED_MISC+=("snap: btop")
          fi
        fi
        ;;
    esac
  done
}

install_cli_tools_macos() {
  if ! has_cmd brew; then
    warn "Homebrew não encontrado; CLI Tools não podem ser instaladas automaticamente."
    return 0
  fi

  local tool
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      delta) brew_install_formula git-delta optional ;;
      *) brew_install_formula "$tool" optional ;;
    esac
  done
}

install_cli_tools_windows() {
  if ! has_cmd winget; then
    warn "winget não disponível; algumas CLI Tools podem exigir instalação manual."
    return 0
  fi

  local tool
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      fzf) winget_install "junegunn.fzf" "fzf" optional ;;
      zoxide) winget_install "ajeetdsouza.zoxide" "zoxide" optional ;;
      eza) winget_install "eza-community.eza" "eza" optional ;;
      bat) winget_install "sharkdp.bat" "bat" optional ;;
      ripgrep) winget_install "BurntSushi.ripgrep" "ripgrep" optional ;;
      fd) winget_install "sharkdp.fd" "fd" optional ;;
      delta) winget_install "dandavison.delta" "delta" optional ;;
      lazygit) winget_install "jesseduffield.lazygit" "lazygit" optional ;;
      gh) winget_install "GitHub.cli" "GitHub CLI" optional ;;
      jq) winget_install "jqlang.jq" "jq" optional ;;
      direnv) winget_install "direnv.direnv" "direnv" optional ;;
      btop) warn "btop não disponível via winget; instale manualmente." ;;
      tmux) warn "tmux não é suportado nativamente no Windows; use WSL." ;;
      starship) winget_install "Starship.Starship" "Starship" optional ;;
      atuin) warn "Atuin não disponível via winget; instale manualmente em https://atuin.sh" ;;
    esac
  done
}

install_selected_ia_tools() {
  [[ ${#SELECTED_IA_TOOLS[@]} -eq 0 ]] && return 0
  msg "▶ Instalando IA Tools selecionadas"
  print_selection_summary "🤖 IA Tools" "${SELECTED_IA_TOOLS[@]}"
  if ! ask_yes_no "Confirmar instalação das IA Tools selecionadas?"; then
    msg "  ⏭️  Pulando instalação das IA Tools"
    return 0
  fi

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
        msg "  ℹ️  Executando comando oficial para disponibilizar o Serena:"
        msg "     uvx --from git+https://github.com/oraios/serena serena start-mcp-server --help"
        if ! uvx --from git+https://github.com/oraios/serena serena start-mcp-server --help >/dev/null 2>&1; then
          record_failure "optional" "Falha ao executar Serena via uvx"
        else
          INSTALLED_MISC+=("serena: uvx (cache)")
        fi
        msg "  💡 Para iniciar o servidor depois:"
        msg "     uvx --from git+https://github.com/oraios/serena serena start-mcp-server"
        ;;
      codex)
        msg "▶ Codex CLI"
        case "$TARGET_OS" in
          macos)
            if has_cmd brew; then
              brew_install_formula codex optional
            elif has_cmd npm; then
              msg "  📦 Instalando Codex via npm..."
              if npm i -g @openai/codex >/dev/null 2>&1; then
                INSTALLED_MISC+=("npm: @openai/codex")
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
              if npm i -g @openai/codex >/dev/null 2>&1; then
                INSTALLED_MISC+=("npm: @openai/codex")
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
            if curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; then
              INSTALLED_MISC+=("claude-code: install.sh")
            else
              record_failure "optional" "Falha ao instalar Claude Code via script"
            fi
            ;;
          windows)
            if has_cmd powershell; then
              msg "  📦 Instalando Claude Code via PowerShell..."
              if powershell -NoProfile -Command "irm https://claude.ai/install.ps1 | iex" >/dev/null 2>&1; then
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
    esac
  done
}
