# 🚀 Dotfiles - Configuração Automatizada

Sistema completo de gerenciamento de dotfiles para **Linux**, **macOS** e **Windows**.

[![GitHub](https://img.shields.io/badge/GitHub-lucassr--dev-181717?style=flat&logo=github)](https://github.com/lucassr-dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 📋 Índice

- [Características](#-características)
- [Instalação](#-instalação)
- [Comandos](#-comandos)
- [O que Instala](#-o-que-instala)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Personalização](#-personalização)
- [Flags e Opções](#-flags-e-opções)
- [Troubleshooting](#-troubleshooting)
- [Recursos Úteis](#-recursos-úteis)
- [Contribuindo](#-contribuindo)

---

## ✨ Características

- **Cross-platform**: Linux, macOS e Windows (Git Bash)
- **Interativo**: Menus de seleção para escolher o que instalar
- **Modular**: Escolha shells, CLI tools, runtimes, apps e temas
- **Seguro**: Backups automáticos antes de qualquer alteração
- **Responsivo**: Interface adaptável ao tamanho do terminal

---

## 🚀 Instalação

### Instalação Rápida

```bash
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```

### Por Sistema Operacional

<details>
<summary><strong>🐧 Linux (Ubuntu/Debian)</strong></summary>

```bash
sudo apt-get update && sudo apt-get install -y git curl
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>🐧 Linux (Fedora/RHEL)</strong></summary>

```bash
sudo dnf install -y git curl
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>🐧 Linux (Arch)</strong></summary>

```bash
sudo pacman -Sy git curl
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>🍎 macOS</strong></summary>

```bash
# Instalar Homebrew (se não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Clonar e instalar
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>🪟 Windows (Git Bash)</strong></summary>

```bash
# 1. Instalar Git for Windows
winget install Git.Git

# 2. Abrir Git Bash e executar:
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

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
│   ├── fish/               #    Configs Fish
│   ├── zsh/                #    Configs Zsh
│   ├── nvim/               #    Configs Neovim
│   ├── tmux/               #    Configs Tmux
│   ├── vscode/             #    Configs VS Code
│   ├── git/                #    Templates Git
│   └── starship.toml       #    Preset Starship
├── linux/                  # 🐧 Específico Linux
├── macos/                  # 🍎 Específico macOS
└── windows/                # 🪟 Específico Windows
```

---

## 🔧 Personalização

### Configuração Git Multi-conta

Crie seus arquivos de configuração Git:

```bash
# Personal
cat > shared/git/.gitconfig-personal << 'EOF'
[user]
  name = Seu Nome
  email = seu@email.com
EOF

# Work (opcional)
cat > shared/git/.gitconfig-work << 'EOF'
[user]
  name = Seu Nome (Work)
  email = seu@empresa.com
EOF
```

### Chaves SSH

Coloque suas chaves SSH em `shared/.ssh/`:
- `id_ed25519` e `id_ed25519.pub` (ou outro tipo de chave)
- `config` (opcional, para múltiplas contas GitHub/GitLab)

---

## 🎛️ Flags e Opções

```bash
# Relatório detalhado pós-instalação
VERBOSE_REPORT=1 bash install.sh

# Escolher preset do Starship
STARSHIP_PRESET=catppuccin-powerline bash install.sh
```

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

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para:

1. Fazer um fork do projeto
2. Criar uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abrir um Pull Request

---

## 📜 Changelog

### 2025-01

- ✨ Banner ASCII responsivo (3 tamanhos)
- ✨ Dashboard pós-instalação em 2 colunas
- ⚡ Otimização de plugins Zsh para performance
- 🐛 Correção de variáveis não inicializadas
- 🔧 Funções helper para eliminar duplicação
- 📝 README completo e organizado

---

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Desenvolvido com ❤️ por [Lucas SR](https://lucassr.dev)**
