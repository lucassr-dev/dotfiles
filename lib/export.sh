#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Modo export inteiro: Sistema -> Repositorio. export_configs varre cada
# ferramenta suportada e chama export_file/export_dir (lib/fileops.sh) para
# copiar de volta ao repo, mais export_brewfile no macOS. export_file/
# export_dir carregam a barreira de material secreto (testada por
# tests/test_secret_export.bats): nao redefina nem contorne aqui.
# Movimentacao pura: nenhum corpo de funcao mudou.

# ════════════════════════════════════════════════════════════════
# Brewfile (macOS) - Export/Import
# ════════════════════════════════════════════════════════════════

export_brewfile() {
  if [[ "$TARGET_OS" != "macos" ]] || ! has_cmd brew; then
    return
  fi

  local brewfile="$CONFIG_MACOS/Brewfile"
  msg "  🍺 Exportando Brewfile..."

  mkdir -p "$(dirname "$brewfile")"
  brew bundle dump --describe --force --file="$brewfile" 2>/dev/null || warn "Falha ao exportar Brewfile"
}


# ════════════════════════════════════════════════════════════════
# Export Configs
# ════════════════════════════════════════════════════════════════

export_configs() {
  msg ""
  msg "╔══════════════════════════════════════╗"
  msg "║   Exportando configs do sistema      ║"
  msg "╚══════════════════════════════════════╝"
  msg "Sistema -> Repositório: $SCRIPT_DIR"

  msg "▶ Exportando configs compartilhadas"

  if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    export_file "$HOME/.config/fish/config.fish" "$CONFIG_SHARED/fish/config.fish"
    normalize_crlf_to_lf "$CONFIG_SHARED/fish/config.fish"
  fi

  if [[ -f "$HOME/.zshrc" ]]; then
    export_file "$HOME/.zshrc" "$CONFIG_SHARED/zsh/.zshrc"
    normalize_crlf_to_lf "$CONFIG_SHARED/zsh/.zshrc"
    if [[ -f "$HOME/.p10k.zsh" ]]; then
      export_file "$HOME/.p10k.zsh" "$CONFIG_SHARED/zsh/.p10k.zsh"
      normalize_crlf_to_lf "$CONFIG_SHARED/zsh/.p10k.zsh"
    fi
  fi

  if [[ -f "$HOME/.config/starship.toml" ]]; then
    export_file "$HOME/.config/starship.toml" "$CONFIG_SHARED/starship.toml"
  fi

  local export_git_dir="$CONFIG_SHARED/git"
  local export_ssh_dir="$CONFIG_SHARED/.ssh"
  if [[ -n "$PRIVATE_SHARED" ]]; then
    export_git_dir="$PRIVATE_SHARED/git"
    export_ssh_dir="$PRIVATE_SHARED/.ssh"
  fi

  if [[ -f "$HOME/.gitconfig" ]]; then
    export_file "$HOME/.gitconfig" "$CONFIG_SHARED/git/.gitconfig"
    [[ -f "$HOME/.gitconfig-personal" ]] && export_file "$HOME/.gitconfig-personal" "$export_git_dir/.gitconfig-personal"
    [[ -f "$HOME/.gitconfig-work" ]] && export_file "$HOME/.gitconfig-work" "$export_git_dir/.gitconfig-work"
  fi

  if [[ -d "$HOME/.config/nvim" ]]; then
    export_dir "$HOME/.config/nvim" "$CONFIG_SHARED/nvim"
  fi

  if [[ -f "$HOME/.tmux.conf" ]]; then
    export_file "$HOME/.tmux.conf" "$CONFIG_SHARED/tmux/.tmux.conf"
  fi

  if [[ -d "$HOME/.ssh" ]]; then
    export_dir "$HOME/.ssh" "$export_ssh_dir"
  fi

  export_vscode_settings
  export_vscode_extensions

  msg "▶ Exportando configurações de ferramentas CLI"

  if [[ -f "$HOME/.config/lazygit/config.yml" ]]; then
    export_dir "$HOME/.config/lazygit" "$CONFIG_SHARED/lazygit"
  fi

  if [[ -d "$HOME/.config/yazi" ]]; then
    export_dir "$HOME/.config/yazi" "$CONFIG_SHARED/yazi"
  fi

  if [[ -f "$HOME/.config/btop/btop.conf" ]]; then
    export_dir "$HOME/.config/btop" "$CONFIG_SHARED/btop"
  fi

  if [[ -f "$HOME/.config/bat/config" ]]; then
    mkdir -p "$CONFIG_SHARED/bat"
    export_file "$HOME/.config/bat/config" "$CONFIG_SHARED/bat/config"
  fi

  if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
    export_dir "$HOME/.config/kitty" "$CONFIG_SHARED/kitty"
  fi

  if [[ -f "$HOME/.config/alacritty/alacritty.toml" ]]; then
    export_dir "$HOME/.config/alacritty" "$CONFIG_SHARED/alacritty"
  fi

  if [[ -f "$HOME/.config/wezterm/wezterm.lua" ]]; then
    export_dir "$HOME/.config/wezterm" "$CONFIG_SHARED/wezterm"
  fi

  if [[ -f "$HOME/.ripgreprc" ]]; then
    export_file "$HOME/.ripgreprc" "$CONFIG_SHARED/.ripgreprc"
  fi

  if [[ -f "$HOME/.npmrc" ]]; then
    mkdir -p "$CONFIG_SHARED/npm"
    export_file "$HOME/.npmrc" "$CONFIG_SHARED/npm/.npmrc"
  fi

  if [[ -f "$HOME/.config/pnpm/.pnpmrc" ]]; then
    mkdir -p "$CONFIG_SHARED/pnpm"
    export_file "$HOME/.config/pnpm/.pnpmrc" "$CONFIG_SHARED/pnpm/.pnpmrc"
  fi

  if [[ -f "$HOME/.yarnrc" ]]; then
    mkdir -p "$CONFIG_SHARED/yarn"
    export_file "$HOME/.yarnrc" "$CONFIG_SHARED/yarn/.yarnrc"
  fi

  if [[ -f "$HOME/.config/pip/pip.conf" ]]; then
    mkdir -p "$CONFIG_SHARED/pip"
    export_file "$HOME/.config/pip/pip.conf" "$CONFIG_SHARED/pip/pip.conf"
  fi

  if [[ -f "$HOME/.cargo/config.toml" ]]; then
    mkdir -p "$CONFIG_SHARED/cargo"
    export_file "$HOME/.cargo/config.toml" "$CONFIG_SHARED/cargo/config.toml"
  fi

  if [[ -f "$HOME/.config/zed/settings.json" ]]; then
    mkdir -p "$CONFIG_SHARED/zed"
    export_file "$HOME/.config/zed/settings.json" "$CONFIG_SHARED/zed/settings.json"
  fi

  if [[ -f "$HOME/.config/helix/config.toml" ]]; then
    mkdir -p "$CONFIG_SHARED/helix"
    export_file "$HOME/.config/helix/config.toml" "$CONFIG_SHARED/helix/config.toml"
  fi

  if [[ -f "$HOME/.aider.conf.yml" ]]; then
    mkdir -p "$CONFIG_SHARED/aider"
    export_file "$HOME/.aider.conf.yml" "$CONFIG_SHARED/aider/.aider.conf.yml"
  fi

  if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    mkdir -p "$CONFIG_SHARED/claude"
    export_file "$HOME/.claude/CLAUDE.md" "$CONFIG_SHARED/claude/CLAUDE.md"
    [[ -f "$HOME/.claude/RTK.md" ]] && export_file "$HOME/.claude/RTK.md" "$CONFIG_SHARED/claude/RTK.md"
    if [[ -d "$CONFIG_SHARED/claude/skills" ]]; then
      local _export_skill_dir
      for _export_skill_dir in "$CONFIG_SHARED/claude/skills"/*/; do
        [[ -d "$_export_skill_dir" ]] || continue
        local _skill_name
        _skill_name="$(basename "$_export_skill_dir")"
        [[ -d "$HOME/.claude/skills/$_skill_name" ]] && export_dir "$HOME/.claude/skills/$_skill_name" "$_export_skill_dir"
      done
    fi
    msg "  ℹ️  settings.json do Claude Code não é exportado (secrets/estado por-máquina) — edite settings.fragment.json a mão se mudar plugins/hooks globais."
  fi

  if [[ -f "$HOME/.docker/config.json" ]]; then
    mkdir -p "$CONFIG_SHARED/docker"
    export_file "$HOME/.docker/config.json" "$CONFIG_SHARED/docker/config.json"
  fi

  if [[ -f "$HOME/.config/direnv/direnvrc" ]]; then
    mkdir -p "$CONFIG_SHARED/direnv"
    export_file "$HOME/.config/direnv/direnvrc" "$CONFIG_SHARED/direnv/.direnvrc"
  fi

  export_brewfile

  case "$TARGET_OS" in
    linux)
      msg "▶ Exportando configs Linux"
      if [[ -d "$HOME/.config/ghostty" ]]; then
        export_dir "$HOME/.config/ghostty" "$CONFIG_LINUX/ghostty"
      fi
      ;;
    macos)
      msg "▶ Exportando configs macOS"
      if [[ -d "$HOME/Library/Application Support/com.mitchellh.ghostty" ]]; then
        export_dir "$HOME/Library/Application Support/com.mitchellh.ghostty" "$CONFIG_MACOS/ghostty"
      fi
      ;;
    windows)
      msg "▶ Exportando configs Windows"
      export_windows_configs_back
      ;;
  esac

  msg ""
  msg "✅ Configs exportadas com sucesso para: $SCRIPT_DIR"
  msg "💡 Execute 'git status' para ver as mudanças"
}
