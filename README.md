# 🚀 Dotfiles - Configuração Automatizada

Sistema completo de gerenciamento de dotfiles para **Linux**, **macOS** e **Windows**.

> ⚠️ **Repositório Privado** - Contém chaves SSH e configurações Git pessoais.
>
> 📦 **Versão Pública**: [github.com/lucassr-dev/dotfiles](https://github.com/lucassr-dev/dotfiles)

---

## 📋 Índice

- [Primeira Instalação](#-primeira-instalação-máquina-nova)
- [Comandos](#-comandos)
- [O que Instala](#-o-que-instala)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Flags e Opções](#-flags-e-opções)
- [Sincronizar Repo Público](#-sincronizar-repo-público)
- [Troubleshooting](#-troubleshooting)
- [Recursos Úteis](#-recursos-úteis)

---

## 🚀 Primeira Instalação (Máquina Nova)

Na primeira instalação, as chaves SSH ainda não existem no sistema. Por isso, use **HTTPS com Personal Access Token**.

### Criar Personal Access Token

1. GitHub → Settings → Developer settings → Personal access tokens → **Tokens (classic)**
2. Scope: `repo` (Full control of private repositories)
3. Copie o token gerado

### macOS

```bash
# 1. Instalar Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clonar via HTTPS
git clone https://SEU_TOKEN@github.com/lucassr-dev/.config.git ~/.config

# 3. Executar instalador
cd ~/.config && bash install.sh
```

### Linux (Ubuntu/Debian)

```bash
# 1. Instalar dependências
sudo apt-get update && sudo apt-get install -y git curl

# 2. Clonar via HTTPS
git clone https://SEU_TOKEN@github.com/lucassr-dev/.config.git ~/.config

# 3. Executar instalador
cd ~/.config && bash install.sh
```

### Windows (Git Bash)

```bash
# 1. Instalar Git for Windows
winget install Git.Git

# 2. Abrir Git Bash e clonar
git clone https://SEU_TOKEN@github.com/lucassr-dev/.config.git ~/.config

# 3. Executar instalador
cd ~/.config && bash install.sh
```

### 📝 Instalações Subsequentes

Após a primeira instalação, as chaves SSH estarão configuradas:

```bash
git clone git@github.com-lucassr-dev:lucassr-dev/.config.git ~/.config
cd ~/.config && bash install.sh
```

---

## 💻 Comandos

```bash
bash install.sh          # 📥 Instalar (repositório → sistema)
bash install.sh export   # 📤 Exportar (sistema → repositório)
bash install.sh sync     # 🔄 Sincronizar (exporta + instala)
bash install.sh help     # ❓ Mostrar ajuda
```

---

## ✨ O que Instala

O instalador é **interativo** - você escolhe o que instalar em cada categoria.

### 🐚 Shells & Temas

| Item | Descrição |
|------|-----------|
| **Zsh** | Shell moderno com Oh My Zsh |
| **Fish** | Shell amigável com auto-completions |
| **Powerlevel10k** | Tema rápido e customizável para Zsh |
| **Starship** | Prompt cross-shell minimalista |

### 🛠️ CLI Tools

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

### 🚀 Runtimes (via mise)

| Runtime | Versão |
|---------|--------|
| **Node.js** | LTS |
| **Python** | Latest |
| **PHP** | Latest |
| **Rust** | Stable |
| **Go** | Latest |

### 🖥️ Apps GUI (por categoria)

```
🌐 Navegadores     → Firefox, Chrome, Brave, Zen
💻 Desenvolvimento → VS Code, Docker, Postman, DBeaver
🗄️ Bancos de Dados → PostgreSQL, Redis, MySQL, pgAdmin
📝 Produtividade   → Slack, Notion, Obsidian
💬 Comunicação     → Discord
🎵 Mídia           → VLC, Spotify
```

### 🔤 Nerd Fonts

Fontes baixadas dinamicamente da release oficial:
- FiraCode
- JetBrainsMono
- Hack
- Meslo
- CascadiaCode
- E mais...

### 🔐 Git Multi-conta

Configuração automática para alternar entre contas:

```
~/personal/*  → usa .gitconfig-personal
~/work/*      → usa .gitconfig-work
```

---

## 📁 Estrutura do Projeto

```
.
├── install.sh              # 🎯 Script principal (orquestrador)
├── lib/                    # 📚 Módulos do instalador
│   ├── banner.sh           #    Banner responsivo
│   ├── report.sh           #    Dashboard pós-instalação
│   ├── selections.sh       #    Menus de seleção
│   ├── nerd_fonts.sh       #    Instalador de fontes
│   ├── git_config.sh       #    Configuração Git
│   ├── themes.sh           #    Temas (P10k, OMZ)
│   ├── os_linux.sh         #    Funções Linux
│   ├── os_macos.sh         #    Funções macOS
│   └── os_windows.sh       #    Funções Windows
├── data/                   # 📦 Catálogos
│   ├── apps.sh             #    Apps GUI por categoria
│   └── runtimes.sh         #    Runtimes disponíveis
├── shared/                 # 🔗 Configs compartilhadas
│   ├── .ssh/               #    🔑 Chaves SSH (PRIVADO!)
│   ├── git/                #    Configs Git
│   ├── fish/               #    Configs Fish
│   ├── zsh/                #    Configs Zsh
│   ├── nvim/               #    Configs Neovim
│   ├── tmux/               #    Configs Tmux
│   ├── vscode/             #    Configs VS Code
│   └── starship.toml       #    Preset Starship
├── linux/                  # 🐧 Específico Linux
├── macos/                  # 🍎 Específico macOS
├── windows/                # 🪟 Específico Windows
└── scripts/                # 🔧 Utilitários
    └── sync_public.sh      #    Sync para repo público
```

---

## 🎛️ Flags e Opções

```bash
# Relatório detalhado pós-instalação
VERBOSE_REPORT=1 bash install.sh

# Escolher preset do Starship
STARSHIP_PRESET=catppuccin-powerline bash install.sh
```

---

## 🔄 Sincronizar Repo Público

O repo público não contém dados sensíveis (SSH, configs pessoais).

```bash
# Sincronizar
bash scripts/sync_public.sh

# Ou especificar diretório
DOTFILES_PUBLIC_DIR="/caminho/para/dotfiles" bash scripts/sync_public.sh
```

**Arquivos excluídos automaticamente:**
- `shared/.ssh/` (chaves privadas)
- `shared/git/.gitconfig-personal`
- `shared/git/.gitconfig-work`
- `scripts/sync_public.sh`

---

## 🚦 Troubleshooting

### Erro: "Ferramentas não foram instaladas"

O script tenta instalar dependências automaticamente. Se falhar:

```bash
# Rust/Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# mise (para runtimes)
curl https://mise.run | sh

# Depois execute novamente
bash install.sh
```

### Erro: "Fontes não aparecem"

```bash
# Atualizar cache de fontes
fc-cache -fv

# Reiniciar terminal e configurar fonte no emulador
```

### Erro: "Git config não funciona"

```bash
# Verificar origem do config
git config --show-origin user.email

# Verificar arquivos
ls -la ~/.gitconfig*
```

### Validar starship.toml

```bash
STARSHIP_CONFIG="shared/starship.toml" starship print-config
```

---

## 📚 Recursos Úteis

### Documentação Oficial

| Ferramenta | Link |
|------------|------|
| Oh My Zsh | [ohmyz.sh](https://ohmyz.sh/) |
| Powerlevel10k | [github.com/romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| Starship | [starship.rs](https://starship.rs/) |
| Fish Shell | [fishshell.com](https://fishshell.com/) |
| Atuin | [atuin.sh](https://atuin.sh/) |
| mise | [mise.jdx.dev](https://mise.jdx.dev/) |

### CLI Tools

| Ferramenta | Link |
|------------|------|
| eza | [github.com/eza-community/eza](https://github.com/eza-community/eza) |
| bat | [github.com/sharkdp/bat](https://github.com/sharkdp/bat) |
| zoxide | [github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) |
| ripgrep | [github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) |
| fzf | [github.com/junegunn/fzf](https://github.com/junegunn/fzf) |
| lazygit | [github.com/jesseduffield/lazygit](https://github.com/jesseduffield/lazygit) |
| delta | [github.com/dandavison/delta](https://github.com/dandavison/delta) |

---

## 🔑 Segurança

> ⚠️ **NUNCA** commite este repo como público - contém chaves privadas!

- Chaves SSH em `shared/.ssh/`
- Configs Git com dados pessoais em `shared/git/`
- Use o repo público para compartilhar: [lucassr-dev/dotfiles](https://github.com/lucassr-dev/dotfiles)

---

## 📜 Changelog

### 2025-01

- ✨ Banner ASCII responsivo (3 tamanhos)
- ✨ Dashboard pós-instalação em 2 colunas
- 🐛 Correção de variáveis não inicializadas
- 🔧 Funções helper para eliminar duplicação
- 📝 README completo e organizado

---

**Desenvolvido com ❤️ por [Lucas SR](https://lucassr.dev)**
