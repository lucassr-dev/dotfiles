# 🐠 Fish Shell Configuration
# Config gerenciada por config/install.sh

# ═══════════════════════════════════════════════════════════
# Prompt Setup (Starship por padrão)
# Defina DEV_PROMPT_FISH (ou DEV_PROMPT_PROVIDER) para escolher:
#   starship (default) | default
#   OBS: Oh My Zsh não é compatível com Fish.
# ═══════════════════════════════════════════════════════════
set -l __dev_prompt_provider "starship"
if set -q DEV_PROMPT_FISH
    set __dev_prompt_provider $DEV_PROMPT_FISH
else if set -q DEV_PROMPT_PROVIDER
    set __dev_prompt_provider $DEV_PROMPT_PROVIDER
end

switch (string lower $__dev_prompt_provider)
    case "starship"
        if command -v starship >/dev/null 2>&1
            starship init fish | source
        else
            if status is-interactive
                echo "⚠️  Starship não encontrado; usando prompt padrão do Fish."
            end
        end
    case "oh-my-zsh"
        if status is-interactive
            echo "ℹ️  Oh My Zsh não funciona no Fish; mantido prompt padrão."
        end
    case "*"
        if status is-interactive
            echo "⚠️  DEV_PROMPT_FISH='($__dev_prompt_provider)' desconhecido; usando prompt padrão."
        end
end

set -e __dev_prompt_provider

# ═══════════════════════════════════════════════════════════
# Fish Settings
# ═══════════════════════════════════════════════════════════
set -g fish_greeting # Disable welcome message

# Better colors for ls/eza
set -gx EXA_COLORS "da=38;5;245:sb=38;5;245:sn=38;5;245:uu=38;5;245:un=38;5;245:gu=38;5;245:gn=38;5;245"

# ═══════════════════════════════════════════════════════════
# Environment Variables
# ═══════════════════════════════════════════════════════════
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER bat

# Bat theme (matching Catppuccin Mocha)
set -gx BAT_THEME "Catppuccin Mocha"

# Better man pages with bat
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx MANROFFOPT "-c"

# FZF colors (Catppuccin Mocha)
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# Ripgrep config
set -gx RIPGREP_CONFIG_PATH ~/.ripgreprc

# Node/npm/pnpm settings
set -gx NODE_OPTIONS "--max-old-space-size=4096"
set -gx NPM_CONFIG_PREFIX ~/.npm-global

# ═══════════════════════════════════════════════════════════
# Aliases - File Management
# ═══════════════════════════════════════════════════════════
if command -v eza >/dev/null
    # Directory listings
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lah --icons --group-directories-first'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza -lah --icons --sort=modified --reverse'
    alias lsize='eza -lah --icons --sort=size --reverse'

    # Specific listings
    alias ld='eza -lD --icons' # Only directories
    alias lf='eza -lf --icons --color=always | grep -v /' # Only files
    alias lh='eza -dl --icons .* --group-directories-first' # Hidden files

    # Tree view
    alias tree='eza --tree --icons --level=3'
    alias tree2='eza --tree --icons --level=2'
    alias tree4='eza --tree --icons --level=4'
else
    alias ll='ls -lah'
    alias la='ls -A'
    alias l='ls -CF'
end

# Cat with syntax highlighting
if command -v bat >/dev/null
    alias cat='bat --style=auto'
    alias ccat='bat --style=plain' # cat without line numbers
else if command -v batcat >/dev/null
    alias cat='batcat --style=auto'
    alias ccat='batcat --style=plain'
end

# ═══════════════════════════════════════════════════════════
# Aliases - Navigation & System
# ═══════════════════════════════════════════════════════════
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Note: ~ and - are built-in fish shortcuts, no need to alias

# Quick access to common dirs
alias dev='cd ~/Development'
alias dl='cd ~/Downloads'
alias dt='cd ~/Desktop'
alias docs='cd ~/Documents'

# System
alias c='clear'
alias h='history'
alias x='exit'

# Disk usage
if command -v duf >/dev/null
    alias df='duf'
else
    alias df='df -h'
end

alias du='du -h'
alias free='free -h'

# Process management
if command -v btop >/dev/null
    alias top='btop'
else if command -v htop >/dev/null
    alias top='htop'
end

# ═══════════════════════════════════════════════════════════
# Aliases - Git
# ═══════════════════════════════════════════════════════════
alias g='git'
alias gs='git status'
alias gss='git status -s'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias glp='git log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short'
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git remote -v'
alias greset='git reset --hard HEAD'
alias gclean='git clean -fd'
alias gstash='git stash'
alias gstashp='git stash pop'

# Lazy git (se instalado)
if command -v lazygit >/dev/null
    alias lg='lazygit'
end

