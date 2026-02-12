#!/usr/bin/env bash
# shellcheck disable=SC2034
CLI_TOOLS=(
  zoxide        # cd inteligente (substitui autojump/z)
  eza           # ls moderno com cores e ícones
  bat           # cat com syntax highlighting
  ripgrep       # grep ultrarrápido (rg)
  fd            # find moderno e intuitivo
  delta         # git diff bonito com syntax highlighting
  lazygit       # TUI para Git
  gh            # GitHub CLI oficial
  jq            # Processador JSON no terminal
  direnv        # Carrega env vars por diretório
  btop          # Monitor de recursos (htop++)
  tmux          # Multiplexador de terminal
  atuin         # Histórico de shell sincronizado
  tealdeer      # tldr em Rust - man pages simplificadas
  yazi          # File manager moderno em Rust
  procs         # ps moderno com cores
  dust          # du visual e intuitivo
  sd            # sed intuitivo e moderno
  tokei         # Contador de linhas de código
  hyperfine     # Benchmarking CLI
)

IA_TOOLS=(
  claude-code  # CLI oficial do Claude (Anthropic)
  aider        # AI pair programming (25K+ GitHub stars)
  codex        # Geração de código com OpenAI Codex
  continue     # Open-source AI assistant para IDEs
  goose        # AI agent framework (Block/Square)
  spec-kit     # Spec-driven development (GitHub Spec Kit)
  serena       # Assistente de código com IA (Language Server)
)

SHELLS=(
  zsh          # Shell padrão macOS, extensível com Oh My Zsh
  fish         # User-friendly, autocomplete nativo
  nushell      # Shell moderno com dados estruturados (Rust)
)

TERMINALS=(
  ghostty              # Terminal rápido em Zig (Linux/macOS)
  kitty                # Terminal GPU-accelerated
  alacritty            # Terminal ultrarrápido em Rust
  wezterm              # Terminal Rust + Lua scripting (cross-platform)
  iterm2               # macOS only - Terminal avançado
  gnome-terminal       # Linux only - GNOME padrão
  windows-terminal     # Windows only - Terminal moderno MS
)

IDES=(
  vscode               # Visual Studio Code (Microsoft)
  cursor               # Fork do VSCode com IA integrada
  zed                  # Editor moderno e rápido (Rust)
  neovim               # Vim moderno e extensível
  helix                # Editor modal moderno (Rust, LSP built-in)
  intellij-idea        # Java IDE (JetBrains)
  pycharm              # Python IDE (JetBrains)
  webstorm             # JavaScript IDE (JetBrains)
  phpstorm             # PHP IDE (JetBrains)
  goland               # Go IDE (JetBrains)
  rubymine             # Ruby IDE (JetBrains)
  clion                # C/C++ IDE (JetBrains)
  rider                # .NET IDE (JetBrains)
  datagrip             # Database IDE (JetBrains)
  sublime-text         # Editor de texto rápido e leve
  android-studio       # IDE oficial para Android
  xcode                # macOS only - IDE oficial Apple
)

BROWSERS=(
  firefox              # Mozilla Firefox (privacidade)
  chrome               # Google Chrome (popular)
  brave                # Brave Browser (privacidade + adblock)
  arc                  # Arc Browser (produtividade, macOS/Windows)
  zen                  # Zen Browser (minimalista, fork Firefox)
  vivaldi              # Vivaldi (altamente customizável)
  edge                 # Microsoft Edge (Chromium)
  opera                # Opera Browser (VPN integrada)
  opera-gx             # Opera GX (otimizado para gamers)
)

DEV_TOOLS=(
  docker               # Containers (inclui docker-compose)
  podman               # Alternativa ao Docker sem daemon (Linux)
  postman              # Teste de APIs (REST/GraphQL)
  insomnia             # Cliente REST/GraphQL leve
  bruno                # Cliente API open-source e local
  dbeaver              # Client SQL universal
  pgadmin              # PostgreSQL admin GUI
  mongodb-compass      # MongoDB GUI oficial
  redis-insight        # Redis GUI oficial
  gitkraken            # Git GUI avançado
  sublime-merge        # Git client rápido do Sublime
  sourcetree           # Git GUI da Atlassian (macOS/Windows)
  httpie               # CLI HTTP client amigável
  ngrok                # Túneis seguros para localhost
  mkcert               # Certificados SSL locais
  k9s                  # Kubernetes TUI
  lens                 # Kubernetes IDE
)

DATABASE_APPS=(
  postgresql           # PostgreSQL - database relacional avançado
  mysql                # MySQL - database relacional popular
  mariadb              # MariaDB - fork open-source do MySQL
  redis                # Redis - cache e banco in-memory
  mongodb              # MongoDB - NoSQL document database
  sqlite               # SQLite - database embutido leve
  elasticsearch        # Elasticsearch - search engine e analytics
)

PRODUCTIVITY_APPS=(
  notion               # Workspace all-in-one
  obsidian             # Markdown notes e PKM
  logseq               # Knowledge base com graphs
  anki                 # Flashcards e memorização espaçada
  joplin               # Notes open-source com sync
  todoist              # Gerenciador de tarefas
  trello               # Boards e kanban
  clickup              # Produtividade e gestão de projetos
  linear               # Issue tracking moderno para devs
)

COMMUNICATION_APPS=(
  slack                # Comunicação de times
  discord              # Chat de comunidades e games
  telegram             # Mensageiro rápido e seguro
  whatsapp             # WhatsApp Desktop
  signal               # Mensageiro privado e criptografado
  element              # Cliente Matrix (descentralizado)
  zoom                 # Videoconferência
  teams                # Microsoft Teams
  thunderbird          # Cliente de email open-source
)

MEDIA_APPS=(
  vlc                  # Media player universal
  mpv                  # Media player minimalista e leve
  spotify              # Streaming de música
  audacity             # Editor de áudio open-source
  obs-studio           # Gravação e streaming de tela
  kdenlive             # Editor de vídeo open-source (Linux)
  davinci-resolve      # Editor de vídeo profissional
  gimp                 # Editor de imagens (alternativa ao Photoshop)
  inkscape             # Editor vetorial (alternativa ao Illustrator)
  krita                # Pintura digital e ilustração
  blender              # 3D modeling, animação e rendering
  handbrake            # Conversor de vídeo open-source
  qbittorrent          # Cliente BitTorrent open-source
)

UTILITIES_APPS=(
  flameshot            # Screenshot e anotação (Linux)
  spectacle            # Screenshot tool (Linux/KDE)
  sharex               # Windows only - Screenshot avançado

  powertoys            # Windows only - Utilitários da Microsoft
  wsl                  # Windows only - Windows Subsystem for Linux

  rectangle            # macOS only - Window manager gratuito
  alfred               # macOS only - Launcher e automação
  bartender            # macOS only - Menu bar organizer
  istat-menus          # macOS only - System monitor detalhado

  1password            # Gerenciador de senhas (premium)
  bitwarden            # Gerenciador de senhas open-source
  keepassxc            # Gerenciador de senhas offline
  syncthing            # Sincronização P2P de arquivos
  rclone               # Sync com cloud storages (CLI)
  veracrypt            # Criptografia de discos e partições
  timeshift            # Linux only - System restore/backup
  balenaetcher         # Flash de imagens USB/SD
  ventoy               # USB bootável multi-ISO
  flatpak              # Linux only - Flatpak packages
)
