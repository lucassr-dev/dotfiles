# Nushell Environment Configuration
# Arquivo: env.nu
# Este arquivo configura variáveis de ambiente antes do config.nu

# ══════════════════════════════════════════════════════════════════════════════
# VARIÁVEIS DE AMBIENTE BÁSICAS
# ══════════════════════════════════════════════════════════════════════════════

$env.EDITOR = (if (which nvim | is-not-empty) { "nvim" } else if (which code | is-not-empty) { "code --wait" } else { "vim" })
$env.VISUAL = $env.EDITOR
$env.PAGER = "less -R"
$env.LANG = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"

# ══════════════════════════════════════════════════════════════════════════════
# PATH - Diretórios de executáveis
# ══════════════════════════════════════════════════════════════════════════════

# Helper para adicionar ao PATH se o diretório existir
def --env add-to-path [dir: string] {
  if ($dir | path exists) {
    $env.PATH = ($env.PATH | prepend $dir)
  }
}

# Diretórios locais
add-to-path ($env.HOME | path join ".local" "bin")
add-to-path ($env.HOME | path join ".cargo" "bin")
add-to-path ($env.HOME | path join "go" "bin")
add-to-path ($env.HOME | path join ".bun" "bin")
add-to-path ($env.HOME | path join ".deno" "bin")

# Homebrew (macOS)
if ("/opt/homebrew/bin" | path exists) {
  add-to-path "/opt/homebrew/bin"
  add-to-path "/opt/homebrew/sbin"
}

# ══════════════════════════════════════════════════════════════════════════════
# MISE - Runtime Version Manager
# ══════════════════════════════════════════════════════════════════════════════

if (which mise | is-not-empty) {
  # Ativar mise para gerenciamento de versões (Node, Python, PHP, etc.)
  $env.MISE_SHELL = "nu"

  # Adicionar shims do mise ao PATH
  let mise_data_dir = ($env.HOME | path join ".local" "share" "mise")
  if ($mise_data_dir | path exists) {
    add-to-path ($mise_data_dir | path join "shims")
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# PROMPT - Starship ou Oh My Posh
# ══════════════════════════════════════════════════════════════════════════════

# Criar diretório de scripts se não existir
if not (($nu.default-config-dir | path join "scripts") | path exists) {
  mkdir ($nu.default-config-dir | path join "scripts")
}

# Starship (se instalado)
if (which starship | is-not-empty) {
  starship init nu | save -f ($nu.default-config-dir | path join "scripts" "starship.nu")
}

# Oh My Posh (se instalado e config existir)
if (which oh-my-posh | is-not-empty) {
  let omp_script = ($nu.default-config-dir | path join "scripts" "omp.nu")
  let omp_config = ($nu.default-config-dir | path join "omp-theme.json")
  if ($omp_config | path exists) {
    oh-my-posh init nu --config $omp_config | save -f $omp_script
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# CORES DO LS_COLORS (para eza e outros)
# ══════════════════════════════════════════════════════════════════════════════

$env.LS_COLORS = "di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

# ══════════════════════════════════════════════════════════════════════════════
# FZF - Configuração
# ══════════════════════════════════════════════════════════════════════════════

$env.FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --preview-window=right:50%"

if (which fd | is-not-empty) {
  $env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
}

# ══════════════════════════════════════════════════════════════════════════════
# DESENVOLVIMENTO
# ══════════════════════════════════════════════════════════════════════════════

# Node.js
$env.NODE_OPTIONS = "--max-old-space-size=4096"

# Python
$env.PYTHONDONTWRITEBYTECODE = "1"
$env.PYTHONUNBUFFERED = "1"

# Go
$env.GOPATH = ($env.HOME | path join "go")

# Rust
$env.CARGO_HOME = ($env.HOME | path join ".cargo")
$env.RUSTUP_HOME = ($env.HOME | path join ".rustup")

# Docker
$env.DOCKER_BUILDKIT = "1"
$env.COMPOSE_DOCKER_CLI_BUILD = "1"