# ═══════════════════════════════════════════════════════════
# Aliases - Development (React, Node, PHP/Laravel)
# ═══════════════════════════════════════════════════════════
# Node/npm/yarn/pnpm
alias ni='npm install'
alias nid='npm install --save-dev'
alias nig='npm install -g'
alias nu='npm uninstall'
alias nup='npm update'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'
alias nd='npm run dev'
alias nls='npm list --depth=0'

alias yi='yarn install'
alias ya='yarn add'
alias yad='yarn add --dev'
alias yr='yarn remove'
alias yup='yarn upgrade'
alias ys='yarn start'
alias yd='yarn dev'
alias yb='yarn build'

alias pi='pnpm install'
alias pa='pnpm add'
alias pad='pnpm add -D'
alias pr='pnpm remove'
alias pup='pnpm update'
alias ps='pnpm start'
alias pd='pnpm dev'
alias pb='pnpm build'

# PHP/Laravel/Composer
alias php='php'
alias composer='composer'
alias ci='composer install'
alias cu='composer update'
alias cr='composer require'
alias cda='composer dump-autoload'

alias art='php artisan'
alias tinker='php artisan tinker'
alias migrate='php artisan migrate'
alias mfs='php artisan migrate:fresh --seed'
alias seed='php artisan db:seed'
alias serve='php artisan serve'
alias optimize='php artisan optimize'
alias cache='php artisan cache:clear'
alias config='php artisan config:clear'
alias route='php artisan route:list'

# Docker & Docker Compose
alias d='docker'
alias dc='docker-compose'
alias dcu='docker-compose up'
alias dcud='docker-compose up -d'
alias dcd='docker-compose down'
alias dcr='docker-compose restart'
alias dcl='docker-compose logs -f'
alias dcp='docker-compose ps'
alias dce='docker-compose exec'
alias dcb='docker-compose build'

alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dstop='docker stop (docker ps -q)'
alias dclean='docker system prune -af'

# ═══════════════════════════════════════════════════════════
# Aliases - Utilities
# ═══════════════════════════════════════════════════════════
alias vim='nvim'
alias v='nvim'
alias vi='nvim'

# Quick edit configs
alias fishconfig='nvim ~/.config/fish/config.fish'
alias starconfig='nvim ~/.config/starship.toml'
alias nvimconfig='nvim ~/.config/nvim/'
alias gitconfig='nvim ~/.gitconfig'

# Networking
alias ping='ping -c 5'
alias ports='netstat -tulanp'
alias myip='curl -s https://ipinfo.io/ip'
alias localip='ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk "{print \$2}" | cut -d/ -f1'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Time
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias nowdate='date +"%Y-%m-%d"'
alias nowtime='date +"%H:%M:%S"'

# ═══════════════════════════════════════════════════════════
# Tools Integration
# ═══════════════════════════════════════════════════════════

# Zoxide (smart cd)
if command -v zoxide &>/dev/null
    zoxide init fish | source
    # Note: não substituindo 'cd' para manter compatibilidade
    # Use 'z' para navegação inteligente
end

# Mise (runtime manager) - gerencia Node.js, Python, Rust, Go, etc
if command -v mise &>/dev/null
    mise activate fish | source

    # Completions
    if not test -f ~/.config/fish/completions/mise.fish
        mkdir -p ~/.config/fish/completions
        mise completion fish > ~/.config/fish/completions/mise.fish 2>/dev/null
    end
end

# direnv (env por diretório)
if command -v direnv &>/dev/null
    direnv hook fish | source
end

# FZF (fuzzy finder)
if command -v fzf &>/dev/null
    # Ctrl+R para histórico
    # Ctrl+T para arquivos
    # Alt+C para diretórios
    if test -f /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
        source /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
    end
end

# Atuin (better history) - se instalado
if command -v atuin &>/dev/null
    atuin init fish | source
end

# ═══════════════════════════════════════════════════════════
# Custom Functions
# ═══════════════════════════════════════════════════════════

# Criar diretório e entrar nele
function mkcd -d "Create directory and cd into it"
    mkdir -p $argv[1]; and cd $argv[1]
end

# Extrair qualquer arquivo compactado
function extract -d "Extract compressed files"
    if test -f $argv[1]
        switch $argv[1]
            case '*.tar.bz2'
                tar xjf $argv[1]
            case '*.tar.gz'
                tar xzf $argv[1]
            case '*.bz2'
                bunzip2 $argv[1]
            case '*.rar'
                unrar x $argv[1]
            case '*.gz'
                gunzip $argv[1]
            case '*.tar'
                tar xf $argv[1]
            case '*.tbz2'
                tar xjf $argv[1]
            case '*.tgz'
                tar xzf $argv[1]
            case '*.zip'
                unzip $argv[1]
            case '*.Z'
                uncompress $argv[1]
            case '*.7z'
                7z x $argv[1]
            case '*'
                echo "❌ Formato desconhecido: '$argv[1]'"
                return 1
        end
        echo "✅ Extraído: $argv[1]"
    else
        echo "❌ '$argv[1]' não é um arquivo válido"
        return 1
    end
