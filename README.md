# 🚀 Dotfiles

[![Validate](https://github.com/lucassr-dev/dotfiles/actions/workflows/validate.yml/badge.svg)](https://github.com/lucassr-dev/dotfiles/actions/workflows/validate.yml)
![Linux](https://img.shields.io/badge/Linux-apt%20%7C%20dnf%20%7C%20pacman-FCC624?logo=linux&logoColor=black)
![macOS](https://img.shields.io/badge/macOS-Homebrew-000000?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-winget%20%7C%20scoop-0078D4?logo=windows&logoColor=white)
![Shell](https://img.shields.io/badge/bash-4.0%2B-4EAA25?logo=gnubash&logoColor=white)

Um instalador que monta uma máquina de desenvolvimento inteira — shells, editores,
runtimes, ferramentas de linha de comando e apps — a partir de um comando, nos três
sistemas operacionais.

Ele pergunta o que você quer antes de instalar qualquer coisa, sabe retomar de onde
parou se for interrompido, e faz backup do que for sobrescrever.

```bash
git clone https://github.com/lucassr-dev/dotfiles.git ~/.config
cd ~/.config && bash install.sh
```

> Quer só olhar antes? `DRY_RUN=1 bash install.sh` mostra tudo que aconteceria
> sem escrever um único arquivo.

---

## 📋 Índice

- [Instalação](#-instalação)
- [Comandos](#-comandos)
- [Temas](#-temas)
- [Neovim](#-neovim)
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

Fora do instalador:

```bash
bash scripts/set_theme.sh              # 🎨 tema de 8 ferramentas de uma vez
bash scripts/verify_nvim.sh            # ✅ 16 critérios de aceite do Neovim
```

Qualquer um deles aceita `DRY_RUN=1` para simular sem escrever nada.

---

## 🎨 Temas

Um comando troca o tema de **oito ferramentas de terminal ao mesmo tempo** — as que
escolhem tema por nome, as que precisam de paleta em hex, e as que usam variáveis
próprias.

```bash
bash scripts/set_theme.sh                 # mostra os temas e o que está ativo agora
bash scripts/set_theme.sh tokyo-night     # aplica
```

| Tema | Paleta |
|---|---|
| `catppuccin-mocha` | `#1e1e2e` base, `#cdd6f4` texto, `#cba6f7` destaque |
| `tokyo-night` | `#1a1b26` base, `#c0caf5` texto, `#bb9af7` destaque |
| `gruvbox-dark` | `#282828` base, `#ebdbb2` texto, `#b16286` destaque |

<details>
<summary><b>Como funciona por dentro</b></summary>

Cada arquivo de configuração tem uma região demarcada por marcadores:

```
# >>> tema:cores inicio (gerenciado por scripts/set_theme.sh) >>>
...
# <<< tema:cores fim <<<
```

O script reescreve **só o interior** dessas regiões, preservando o resto do arquivo.
Isso significa que você pode editar tudo à vontade fora dos marcadores.

Garantias verificadas a cada mudança:

- **Reversível** — aplicar A → B → A devolve os arquivos byte a byte ao original
- **Idempotente** — aplicar o mesmo tema duas vezes não escreve nada na segunda
- **Nunca parcial** — se uma ferramenta não puder ser atualizada, o script avisa e
  não toca em nenhuma

Ferramentas cobertas: ghostty, bat, delta, starship, lazygit, fish (`FZF_DEFAULT_OPTS`),
tmux e Neovim. O `yazi` fica fixo em Catppuccin — ainda não tem marcador.

Alguns temas precisam de um arquivo baixado para funcionar (o Tokyo Night no `bat`, por
exemplo). O script instala o que falta e avisa quando não consegue, em vez de gravar um
nome de tema que a ferramenta vai ignorar em silêncio.

</details>

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

### 🛠️ CLI Tools (32)

<details open>
<summary>As 32 ferramentas</summary>

| Ferramenta | Descrição |
|---|---|
| `zoxide` | cd inteligente (substitui autojump/z) |
| `eza` | ls moderno com cores e ícones |
| `bat` | cat com syntax highlighting |
| `ripgrep` | grep ultrarrápido (rg) |
| `fd` | find moderno e intuitivo |
| `delta` | git diff bonito com syntax highlighting |
| `lazygit` | TUI para Git |
| `gh` | GitHub CLI oficial |
| `jq` | Processador JSON no terminal |
| `direnv` | Carrega env vars por diretório |
| `btop` | Monitor de recursos (htop++) |
| `tmux` | Multiplexador de terminal |
| `atuin` | Histórico de shell sincronizado |
| `tealdeer` | tldr em Rust - man pages simplificadas |
| `yazi` | File manager moderno em Rust |
| `procs` | ps moderno com cores |
| `dust` | du visual e intuitivo |
| `sd` | sed intuitivo e moderno |
| `tokei` | Contador de linhas de código |
| `hyperfine` | Benchmarking CLI |
| `mise` | Runtime version manager (node, python, ruby...) |
| `bottom` | Monitor de sistema TUI em Rust |
| `duf` | Visualizador de uso de disco moderno |
| `gping` | Ping com gráfico em tempo real |
| `difftastic` | Diff estrutural que entende a linguagem |
| `zellij` | Multiplexador de terminal moderno |
| `xh` | Cliente HTTP moderno (alternativa ao curl) |
| `gitui` | Interface Git TUI rápida em Rust |
| `broot` | Navegador de árvore interativo |
| `glow` | Renderizador de Markdown no terminal |
| `navi` | Cheatsheets interativos (cargo/brew) |
| `topgrade` | Atualiza tudo (pkgs/rust/mise/brew/...) de uma vez |
</details>

### 🤖 Ferramentas IA (9)

<details>
<summary>As 9 ferramentas</summary>

| Ferramenta | Descrição |
|---|---|
| `claude-code` | CLI oficial do Claude (Anthropic) |
| `aider` | AI pair programming (25K+ GitHub stars) |
| `codex` | Codex CLI da OpenAI (assistente no terminal) |
| `continue` | Open-source AI assistant para IDEs |
| `goose` | AI agent framework (Block/Square) |
| `spec-kit` | Spec-driven development (GitHub Spec Kit) |
| `serena` | Assistente de código com IA (Language Server) |
| `ollama` | Runtime LLM local (modelos open-source) |
| `promptfoo` | Framework de eval/testing para LLMs |
</details>

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

### 🖥️ Apps GUI (104, por categoria)

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

## ⌨️ Neovim

A configuração de Neovim é baseada em **LazyVim**, afinada para desenvolvimento
frontend e fullstack com TypeScript.

| | |
|---|---|
| Neovim | `0.12.5`, instalado via mise |
| LazyVim | `16.0.1` |
| Plugins | 63 |
| Extras | 25, declarados em `lazyvim.json` |
| Startup | ~50 ms (mediana de 11 execuções) |

<details>
<summary><b>O que foi escolhido, e por quê</b></summary>

- **`vtsls`** no lugar do `ts_ls` — é o servidor que o próprio LazyVim passou a
  recomendar, com melhor suporte a monorepo e inlay hints
- **`snacks.nvim`** para picker, explorer, dashboard, indent e scroll — substituiu
  telescope, neo-tree, dashboard-nvim e indent-blankline, quatro plugins por um
- **`blink.cmp`** no lugar do `nvim-cmp` — completion em Rust, mais rápida
- **`;` como prefixo de busca** — `;f` arquivos, `;r` grep, `;b` buffers, `;s`
  símbolos. Fica na home row, diferente de `<leader>f`

Uma verificação automatizada trava 16 critérios: startup sem erro, teto de plugins,
tempo de startup, quais LSPs anexam num `.tsx`, atalhos críticos que não podem sumir,
e se a configuração do repositório está idêntica à do sistema.

```bash
bash scripts/verify_nvim.sh
```

</details>

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

### 2026-09

- **Temas entre ferramentas** — um comando aplica catppuccin-mocha, tokyo-night ou
  gruvbox-dark a oito ferramentas de terminal, com catálogo declarativo e marcadores
  nos arquivos de configuração
- **Neovim modernizado** — LSP corrigido em `.tsx`, migração para snacks e blink.cmp,
  63 plugins, 16 critérios de aceite automatizados
- **`DRY_RUN` de verdade** — passou a valer também para operações de usuário
  (`cargo install`, `git clone`, escrita no `.zshrc`), não só para as que pedem sudo
- **Barreira de credencial no export** — material secreto só é copiado para caminhos
  que o espelho público exclui
- **btop de pacote nativo** — em vez de snap ou flatpak, que não conseguem ler
  `~/.config` e faziam a configuração ser ignorada em silêncio
- `lib/themes.sh` dividido em preview, seleção e instalação

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
