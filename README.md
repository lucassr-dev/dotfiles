# 🚀 Dotfiles - Configuração Automatizada

Sistema completo de gerenciamento de dotfiles para **Linux**, **macOS** e **Windows**.

Instalador interativo com menus visuais, tema **Catppuccin Mocha** unificado, e suporte a 3 shells, 19+ CLI tools, 7 ferramentas IA, e 150+ apps GUI.

---

## 📋 Índice

- [Instalação](#-instalação)
- [Comandos](#-comandos)
- [O que Instala](#-o-que-instala)
- [Configurações Incluídas](#-configurações-incluídas)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Flags e Opções](#-flags-e-opções)
- [Personalização](#-personalização)
- [Troubleshooting](#-troubleshooting)
- [Recursos Úteis](#-recursos-úteis)

---

## 🚀 Instalação

```bash
# Clonar
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config

# Executar
cd ~/.config && bash install.sh
```

> 💡 No macOS, o script instala o Homebrew automaticamente se necessário.

### Requisitos

- **bash** 4.3+
- **git** e **curl**
- Linux, macOS ou Windows (Git Bash)

---

## 💻 Comandos

```bash
bash install.sh          # 📥 Instalar (repositório → sistema)
bash install.sh export   # 📤 Exportar (sistema → repositório)
bash install.sh sync     # 🔄 Sincronizar (exporta + instala)
```

---

## ✨ O que Instala

O instalador é **interativo** — você escolhe o que instalar em cada categoria.

### 🐚 Shells & Temas

| Item | Descrição |
|------|-----------|
| **Zsh** | Shell moderno com Oh My Zsh e plugins |
| **Fish** | Shell amigável com auto-completions |
| **Nushell** | Shell estruturado com pipelines tipados |
| **Powerlevel10k** | Tema rápido e customizável para Zsh |
| **Starship** | Prompt cross-shell minimalista |
| **Oh My Posh** | Prompt cross-shell com temas ricos |

> O instalador oferece apenas temas compatíveis com o shell selecionado.

### 🛠️ CLI Tools (19+)

| Ferramenta | Descrição |
|------------|-----------|
| **fzf** | Fuzzy finder interativo |
| **zoxide** | Navegação inteligente (`z pasta`) |
| **eza** | `ls` moderno com ícones |
| **bat** | `cat` com syntax highlighting |
| **ripgrep** | `grep` ultrarrápido |
| **fd** | `find` moderno |
| **delta** | Diff bonito para Git |
| **lazygit** | TUI para Git |
| **btop** | Monitor de sistema |
| **tmux** | Multiplexador de terminal |
| **atuin** | Histórico inteligente |
| **yazi** | File manager no terminal |
| **dust** | `du` com visualização em árvore |
| **gum** | UI interativa para scripts |
| **direnv** | Variáveis de ambiente por diretório |
| **hyperfine** | Benchmark de comandos |
| **tealdeer** | `tldr` rápido em Rust |

### 🤖 Ferramentas IA (7)

| Ferramenta | Descrição |
|------------|-----------|
| **Claude Code** | Assistente de código da Anthropic |
| **Aider** | Pair programming com IA no terminal |
| **Codex** | Assistente OpenAI para terminal |
| **Continue** | Copilot open-source para IDEs |
| **Goose** | Agente autônomo de desenvolvimento |
| **Serena** | Assistente IA com contexto semântico |
| **Spec Kit** | Gerador de specs com IA |

### 🚀 Runtimes (via mise)

| Runtime | Versão | Tipo |
|---------|--------|------|
| **Node.js** | LTS | Padrão |
| **Python** | Latest | Padrão |
| **PHP** | Latest | Padrão |
| **Rust** | Stable | Opcional |
| **Go** | Latest | Opcional |
| **Bun** | Latest | Opcional |
| **Deno** | Latest | Opcional |

### 🖥️ Apps GUI (150+ por categoria)

```text
🌐 Navegadores     → Firefox, Chrome, Brave, Zen, Arc, Vivaldi
💻 Desenvolvimento → VS Code, Cursor, Docker, Postman, DBeaver
🗄️ Bancos de Dados → PostgreSQL, Redis, MySQL, MongoDB, pgAdmin
📝 Produtividade   → Slack, Notion, Obsidian, Todoist, Raycast
💬 Comunicação     → Discord, Telegram, Teams
🎵 Mídia           → VLC, Spotify, OBS Studio
🔧 Utilitários     → Bitwarden, Rectangle, AppCleaner
```

### 🔤 Nerd Fonts

Download dinâmico de 100+ fontes do GitHub releases:

- JetBrainsMono, FiraCode, Hack, Meslo, CascadiaCode, e mais...

### 🔐 Git Multi-conta

Configuração automática para alternar entre contas:

```text
~/personal/*  → usa .gitconfig-personal
~/work/*      → usa .gitconfig-work
```

---

## 🎨 Configurações Incluídas

Todas as configs usam o tema **Catppuccin Mocha** para consistência visual.

### Terminais

| Config | Formato |
|--------|---------|
| **Alacritty** | TOML (v0.13+) |
| **Kitty** | conf |
| **WezTerm** | Lua |
| **Ghostty** | config (Linux/macOS) |
| **Windows Terminal** | JSON |

### Editores

| Config | Notas |
|--------|-------|
| **Neovim** | Config completa |
| **VS Code** | settings.json + extensões |
| **Helix** | Multi-language LSP |
| **Zed** | Vim mode + AI assistant |

### CLI Tools

| Config | Notas |
|--------|-------|
| **Lazygit** | Custom commands + Catppuccin |
| **Yazi** | File manager com previews |
| **Btop** | Monitor de sistema |
| **Tmux** | Vim-style + Catppuccin |
| **Starship** | Prompt com contexto de dev |

### Package Managers

npm, pnpm, Yarn, Cargo, pip, Docker — configs otimizadas com apenas o essencial.

---

## 📁 Estrutura do Projeto

```text
.
├── install.sh              # Script principal (orquestrador)
├── lib/                    # Módulos do instalador (17 arquivos)
│   ├── ui.sh               #   Sistema de UI (fzf/gum/bash)
│   ├── banner.sh           #   Banner ASCII responsivo
│   ├── report.sh           #   Dashboard pós-instalação
│   ├── selections.sh       #   Menus de seleção interativos
│   ├── fileops.sh          #   Operações de arquivo (copy/backup/diff)
│   ├── checkpoint.sh       #   Sistema de checkpoint (resume)
│   ├── install_priority.sh #   Sistema de prioridade de instalação
│   ├── nerd_fonts.sh       #   Instalador de Nerd Fonts
│   ├── git_config.sh       #   Configuração Git multi-conta
│   ├── themes.sh           #   Temas (P10k, Starship, Oh My Posh)
│   ├── tools.sh            #   CLI tools
│   ├── runtimes.sh         #   Runtimes via mise
│   ├── gui_apps.sh         #   Instalação de apps GUI
│   ├── app_installers.sh   #   Instaladores especiais
│   ├── os_linux.sh         #   Funções específicas Linux
│   ├── os_macos.sh         #   Funções específicas macOS
│   └── os_windows.sh       #   Funções específicas Windows
├── data/                   # Catálogos
│   ├── apps.sh             #   Apps GUI por categoria
│   └── runtimes.sh         #   Runtimes disponíveis
├── shared/                 # Configs compartilhadas (cross-platform)
├── linux/                  # Configs específicas Linux
├── macos/                  # Configs específicas macOS
└── windows/                # Configs específicas Windows
```

---

## 🎛️ Flags e Opções

```bash
# Parar na primeira falha
FAIL_FAST=1 bash install.sh

# Modo dry-run (simula sem executar)
DRY_RUN=1 bash install.sh

# Desabilitar shells específicos
INSTALL_ZSH=0 bash install.sh
INSTALL_FISH=0 bash install.sh
INSTALL_NUSHELL=1 bash install.sh

# Forçar modo de UI
FORCE_UI_MODE=bash bash install.sh
```

### Prioridade de Instalação

O instalador escolhe a fonte mais atualizada para cada ferramenta.

| OS | Prioridade |
|----|------------|
| **Linux** | `official` → `cargo` → `snap` → `flatpak` → `apt` |
| **macOS** | `official` → `cargo` → `brew` |
| **Windows** | `official` → `cargo` → `winget` → `scoop` → `choco` |

```bash
# Personalizar prioridade
INSTALL_PRIORITY_LINUX="official,cargo,flatpak,snap,apt" bash install.sh
```

---

## 🔧 Personalização

### Configs Git

Crie seus arquivos de identidade Git:

```bash
# shared/git/.gitconfig-personal
[user]
  name = Seu Nome
  email = seu@email.com

# shared/git/.gitconfig-work
[user]
  name = Seu Nome (Work)
  email = seu@empresa.com
```

### SSH Keys

Coloque suas chaves SSH em `shared/.ssh/`. O instalador copia para `~/.ssh/` com permissões corretas.

Consulte `shared/.ssh.example/` para a estrutura esperada.

---

## 🚦 Troubleshooting

### Ferramentas não foram instaladas

```bash
# Instalar Rust/Cargo manualmente
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Instalar mise manualmente
curl https://mise.run | sh

# Depois execute novamente
bash install.sh
```

### Fontes não aparecem

```bash
fc-cache -fv  # Atualizar cache de fontes
# Reiniciar terminal e configurar fonte no emulador
```

### Git config não funciona

```bash
git config --show-origin user.email
ls -la ~/.gitconfig*
```

### fzf não detectado após instalação

```bash
export PATH="$HOME/.fzf/bin:$PATH"
```

---

## 📚 Recursos Úteis

| Ferramenta | Link |
|------------|------|
| Oh My Zsh | [ohmyz.sh](https://ohmyz.sh/) |
| Powerlevel10k | [github.com/romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| Starship | [starship.rs](https://starship.rs/) |
| Oh My Posh | [ohmyposh.dev](https://ohmyposh.dev/) |
| Fish Shell | [fishshell.com](https://fishshell.com/) |
| Nushell | [nushell.sh](https://www.nushell.sh/) |
| mise | [mise.jdx.dev](https://mise.jdx.dev/) |
| Catppuccin | [catppuccin.com](https://catppuccin.com/) |
| eza | [github.com/eza-community/eza](https://github.com/eza-community/eza) |
| bat | [github.com/sharkdp/bat](https://github.com/sharkdp/bat) |
| zoxide | [github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) |
| ripgrep | [github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) |
| fzf | [github.com/junegunn/fzf](https://github.com/junegunn/fzf) |
| lazygit | [github.com/jesseduffield/lazygit](https://github.com/jesseduffield/lazygit) |
| delta | [github.com/dandavison/delta](https://github.com/dandavison/delta) |
| yazi | [github.com/sxyazi/yazi](https://github.com/sxyazi/yazi) |

---

## 📜 Changelog

### 2026-02

- 🎨 **Catppuccin Mocha** como tema padrão em todas as ferramentas
- 🐚 Suporte a **Nushell** e **Oh My Posh**
- 🤖 Seção de **ferramentas IA** (Claude Code, Aider, Codex, Continue, Goose, Serena, Spec Kit)
- 🔄 Migração **Alacritty YAML → TOML** (formato v0.13+)
- 🔧 Lazygit config atualizada (propriedades deprecated removidas)
- 🧹 Configs de package managers simplificadas
- 🧹 Lista de apps auditada com descrições em todos os itens

### 2026-01

- ✨ Sistema de prioridade de instalação
- ✨ Auto-instalação do Homebrew no macOS
- 🗑️ Removido código morto de `app_installers.sh`

### 2025-01

- ✨ Banner ASCII responsivo
- ✨ Dashboard pós-instalação
- 📝 README inicial

---

**Desenvolvido com ❤️ por [Lucas SR](https://lucassr.dev)**
