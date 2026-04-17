# 🐠 Fish Shell Configuration
# Limpo, consistente e pronto para VS Code + terminal externo

# ═══════════════════════════════════════════════════════════
# Fish Settings
# ═══════════════════════════════════════════════════════════
set -g fish_greeting

# ═══════════════════════════════════════════════════════════
# PATH Management
# Ordem importa: primeiro PATHs base, depois ferramentas que injetam ambiente
# ═══════════════════════════════════════════════════════════

# Homebrew (macOS)
if test -d /opt/homebrew/bin
    fish_add_path /opt/homebrew/bin
end

# Common system/local bins
if test -d /usr/local/bin
    fish_add_path /usr/local/bin
end

# User bins
if test -d ~/.local/bin
    fish_add_path ~/.local/bin
end

if test -d ~/bin
    fish_add_path ~/bin
end

# fzf
if test -d ~/.fzf/bin
    fish_add_path ~/.fzf/bin
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
# Environment Variables
# ═══════════════════════════════════════════════════════════
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx BAT_THEME "Catppuccin Mocha"
set -gx EXA_COLORS "da=38;5;245:sb=38;5;245:sn=38;5;245:uu=38;5;245:un=38;5;245:gu=38;5;245:gn=38;5;245"
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
set -gx RIPGREP_CONFIG_PATH ~/.ripgreprc
set -gx NODE_OPTIONS "--max-old-space-size=4096"
set -gx NPM_CONFIG_PREFIX ~/.npm-global

if command -v bat >/dev/null 2>&1
    set -gx PAGER bat
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
else if command -v batcat >/dev/null 2>&1
    set -gx PAGER batcat
    set -gx MANPAGER "sh -c 'col -bx | batcat -l man -p'"
else
    set -gx PAGER less
end
set -gx MANROFFOPT "-c"

# ═══════════════════════════════════════════════════════════
# Tools Integration
# Ferramentas que mexem em PATH/ambiente vêm antes do prompt
# ═══════════════════════════════════════════════════════════

# Mise (runtime manager)
if command -v mise >/dev/null 2>&1
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end

    if not test -f ~/.config/fish/completions/mise.fish
        mkdir -p ~/.config/fish/completions
        mise completion fish > ~/.config/fish/completions/mise.fish 2>/dev/null
    end
end

# direnv
if command -v direnv >/dev/null 2>&1
    direnv hook fish | source
end

# zoxide
if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end

# atuin
if command -v atuin >/dev/null 2>&1
    atuin init fish | source
end

# fzf key bindings
if command -v fzf >/dev/null 2>&1
    if test -f /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
        source /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
    else if test -f ~/.fzf/shell/key-bindings.fish
        source ~/.fzf/shell/key-bindings.fish
    end
end

# ═══════════════════════════════════════════════════════════
# Prompt Setup
# Colocado depois do mise para Node/Bun/Deno/PHP resolverem corretamente
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
        else if status is-interactive
            echo "⚠️  Starship não encontrado; usando prompt padrão do Fish."
        end
    case "oh-my-zsh"
        if status is-interactive
            echo "ℹ️  Oh My Zsh não funciona no Fish; mantido prompt padrão."
        end
    case "default"
        # usa prompt padrão do fish
    case "*"
        if status is-interactive
            echo "⚠️  DEV_PROMPT_FISH='$__dev_prompt_provider' desconhecido; usando prompt padrão."
        end
end
set -e __dev_prompt_provider

# ═══════════════════════════════════════════════════════════
# Aliases - File Management
# ═══════════════════════════════════════════════════════════
if command -v eza >/dev/null 2>&1
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lah --icons --group-directories-first'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza -lah --icons --sort=modified --reverse'
    alias lsize='eza -lah --icons --sort=size --reverse'
    alias ld='eza -lD --icons'
    alias lf='eza -lf --icons --color=always | grep -v /'
    alias lh='eza -dl --icons .* --group-directories-first'
    alias tree='eza --tree --icons --level=3'
    alias tree2='eza --tree --icons --level=2'
    alias tree4='eza --tree --icons --level=4'
else
    alias l='ls -CF'
    alias ll='ls -lah'
    alias la='ls -A'
end

if command -v bat >/dev/null 2>&1
    alias cat='bat --paging=never --style=auto'
    alias ccat='bat --paging=never --style=plain'
else if command -v batcat >/dev/null 2>&1
    alias cat='batcat --paging=never --style=auto'
    alias ccat='batcat --paging=never --style=plain'
end

# ═══════════════════════════════════════════════════════════
# Aliases - Navigation & System
# ═══════════════════════════════════════════════════════════
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias dev='cd ~/Development'
alias dl='cd ~/Downloads'
alias dt='cd ~/Desktop'
alias docs='cd ~/Documents'

alias c='clear'
alias h='history'
alias x='exit'

if command -v duf >/dev/null 2>&1
    alias df='duf'
else
    alias df='df -h'
end

alias du='du -h'
alias free='free -h'

if command -v btop >/dev/null 2>&1
    alias top='btop'
else if command -v htop >/dev/null 2>&1
    alias top='htop'
end

# Networking
alias ping='ping -c 5'
if command -v ss >/dev/null 2>&1
    alias ports='ss -tulpen'
else
    alias ports='netstat -tulanp'
end
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

if command -v lazygit >/dev/null 2>&1
    alias lg='lazygit'
end

# ═══════════════════════════════════════════════════════════
# Aliases - Development (Node / Bun / Deno / PHP / Laravel)
# ═══════════════════════════════════════════════════════════

# npm
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

