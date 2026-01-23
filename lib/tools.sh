#!/usr/bin/env bash
# Instalação de CLI Tools e IA Tools selecionadas
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
  if curl -fsSL https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash; then
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
      lazygit|btop|gh|yazi|tealdeer|procs|dust|sd|tokei|hyperfine)
        continue
        ;;
      starship)
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

    install_linux_packages optional "$pkg"
  done

  local need_cargo=0
  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      eza|zoxide|bat|delta|starship|ripgrep|fd|tealdeer|yazi|procs|dust|sd|tokei|hyperfine)
        if ! cli_tool_installed "$tool"; then
          need_cargo=1
        fi
        ;;
    esac
  done

  if [[ $need_cargo -eq 1 ]]; then
    ensure_rust_cargo
    if has_cmd cargo; then
      ensure_cargo_binstall

      for tool in "${SELECTED_CLI_TOOLS[@]}"; do
        case "$tool" in
          eza)
            cli_tool_installed "$tool" || cargo_smart_install eza "eza"
            ;;
          zoxide)
            cli_tool_installed "$tool" || cargo_smart_install zoxide "zoxide"
            ;;
          bat)
            cli_tool_installed "$tool" || cargo_smart_install bat "bat"
            ;;
          ripgrep)
            cli_tool_installed "rg" || cargo_smart_install ripgrep "ripgrep"
            ;;
          fd)
            cli_tool_installed "$tool" || cargo_smart_install fd-find "fd"
            ;;
          delta)
            cli_tool_installed "$tool" || cargo_smart_install git-delta "git-delta"
            ;;
          starship)
            cli_tool_installed "$tool" || cargo_smart_install starship "starship"
            ;;
          tealdeer)
            cli_tool_installed "$tool" || cargo_smart_install tealdeer "tealdeer"
            ;;
          yazi)
            if ! cli_tool_installed "$tool"; then
              cargo_smart_install yazi-fm "yazi"
              cargo_smart_install yazi-cli "yazi-cli"
            fi
            ;;
          procs)
            cli_tool_installed "$tool" || cargo_smart_install procs "procs"
            ;;
          dust)
            cli_tool_installed "$tool" || cargo_smart_install du-dust "dust"
            ;;
          sd)
            cli_tool_installed "$tool" || cargo_smart_install sd "sd"
            ;;
          tokei)
            cli_tool_installed "$tool" || cargo_smart_install tokei "tokei"
            ;;
          hyperfine)
            cli_tool_installed "$tool" || cargo_smart_install hyperfine "hyperfine"
            ;;
        esac
      done
    fi
  fi

  for tool in "${SELECTED_CLI_TOOLS[@]}"; do
    case "$tool" in
      gh)
        if ! cli_tool_installed "$tool"; then
          msg "  📦 Instalando GitHub CLI (gh)..."
          if [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
            if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | run_with_sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null; then
              run_with_sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | run_with_sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
              if run_with_sudo apt-get update && run_with_sudo apt-get install -y gh; then
                INSTALLED_MISC+=("gh: apt")
              else
                record_failure "optional" "Falha ao instalar gh via apt"
              fi
            else
              record_failure "optional" "Falha ao baixar chave GPG do GitHub CLI"
            fi
          elif [[ "$LINUX_PKG_MANAGER" == "pacman" ]]; then
            install_linux_packages optional github-cli
          elif [[ "$LINUX_PKG_MANAGER" == "dnf" ]]; then
            if run_with_sudo dnf install -y 'dnf-command(config-manager)' && run_with_sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo && run_with_sudo dnf install -y gh; then
              INSTALLED_MISC+=("gh: dnf")
            else
              record_failure "optional" "Falha ao instalar gh via dnf"
            fi
          fi
        fi
        ;;
      lazygit)
        if ! cli_tool_installed "$tool"; then
          msg "  📦 Instalando lazygit via GitHub Releases..."
          local lazygit_version=""
          lazygit_version="$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*' || echo "")"
          if [[ -n "$lazygit_version" ]]; then
            local lazygit_url="https://github.com/jesseduffield/lazygit/releases/download/v${lazygit_version}/lazygit_${lazygit_version}_Linux_x86_64.tar.gz"
            local lazygit_tmp=""
            lazygit_tmp="$(mktemp -d)"
            if curl -fsSL "$lazygit_url" -o "$lazygit_tmp/lazygit.tar.gz"; then
              if tar xf "$lazygit_tmp/lazygit.tar.gz" -C "$lazygit_tmp" lazygit; then
                if [[ -f "$lazygit_tmp/lazygit" ]]; then
                  if run_with_sudo install "$lazygit_tmp/lazygit" -D -t /usr/local/bin/; then
                    INSTALLED_MISC+=("lazygit: v${lazygit_version}")
                  else
                    record_failure "optional" "Falha ao mover lazygit para /usr/local/bin"
                  fi
                fi
              else
                record_failure "optional" "Falha ao extrair lazygit"
              fi
            else
              record_failure "optional" "Falha ao baixar lazygit"
            fi
            rm -rf "$lazygit_tmp" 2>/dev/null || true
          else
            record_failure "optional" "Falha ao obter versão do lazygit do GitHub"
          fi
        fi
        ;;
      btop)
        if ! cli_tool_installed "$tool"; then
          msg "  📦 Instalando btop..."
          if has_cmd snap; then
            if run_with_sudo snap install btop; then
              INSTALLED_MISC+=("btop: snap")
            else
              record_failure "optional" "Falha ao instalar btop via snap"
            fi
          elif [[ "$LINUX_PKG_MANAGER" == "apt-get" ]]; then
            install_linux_packages optional btop
          elif [[ "$LINUX_PKG_MANAGER" == "pacman" ]]; then
            install_linux_packages optional btop
          else
            record_failure "optional" "btop: nenhum método de instalação disponível"
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
      btop) warn "btop não disponível via winget. Use Scoop: scoop install btop-lhm" ;;
      tmux) warn "tmux não é suportado nativamente no Windows; use WSL." ;;
      starship) winget_install "Starship.Starship" "Starship" optional ;;
      atuin) warn "Atuin não disponível via winget; instale manualmente em https://atuin.sh" ;;
      tealdeer) winget_install "dbrgn.tealdeer" "tealdeer" optional ;;
      yazi) winget_install "sxyazi.yazi" "yazi" optional ;;
      procs) winget_install "dalance.procs" "procs" optional ;;
      dust) winget_install "bootandy.dust" "dust" optional ;;
      sd) winget_install "chmln.sd" "sd" optional ;;
      tokei) winget_install "XAMPPRocky.tokei" "tokei" optional ;;
      hyperfine) winget_install "sharkdp.hyperfine" "hyperfine" optional ;;
    esac
  done
}

install_selected_ia_tools() {
  [[ ${#SELECTED_IA_TOOLS[@]} -eq 0 ]] && return 0
  msg "▶ Instalando IA Tools selecionadas"
  print_selection_summary "🤖 IA Tools" "${SELECTED_IA_TOOLS[@]}"

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
            if curl -fsSL https://claude.ai/install.sh | bash; then
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