end

# Git commit com mensagem rápida
function gcom -d "Git add all and commit with message"
    if test (count $argv) -eq 0
        echo "❌ Uso: gcom <mensagem do commit>"
        return 1
    end
    git add .
    git commit -m "$argv"
end

# Git push com upstream automático
function gpush -d "Git push with automatic upstream"
    set branch (git branch --show-current)
    git push -u origin $branch
end

# Criar novo projeto React com Vite
function create-react -d "Create new React project with Vite"
    if test (count $argv) -eq 0
        echo "❌ Uso: create-react <nome-do-projeto>"
        return 1
    end
    npm create vite@latest $argv[1] -- --template react-ts
    cd $argv[1]
    npm install
    echo "✅ Projeto React criado: $argv[1]"
end

# Criar novo projeto Laravel
function create-laravel -d "Create new Laravel project"
    if test (count $argv) -eq 0
        echo "❌ Uso: create-laravel <nome-do-projeto>"
        return 1
    end
    composer create-project laravel/laravel $argv[1]
    cd $argv[1]
    php artisan key:generate
    echo "✅ Projeto Laravel criado: $argv[1]"
end

# Limpar caches de desenvolvimento
function dev-clean -d "Clean all development caches"
    echo "🧹 Limpando caches de desenvolvimento..."

    # Node
    if test -d node_modules
        echo "  📦 Limpando node_modules..."
        rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml
        npm install
    end

    # Laravel
    if test -f artisan
        echo "  🐘 Limpando cache Laravel..."
        php artisan cache:clear
        php artisan config:clear
        php artisan route:clear
        php artisan view:clear
        composer dump-autoload
    end

    # Docker
    if test -f docker-compose.yml
        echo "  🐳 Reconstruindo containers Docker..."
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
    end

    echo "✅ Limpeza concluída!"
end

# Buscar processo rodando em porta específica
function port -d "Find process using specific port"
    if test (count $argv) -eq 0
        echo "❌ Uso: port <número>"
        return 1
    end

    if command -v lsof >/dev/null
        lsof -i :$argv[1]
    else if command -v netstat >/dev/null
        netstat -tlnp | grep :$argv[1]
    else
        echo "❌ lsof ou netstat não encontrado"
        return 1
    end
end

# Backup rápido de arquivo
function backup -d "Create backup of file"
    if test (count $argv) -eq 0
        echo "❌ Uso: backup <arquivo>"
        return 1
    end

    set file $argv[1]
    set backup_file "$file.backup."(date +%Y%m%d_%H%M%S)
    cp $file $backup_file
    echo "✅ Backup criado: $backup_file"
end

# Mostrar tamanho de diretórios
function dirsize -d "Show directory sizes"
    du -sh * | sort -h
end

# ═══════════════════════════════════════════════════════════
# PATH Management
# ═══════════════════════════════════════════════════════════
# Homebrew (macOS)
if test -d /opt/homebrew/bin
    fish_add_path /opt/homebrew/bin
end

if test -d /usr/local/bin
    fish_add_path /usr/local/bin
end

# User binaries
fish_add_path ~/.local/bin
fish_add_path ~/bin

# fzf (instalado via git)
if test -d ~/.fzf/bin
    fish_add_path ~/.fzf/bin
end

# mise shims (runtime manager)
if test -d ~/.local/share/mise/shims
    fish_add_path ~/.local/share/mise/shims
end

# Cargo (Rust)
if test -d ~/.cargo/bin
    fish_add_path ~/.cargo/bin
end

# npm global
if test -d ~/.npm-global/bin
    fish_add_path ~/.npm-global/bin
end

# Go
if test -d ~/go/bin
    fish_add_path ~/go/bin
end

# ═══════════════════════════════════════════════════════════
# Welcome Message (Optional)
# ═══════════════════════════════════════════════════════════
if status is-interactive
    # Descomente para mostrar mensagem de boas-vindas
    # echo ""
    # echo "🐠 Fish Shell + ⭐ Starship"
    # echo "💻 Sistema: "(uname -s)" | "(uname -m)
    # echo ""

    # Mostrar dica aleatória (opcional)
    # set tips \
    #     "💡 Use 'z <dir>' para navegação inteligente" \
    #     "💡 Use 'lg' para interface Git visual (lazygit)" \
    #     "💡 Use 'dev-clean' para limpar caches de desenvolvimento" \
    #     "💡 Use 'tree' para visualizar estrutura de diretórios" \
    #     "💡 Use 'port 3000' para ver processo usando porta"
    # echo $tips[(random 1 (count $tips))]
    # echo ""
end
