# Nushell Configuration
# Arquivo: config.nu
# Configuração moderna para desenvolvimento

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════

$env.config = {
  show_banner: false

  # Completions
  completions: {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: "fuzzy"
    external: {
      enable: true
      max_results: 100
      completer: null
    }
  }

  # Histórico
  history: {
    max_size: 100000
    sync_on_enter: true
    file_format: "sqlite"
    isolation: false
  }

  # Formatação de arquivos
  filesize: {
    metric: true
    format: "auto"
  }

  # Cursor
  cursor_shape: {
    emacs: line
    vi_insert: line
    vi_normal: block
  }

  # Tabelas e formatação
  table: {
    mode: rounded
    index_mode: always
    show_empty: true
    padding: { left: 1, right: 1 }
    trim: {
      methodology: wrapping
      wrapping_try_keep_words: true
      truncating_suffix: "..."
    }
    header_on_separator: false
  }

  # Erros
  error_style: "fancy"

  # Datetime
  datetime_format: {
    normal: "%Y-%m-%d %H:%M:%S"
    table: "%Y-%m-%d %H:%M"
  }

  # Hooks
  hooks: {
    pre_prompt: []
    pre_execution: []
    env_change: {
      PWD: [{|before, after|
        # Hook para direnv (se instalado)
        if (which direnv | is-not-empty) {
          direnv export json | from json | default {} | load-env
        }
      }]
    }
    display_output: "if (term size).columns >= 100 { table -e } else { table }"
    command_not_found: {}
  }

  # Menus
  menus: [
    {
      name: completion_menu
      only_buffer_difference: false
      marker: "| "
      type: {
        layout: columnar
        columns: 4
        col_width: 20
        col_padding: 2
      }
      style: {
        text: green
        selected_text: { attr: r }
        description_text: yellow
      }
    }
    {
      name: history_menu
      only_buffer_difference: true
      marker: "? "
      type: {
        layout: list
        page_size: 10
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
    }
  ]

  # Keybindings
  keybindings: [
    {
      name: completion_menu
      modifier: none
      keycode: tab
      mode: [emacs vi_normal vi_insert]
      event: {
        until: [
          { send: menu name: completion_menu }
          { send: menunext }
          { edit: complete }
        ]
      }
    }
    {
      name: history_menu
      modifier: control
      keycode: char_r
      mode: [emacs, vi_insert, vi_normal]
      event: { send: menu name: history_menu }
    }
    {
      name: clear_screen
      modifier: control
      keycode: char_l
      mode: [emacs, vi_insert, vi_normal]
      event: { send: clearscreen }
    }
  ]
}

# ══════════════════════════════════════════════════════════════════════════════
# TEMA DE CORES (Catppuccin Mocha inspirado)
# ══════════════════════════════════════════════════════════════════════════════

$env.config.color_config = {
  separator: dark_gray
  leading_trailing_space_bg: { attr: n }
  header: green_bold
  empty: blue
  bool: light_cyan
  int: light_cyan
  filesize: cyan
  duration: light_cyan
  date: purple
  range: light_cyan
  float: light_cyan
  string: white
  nothing: white
  binary: light_cyan
  cell-path: light_cyan
  row_index: green_bold
  record: white
  list: white
  block: white
  hints: dark_gray
  search_result: { bg: red fg: white }
  shape_and: purple_bold
  shape_binary: purple_bold
  shape_block: blue_bold
  shape_bool: light_cyan
  shape_closure: green_bold
  shape_custom: green
  shape_datetime: cyan_bold
  shape_directory: cyan
  shape_external: cyan
  shape_externalarg: green_bold
  shape_external_resolved: light_yellow_bold
  shape_filepath: cyan
  shape_flag: blue_bold
  shape_float: purple_bold
  shape_garbage: { fg: white bg: red attr: b }
  shape_globpattern: cyan_bold
  shape_int: purple_bold
  shape_internalcall: cyan_bold
  shape_keyword: cyan_bold
  shape_list: cyan_bold
  shape_literal: blue
  shape_match_pattern: green
  shape_matching_brackets: { attr: u }
  shape_nothing: light_cyan
  shape_operator: yellow
  shape_or: purple_bold
  shape_pipe: purple_bold
  shape_range: yellow_bold
  shape_record: cyan_bold
  shape_redirection: purple_bold
  shape_signature: green_bold
  shape_string: green
  shape_string_interpolation: cyan_bold
  shape_table: blue_bold
  shape_variable: purple
  shape_vardecl: purple
  shape_raw_string: light_purple
}

# ══════════════════════════════════════════════════════════════════════════════
# ALIASES - Ferramentas Modernas
# ══════════════════════════════════════════════════════════════════════════════

# eza (substituto moderno do ls)
if (which eza | is-not-empty) {
  alias ll = eza -la --icons --git --group-directories-first
  alias la = eza -a --icons --group-directories-first
  alias lt = eza -T --icons --git-ignore -L 3
  alias llt = eza -laT --icons --git -L 2
}

# bat (substituto moderno do cat)
if (which bat | is-not-empty) {
  alias cat = bat --paging=never --style=plain
  alias catn = bat --paging=never
  alias catp = bat --style=full
}

# fd (substituto moderno do find)
if (which fd | is-not-empty) {
  alias ff = fd --type f
  alias fd-hidden = fd --hidden --no-ignore
}

# ripgrep (substituto moderno do grep)
if (which rg | is-not-empty) {
  alias grep = rg
  alias rgi = rg --ignore-case
  alias rgf = rg --files-with-matches
}

# zoxide (cd inteligente)
if (which zoxide | is-not-empty) {
  # zoxide init é executado automaticamente
}

# lazygit
if (which lazygit | is-not-empty) {
  alias lg = lazygit
}

# btop
if (which btop | is-not-empty) {
  alias top = btop
}

# dust (du moderno)
if (which dust | is-not-empty) {
  alias du = dust
}

# procs (ps moderno)
if (which procs | is-not-empty) {
  alias ps = procs
}

# ══════════════════════════════════════════════════════════════════════════════
# ALIASES - Git
# ══════════════════════════════════════════════════════════════════════════════

alias g = git
alias gs = git status -sb
alias ga = git add
alias gaa = git add --all
alias gc = git commit
alias gcm = git commit -m
alias gca = git commit --amend
alias gco = git checkout
alias gcb = git checkout -b
alias gp = git push
alias gpf = git push --force-with-lease
alias gl = git pull
alias gf = git fetch --all --prune
alias gd = git diff
alias gds = git diff --staged
alias glog = git log --oneline --graph --decorate -20
alias gb = git branch
alias gba = git branch -a
alias gbr = git branch -r
alias gst = git stash
alias gstp = git stash pop
alias grb = git rebase
alias grbi = git rebase -i

# ══════════════════════════════════════════════════════════════════════════════
# ALIASES - Docker
# ══════════════════════════════════════════════════════════════════════════════

if (which docker | is-not-empty) {
  alias d = docker
  alias dc = docker compose
  alias dcu = docker compose up -d
  alias dcd = docker compose down
  alias dcl = docker compose logs -f
  alias dps = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  alias dex = docker exec -it
  alias dprune = docker system prune -af
}

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES ÚTEIS PARA DESENVOLVIMENTO
# ══════════════════════════════════════════════════════════════════════════════

# Criar diretório e entrar nele
def --env mkcd [dir: string] {
  mkdir $dir
  cd $dir
}

# Extrair arquivos automaticamente
def extract [file: string] {
  let ext = ($file | path parse | get extension)
  match $ext {
    "tar" | "gz" | "tgz" => { tar -xvf $file }
    "bz2" | "tbz" => { tar -xjvf $file }
    "xz" | "txz" => { tar -xJvf $file }
    "zip" => { unzip $file }
    "rar" => { unrar x $file }
    "7z" => { 7z x $file }
    _ => { print $"Formato não suportado: ($ext)" }
  }
}

# Buscar em arquivos com preview
def search [pattern: string, path: string = "."] {
  if (which rg | is-not-empty) {
    rg --color=always --line-number $pattern $path
  } else {
    grep -rn $pattern $path
  }
}

# Ver processos usando uma porta
def port [port_num: int] {
  if (which lsof | is-not-empty) {
    lsof -i :($port_num)
  } else {
    ss -tulpn | grep $":($port_num)"
  }
}

# JSON prettifier
def jsonp [] {
  $in | from json | to json --indent 2
}

# Tamanho de diretórios (top 10)
def dsize [path: string = "."] {
  ls $path | where type == dir | each { |it|
    { name: $it.name, size: (du -sb $it.name | split row "\t" | first | into int) }
  } | sort-by size -r | first 10
}

# Git: mostrar arquivos modificados com diff
def gdiff [] {
  git diff --name-only | each { |file|
    print $"(ansi green)═══ ($file) ═══(ansi reset)"
    git diff $file
  }
}

# Ambiente virtual Python
def --env venv [name: string = ".venv"] {
  if not ($name | path exists) {
    python -m venv $name
  }

  let activate = ($name | path join "bin" "activate.nu")
  if ($activate | path exists) {
    source $activate
  } else {
    $env.VIRTUAL_ENV = ($name | path expand)
    $env.PATH = ($env.PATH | prepend ($name | path join "bin"))
  }
}

# Node.js: limpar cache e reinstalar
def npm-clean [] {
  rm -rf node_modules
  rm -f package-lock.json
  npm install
}

# ══════════════════════════════════════════════════════════════════════════════
# PROMPT - Starship ou Oh My Posh
# ══════════════════════════════════════════════════════════════════════════════

if (($nu.default-config-dir | path join "scripts" "starship.nu") | path exists) {
  source ($nu.default-config-dir | path join "scripts" "starship.nu")
} else if (($nu.default-config-dir | path join "scripts" "omp.nu") | path exists) {
  source ($nu.default-config-dir | path join "scripts" "omp.nu")
}

# ══════════════════════════════════════════════════════════════════════════════
# ZOXIDE (cd inteligente)
# ══════════════════════════════════════════════════════════════════════════════

if (which zoxide | is-not-empty) {
  # Inicializar zoxide
  zoxide init nushell | save -f ($nu.default-config-dir | path join "scripts" "zoxide.nu")
  source ($nu.default-config-dir | path join "scripts" "zoxide.nu")
}

# ══════════════════════════════════════════════════════════════════════════════
# ATUIN (histórico sincronizado)
# ══════════════════════════════════════════════════════════════════════════════

if (which atuin | is-not-empty) {
  # Atuin usa keybindings próprios no Nushell
  # Configure via: atuin init nu | save -f ~/.config/nushell/atuin.nu
}

# ══════════════════════════════════════════════════════════════════════════════
# MISE - Runtime Version Manager
# ══════════════════════════════════════════════════════════════════════════════

if (which mise | is-not-empty) {
  # Inicializar mise hook
  mise activate nu | save -f ($nu.default-config-dir | path join "scripts" "mise.nu")

  let mise_script = ($nu.default-config-dir | path join "scripts" "mise.nu")
  if ($mise_script | path exists) {
    source $mise_script
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# MENSAGEM DE BOAS-VINDAS (opcional)
# ══════════════════════════════════════════════════════════════════════════════

# Descomente para ver informações ao iniciar
# print $"(ansi cyan)Nushell(ansi reset) (version)"
# print $"Digite (ansi green)help commands(ansi reset) para ver comandos disponíveis"
