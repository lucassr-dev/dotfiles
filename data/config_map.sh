#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Correspondencia sistema <-> repositorio, consumida pelo doctor e pelo diff.
#
# Formato: tipo|sistema|repo|rotulo|os
#   tipo = file ou dir
#   os   = todos, linux ou macos
#
# Montada por funcao, nao por atribuicao no nivel do arquivo: $CONFIG_* so
# existe depois que o install.sh define os diretorios.

config_map_carregar() {
  CONFIG_MAP=(
    "file|$HOME/.config/fish/config.fish|$CONFIG_SHARED/fish/config.fish|Fish|todos"
    "file|$HOME/.zshrc|$CONFIG_SHARED/zsh/.zshrc|Zsh|todos"
    "file|$HOME/.p10k.zsh|$CONFIG_SHARED/zsh/.p10k.zsh|Powerlevel10k|todos"
    "file|$HOME/.config/starship.toml|$CONFIG_SHARED/starship.toml|Starship|todos"
    "file|$HOME/.gitconfig|$CONFIG_SHARED/git/.gitconfig|Git|todos"
    "file|$HOME/.gitconfig-personal|$CONFIG_SHARED/git/.gitconfig-personal|Git pessoal|todos"
    "file|$HOME/.gitconfig-work|$CONFIG_SHARED/git/.gitconfig-work|Git trabalho|todos"
    "dir|$HOME/.config/nvim|$CONFIG_SHARED/nvim|Neovim|todos"
    "file|$HOME/.tmux.conf|$CONFIG_SHARED/tmux/.tmux.conf|Tmux|todos"
    "dir|$HOME/.ssh|$CONFIG_SHARED/.ssh|SSH|todos"
    "dir|$HOME/.config/lazygit|$CONFIG_SHARED/lazygit|Lazygit|todos"
    "dir|$HOME/.config/yazi|$CONFIG_SHARED/yazi|Yazi|todos"
    "dir|$HOME/.config/btop|$CONFIG_SHARED/btop|Btop|todos"
    "file|$HOME/.config/bat/config|$CONFIG_SHARED/bat/config|Bat|todos"
    "dir|$HOME/.config/kitty|$CONFIG_SHARED/kitty|Kitty|todos"
    "dir|$HOME/.config/alacritty|$CONFIG_SHARED/alacritty|Alacritty|todos"
    "dir|$HOME/.config/wezterm|$CONFIG_SHARED/wezterm|WezTerm|todos"
    "file|$HOME/.ripgreprc|$CONFIG_SHARED/.ripgreprc|Ripgrep|todos"
    "file|$HOME/.npmrc|$CONFIG_SHARED/npm/.npmrc|npm|todos"
    "file|$HOME/.config/pnpm/.pnpmrc|$CONFIG_SHARED/pnpm/.pnpmrc|pnpm|todos"
    "file|$HOME/.yarnrc|$CONFIG_SHARED/yarn/.yarnrc|Yarn|todos"
    "file|$HOME/.config/pip/pip.conf|$CONFIG_SHARED/pip/pip.conf|pip|todos"
    "file|$HOME/.cargo/config.toml|$CONFIG_SHARED/cargo/config.toml|Cargo|todos"
    "file|$HOME/.config/zed/settings.json|$CONFIG_SHARED/zed/settings.json|Zed|todos"
    "file|$HOME/.config/helix/config.toml|$CONFIG_SHARED/helix/config.toml|Helix|todos"
    "file|$HOME/.aider.conf.yml|$CONFIG_SHARED/aider/.aider.conf.yml|Aider|todos"
    "file|$HOME/.claude/CLAUDE.md|$CONFIG_SHARED/claude/CLAUDE.md|Claude Code|todos"
    "file|$HOME/.claude/RTK.md|$CONFIG_SHARED/claude/RTK.md|Claude Code RTK|todos"
    "file|$HOME/.docker/config.json|$CONFIG_SHARED/docker/config.json|Docker|todos"
    "file|$HOME/.config/direnv/direnvrc|$CONFIG_SHARED/direnv/.direnvrc|direnv|todos"
    "dir|$HOME/.config/ghostty|$CONFIG_LINUX/ghostty|Ghostty|linux"
    "dir|$HOME/Library/Application Support/com.mitchellh.ghostty|$CONFIG_MACOS/ghostty|Ghostty|macos"
  )
}

# Fora da tabela porque o nome de cada skill so se conhece varrendo o
# diretorio em tempo de execucao.
config_map_skills() {
  local dir_skills="$HOME/.claude/skills"
  [[ -d "$dir_skills" ]] || return 0
  local caminho nome
  for caminho in "$dir_skills"/*/; do
    [[ -d "$caminho" ]] || continue
    nome="$(basename "$caminho")"
    printf 'dir|%s|%s|Skill %s|todos\n' \
      "$dir_skills/$nome" "$CONFIG_SHARED/claude/skills/$nome" "$nome"
  done
}

# So o Ghostty diverge hoje: no macOS mora em Library/Application Support.
config_map_do_os() {
  local alvo="${1:-${TARGET_OS:-linux}}"
  local entrada os
  config_map_carregar
  for entrada in "${CONFIG_MAP[@]}"; do
    os="${entrada##*|}"
    [[ "$os" == "todos" || "$os" == "$alvo" ]] && printf '%s\n' "$entrada"
  done
}