# yarn
alias yi='yarn install'
alias ya='yarn add'
alias yad='yarn add --dev'
alias yr='yarn remove'
alias yup='yarn upgrade'
alias ys='yarn start'
alias yd='yarn dev'
alias yb='yarn build'

# pnpm
alias pi='pnpm install'
alias pa='pnpm add'
alias pad='pnpm add -D'
alias pr='pnpm remove'
alias pup='pnpm update'
alias ps='pnpm start'
alias pd='pnpm dev'
alias pb='pnpm build'

# bun
alias buni='bun install'
alias bunx='bunx'
alias bund='bun run dev'
alias bunt='bun test'
alias bunb='bun run build'

# deno
alias denor='deno run'
alias denot='deno task'
alias denof='deno fmt'
alias denol='deno lint'

# PHP / Laravel / Composer
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

# Docker
alias d='docker'
if command -v docker >/dev/null 2>&1
    if docker compose version >/dev/null 2>&1
        alias dc='docker compose'
        alias dcu='docker compose up'
        alias dcud='docker compose up -d'
        alias dcd='docker compose down'
        alias dcr='docker compose restart'
        alias dcl='docker compose logs -f'
        alias dcp='docker compose ps'
        alias dce='docker compose exec'
        alias dcb='docker compose build'
    else
        alias dc='docker-compose'
        alias dcu='docker-compose up'
        alias dcud='docker-compose up -d'
        alias dcd='docker-compose down'
        alias dcr='docker-compose restart'
        alias dcl='docker-compose logs -f'
        alias dcp='docker-compose ps'
        alias dce='docker-compose exec'
        alias dcb='docker-compose build'
    end
end

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

alias fishconfig='nvim ~/.config/fish/config.fish'
alias starconfig='nvim ~/.config/starship.toml'
alias nvimconfig='nvim ~/.config/nvim/'
alias gitconfig='nvim ~/.gitconfig'

# ═══════════════════════════════════════════════════════════
# Custom Functions
# ═══════════════════════════════════════════════════════════
function mkcd -d "Create directory and cd into it"
    if test (count $argv) -eq 0
        echo "❌ Uso: mkcd <diretório>"
        return 1
    end
    mkdir -p $argv[1]; and cd $argv[1]
end

function extract -d "Extract compressed files"
    if test (count $argv) -eq 0
        echo "❌ Uso: extract <arquivo>"
        return 1
    end

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

function gcom -d "Git add all and commit with message"
    if test (count $argv) -eq 0
        echo "❌ Uso: gcom <mensagem do commit>"
        return 1
    end
    git add .
    git commit -m "$argv"
end

function gpush -d "Git push with automatic upstream"
    set branch (git branch --show-current)
    if test -z "$branch"
        echo "❌ Não foi possível detectar a branch atual"
        return 1
    end
    git push -u origin $branch
end

function create-react -d "Create new React project with Vite"
    if test (count $argv) -eq 0
        echo "❌ Uso: create-react <nome-do-projeto>"
        return 1
    end
    npm create vite@latest $argv[1] -- --template react-ts
    and cd $argv[1]
    and npm install
    and echo "✅ Projeto React criado: $argv[1]"
end

function create-laravel -d "Create new Laravel project"
    if test (count $argv) -eq 0
        echo "❌ Uso: create-laravel <nome-do-projeto>"
        return 1
    end
    composer create-project laravel/laravel $argv[1]
    and cd $argv[1]
    and php artisan key:generate
    and echo "✅ Projeto Laravel criado: $argv[1]"
end

function dev-clean -d "Clean all development caches"
    echo "🧹 Limpando caches de desenvolvimento..."

    if test -d node_modules
        echo "  📦 Limpando node_modules..."
        rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock
        if test -f package.json
            npm install
        end
    end

    if test -f artisan
        echo "  🐘 Limpando cache Laravel..."
        php artisan cache:clear
        php artisan config:clear
        php artisan route:clear
        php artisan view:clear
        composer dump-autoload
    end

    if test -f docker-compose.yml
        echo "  🐳 Reconstruindo containers Docker..."
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
    else if test -f compose.yml; or test -f compose.yaml
        echo "  🐳 Reconstruindo containers Docker..."
        docker compose down
        docker compose build --no-cache
        docker compose up -d
    end

    echo "✅ Limpeza concluída!"
end

function port -d "Find process using specific port"
    if test (count $argv) -eq 0
        echo "❌ Uso: port <número>"
        return 1
    end

    if command -v lsof >/dev/null 2>&1
        lsof -i :$argv[1]
    else if command -v ss >/dev/null 2>&1
        ss -ltnp "( sport = :$argv[1] )"
    else if command -v netstat >/dev/null 2>&1
        netstat -tlnp | grep :$argv[1]
    else
        echo "❌ lsof, ss ou netstat não encontrado"
        return 1
    end
end

function backup -d "Create backup of file"
    if test (count $argv) -eq 0
        echo "❌ Uso: backup <arquivo>"
        return 1
    end

    set file $argv[1]
    set backup_file "$file.backup."(date +%Y%m%d_%H%M%S)
    cp $file $backup_file
    and echo "✅ Backup criado: $backup_file"
end

function dirsize -d "Show directory sizes"
    du -sh * | sort -h
end

# ═══════════════════════════════════════════════════════════
# Welcome Message (Optional)
# ═══════════════════════════════════════════════════════════
if status is-interactive
    # echo ""
    # echo "🐠 Fish Shell + ⭐ Starship"
    # echo "💻 Sistema: "(uname -s)" | "(uname -m)
    # echo ""
end
