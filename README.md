# Dotfiles Installer

Um instalador interativo e cross-platform para configurar seu ambiente de desenvolvimento completo.

## Características

- **Cross-platform**: Linux, macOS e Windows (Git Bash)
- **Interativo**: Menus de seleção para escolher o que instalar
- **Modular**: Escolha shells, CLI tools, runtimes, apps e temas
- **Seguro**: Backups automáticos antes de qualquer alteração
- **Responsivo**: Interface adaptável ao tamanho do terminal

## O que instala

| Categoria | Itens |
|-----------|-------|
| **Shells** | Zsh, Fish, Bash configs |
| **Temas** | Powerlevel10k, Oh My Zsh, Starship |
| **CLI Tools** | fzf, zoxide, bat, ripgrep, fd, delta, lazygit, btop, etc. |
| **Runtimes** | Node.js, Python, PHP, Rust, Go (via mise) |
| **Editores** | Neovim, VS Code |
| **Apps GUI** | Seleção interativa por categoria |
| **Fontes** | Nerd Fonts (FiraCode, JetBrainsMono, etc.) |
| **Git** | Configuração multi-conta (personal/work) |

## Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config

# 2. Execute o instalador
cd ~/.config
bash install.sh
```

### Primeira instalação por OS

<details>
<summary><strong>Linux (Ubuntu/Debian)</strong></summary>

```bash
sudo apt-get update && sudo apt-get install -y git curl
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>Linux (Fedora/RHEL)</strong></summary>

```bash
sudo dnf install -y git curl
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>Linux (Arch)</strong></summary>

```bash
sudo pacman -Sy git curl
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>macOS</strong></summary>

```bash
# Instalar Homebrew primeiro (se não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Clonar e instalar
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

<details>
<summary><strong>Windows</strong></summary>

```bash
# 1. Instalar Git for Windows
winget install Git.Git

# 2. Abrir Git Bash e executar:
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```
</details>

## Comandos

```bash
bash install.sh          # Instala (repositório → sistema)
bash install.sh export   # Exporta configs (sistema → repositório)
bash install.sh sync     # Exporta + Instala
bash install.sh help     # Mostra ajuda
```

## Estrutura do Projeto

```
.
├── install.sh           # Script principal (orquestrador)
├── lib/                 # Módulos do instalador
│   ├── banner.sh        # Banner responsivo
│   ├── report.sh        # Dashboard pós-instalação
│   ├── nerd_fonts.sh    # Instalador de fontes
│   └── ...
├── data/                # Catálogos de apps e runtimes
├── shared/              # Configs compartilhadas entre OS
│   ├── fish/            # Configurações Fish
│   ├── zsh/             # Configurações Zsh
│   ├── nvim/            # Configurações Neovim
│   ├── tmux/            # Configurações Tmux
│   ├── vscode/          # Configurações VS Code
│   ├── git/             # Templates de configuração Git
│   └── starship.toml    # Configuração Starship
├── linux/               # Configs específicas Linux
├── macos/               # Configs específicas macOS
└── windows/             # Configs específicas Windows
```

## Personalização

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
- `config` (opcional, para múltiplas contas)

## Screenshots

O instalador inclui:
- Banner ASCII responsivo (adapta ao tamanho do terminal)
- Menus interativos com seleção múltipla
- Dashboard pós-instalação com resumo do que foi instalado

## Observações

- Backups automáticos em `~/.dotfiles-backup-YYYYMMDD-HHMMSS`
- Relatório detalhado: `VERBOSE_REPORT=1 bash install.sh`
- O instalador detecta automaticamente o OS e ajusta as instalações

## Licença

MIT

## Autor

**Lucas SR** - [lucassr.dev](https://lucassr.dev)

[![GitHub](https://img.shields.io/badge/GitHub-lucassr--dev-181717?style=flat&logo=github)](https://github.com/lucassr-dev)
