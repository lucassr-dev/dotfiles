# Zsh Configuration
# 🔥 Config gerenciada por dot-portable

# ═══════════════════════════════════════════════════════════
# Prompt Setup (Oh My Zsh + P10k ✨ ou Starship 🚀)
# Use DEV_PROMPT_ZSH (ou DEV_PROMPT_PROVIDER) para escolher:
#   oh-my-zsh (default) | starship
# ═══════════════════════════════════════════════════════════
export ZSH="$HOME/.oh-my-zsh"

# Plugins (mantidos para ambos os prompts)
plugins=(git docker npm node python command-not-found sudo extract z web-search zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete zsh-completions)

prompt_load_omz_with_p10k() {
  ZSH_THEME="powerlevel10k/powerlevel10k"
  if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
  else
    [[ -o interactive ]] && echo "⚠️  Oh My Zsh não encontrado; tentando Starship (se disponível)."
    if command -v starship >/dev/null 2>&1; then
      eval "$(starship init zsh)"
    fi
    return
  fi
  [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
}

prompt_load_starship() {
  if ! command -v starship >/dev/null 2>&1; then
    [[ -o interactive ]] && echo "⚠️  Starship não encontrado; voltando para Oh My Zsh + Powerlevel10k."
    prompt_load_omz_with_p10k
    return
  fi

  # Ainda carregamos o Oh My Zsh para plugins/tools, mas sem P10k.
  ZSH_THEME=""
  if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
  fi
  eval "$(starship init zsh)"
}

_dev_prompt_target="${DEV_PROMPT_ZSH:-${DEV_PROMPT_PROVIDER:-oh-my-zsh}}"
_dev_prompt_target="${_dev_prompt_target:l}"

case "$_dev_prompt_target" in
  "starship")
    prompt_load_starship
    ;;
  "oh-my-zsh"|"p10k"|"powerlevel10k")
    prompt_load_omz_with_p10k
    ;;
  *)
    [[ -o interactive ]] && echo "⚠️  DEV_PROMPT_ZSH='$_dev_prompt_target' desconhecido. Usando Oh My Zsh."
    prompt_load_omz_with_p10k
    ;;
esac

unset -f prompt_load_omz_with_p10k prompt_load_starship
unset _dev_prompt_target

# ═══════════════════════════════════════════════════════════
# Aliases
# ═══════════════════════════════════════════════════════════
alias ll='eza -la --icons --git'
alias ls='eza --icons'
if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
fi
alias vim='nvim'
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'

# ═══════════════════════════════════════════════════════════
# Environment Variables
# ═══════════════════════════════════════════════════════════
export EDITOR=nvim
export VISUAL=nvim

# ═══════════════════════════════════════════════════════════
# Tools
# ═══════════════════════════════════════════════════════════

# Zoxide (smart cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# FZF
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"

  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
  elif command -v fdfind >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="fdfind --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fdfind --type=d --hidden --strip-cwd-prefix --exclude .git"
  fi
fi

# Mise (runtime manager) - gerencia Node.js, Python, Rust, etc
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# direnv (env por diretório)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ═══════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════

# Criar diretório e entrar nele
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extrair qualquer arquivo compactado
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"   ;;
      *.tar.gz)    tar xzf "$1"   ;;
      *.bz2)       bunzip2 "$1"   ;;
      *.rar)       unrar x "$1"   ;;
      *.gz)        gunzip "$1"    ;;
      *.tar)       tar xf "$1"    ;;
      *.tbz2)      tar xjf "$1"   ;;
      *.tgz)       tar xzf "$1"   ;;
      *.zip)       unzip "$1"     ;;
      *.Z)         uncompress "$1";;
      *.7z)        7z x "$1"      ;;
      *)           echo "Formato desconhecido: '$1'" ;;
    esac
  else
    echo "'$1' não é um arquivo válido"
  fi
}

# Git commit com mensagem rápida
gcom() {
  git add .
  git commit -m "$*"
}

# ═══════════════════════════════════════════════════════════
# PATH
# ═══════════════════════════════════════════════════════════
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ═══════════════════════════════════════════════════════════
# History
# ═══════════════════════════════════════════════════════════
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# ═══════════════════════════════════════════════════════════
# Completion
# ═══════════════════════════════════════════════════════════
autoload -U compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
