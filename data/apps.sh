#!/usr/bin/env bash
# shellcheck disable=SC2034
CLI_TOOLS=(
  zoxide        # cd inteligente (substitui autojump/z)
  eza           # ls moderno com cores e ícones
  bat           # cat com syntax highlighting
  ripgrep       # grep ultrarrápido (rg)
  fd            # find moderno
  delta         # git diff bonito
  lazygit       # TUI para Git
  gh            # GitHub CLI oficial
  jq            # Processador JSON
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
  spec-kit     # Spec-driven development (GitHub Spec Kit)
  serena       # Assistente de código baseado em IA
  codex        # Geração de código com OpenAI Codex
  claude-code  # CLI oficial do Claude (Anthropic)
  aider        # AI pair programming (25K+ GitHub stars)
  continue     # Open-source AI assistant IDE
  goose        # AI agent framework (Block/Square)
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
  zed                  # Editor moderno e rápido (Rust)
  cursor               # Fork do VSCode com IA integrada
  neovim               # Vim moderno e extensível
  helix                # Editor modal moderno (Rust, LSP built-in)
  intellij-idea        # Java IDE (JetBrains) - Community/Ultimate
  pycharm              # Python IDE (JetBrains) - Community/Ultimate
  webstorm             # JavaScript IDE (JetBrains)
  phpstorm             # PHP IDE (JetBrains)
  goland               # Go IDE (JetBrains)
  rubymine             # Ruby IDE (JetBrains)
  clion                # C/C++ IDE (JetBrains)
  rider                # .NET IDE (JetBrains)
  datagrip             # Database IDE (JetBrains)
  sublime-text         # Editor de texto rápido
  android-studio       # IDE oficial para Android
  xcode                # macOS only - IDE oficial Apple
)

BROWSERS=(
  firefox              # Mozilla Firefox
  chrome               # Google Chrome
  brave                # Brave (privacidade + crypto)
  arc                  # Arc Browser (macOS/Windows)
  zen                  # Zen Browser (fork do Firefox)
  vivaldi              # Vivaldi (customizável)
  edge                 # Microsoft Edge (Chromium)
  opera                # Opera Browser
  opera-gx             # Opera GX (para gamers)
  librewolf            # Firefox com foco em privacidade
  waterfox             # Firefox fork com privacidade
  min                  # Navegador minimalista
  floorp               # Firefox fork japonês customizável
)

DEV_TOOLS=(
  docker               # Containers (inclui docker-compose)
  podman               # Alternativa ao Docker (Linux)
  postman              # Teste de APIs (REST/GraphQL)
  insomnia             # Cliente REST/GraphQL
  bruno                # Cliente API open-source
  dbeaver              # Client SQL universal
  pgadmin              # PostgreSQL admin GUI
  mongodb-compass      # MongoDB GUI oficial
  redis-insight        # Redis GUI oficial
  gitkraken            # Git GUI avançado
  sublime-merge        # Git client do Sublime
  sourcetree           # Git GUI da Atlassian (macOS/Windows)
  httpie               # CLI HTTP client amigável
  ngrok                # Túneis seguros para localhost
  localtunnel          # Alternativa ao ngrok
  mkcert               # Certificados SSL locais
  earthly              # Build automation
  k9s                  # Kubernetes TUI
  lens                 # Kubernetes IDE
)

DATABASE_APPS=(
  postgresql           # PostgreSQL database
  mysql                # MySQL database
  mariadb              # Fork do MySQL
  redis                # Cache e banco in-memory
  mongodb              # NoSQL document database
  cassandra            # NoSQL distributed database
  cockroachdb          # Database distribuído (Postgres-compatible)
  sqlite               # Database embutido
  influxdb             # Time-series database
  elasticsearch        # Search engine e analytics
  neo4j                # Graph database
)

PRODUCTIVITY_APPS=(
  notion               # Workspace all-in-one
  obsidian             # Markdown notes e PKM
  logseq               # Knowledge base com graphs
  anki                 # Flashcards e memorização
  joplin               # Notes open-source
  todoist              # Gerenciador de tarefas
  trello               # Boards e kanban
  clickup              # Produtividade e projetos
  linear               # Issue tracking moderno
  focalboard           # Alternativa open-source ao Trello
  anytype              # Notion open-source
  appflowy             # Notion/Linear open-source
  standard-notes       # Notes criptografadas
  trilium              # Hierarchical notes
)

COMMUNICATION_APPS=(
  slack                # Comunicação de times
  discord              # Chat de comunidades/games
  telegram             # Mensageiro rápido e seguro
  whatsapp             # WhatsApp Desktop
  signal               # Mensageiro privado e criptografado
  element              # Cliente Matrix (descentralizado)
  zoom                 # Videoconferência
  teams                # Microsoft Teams
  skype                # Skype (legado)
  gather               # Espaços virtuais interativos
  thunderbird          # Cliente de email open-source
  mailspring           # Cliente de email moderno
  rambox               # Agregador de mensageiros
  franz                # Agregador de mensageiros
  ferdium              # Fork do Ferdi (agregador)
)

MEDIA_APPS=(
  vlc                  # Media player universal
  mpv                  # Media player minimalista
  spotify              # Streaming de música
  audacity             # Editor de áudio open-source
  obs-studio           # Gravação e streaming
  kdenlive             # Editor de vídeo (Linux)
  davinci-resolve      # Editor de vídeo profissional
  gimp                 # Editor de imagens (Photoshop alternative)
  inkscape             # Editor vetorial (Illustrator alternative)
  krita                # Pintura digital
  blender              # 3D modeling e animação
  handbrake            # Conversor de vídeo
  transmission         # Cliente BitTorrent (macOS/Linux)
  qbittorrent          # Cliente BitTorrent
  jellyfin             # Media server open-source
  plex                 # Media server
  calibre              # Gerenciador de e-books
)

UTILITIES_APPS=(
  flameshot            # Screenshot tool (Linux)
  spectacle            # Screenshot tool (Linux/KDE)
  screenkey            # Mostra teclas pressionadas (Linux)
  ksnip                # Screenshot cross-platform
  sharex               # Windows only - Screenshot avançado

  powertoys            # Windows only - Utilitários da Microsoft
  wsl                  # Windows only - Windows Subsystem for Linux

  rectangle            # macOS only - Window manager
  alfred               # macOS only - Launcher avançado
  bartender            # macOS only - Menu bar organizer
  cleanmymac           # macOS only - System cleaner
  istat-menus          # macOS only - System monitor

  1password            # Gerenciador de senhas
  bitwarden            # Gerenciador de senhas open-source
  keepassxc            # Gerenciador de senhas offline
  syncthing            # Sincronização P2P de arquivos
  rclone               # Sync com cloud storages (CLI)
  veracrypt            # Criptografia de discos
  timeshift            # Linux only - System restore
  balenaetcher         # Flash de imagens USB
  ventoy               # USB bootável multi-ISO
  bleachbit            # System cleaner (Linux/Windows)
  stacer               # Linux only - System optimizer
  appimage-launcher    # Linux only - AppImage integration
  snapcraft            # Linux only - Snap packages manager
  flatpak              # Linux only - Flatpak packages
)
