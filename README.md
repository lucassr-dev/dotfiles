# 🚀 Dotfiles - Sistema de Configuração Automatizada

Sistema completo e moderno de gerenciamento de dotfiles para Linux, macOS, Windows e WSL2.

## 📋 Índice

- [Instalação Rápida](#instalação-rápida)
- [Comandos Disponíveis](#comandos-disponíveis)
- [✨ Novidades 2025](#-novidades-2025)
- [O que está Incluído](#o-que-está-incluído)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Workflow Recomendado](#workflow-recomendado)
- [Customização](#customização)
- [Alternância Automática de Contas Git](#-alternância-automática-de-contas-git)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)

---

## ⚡ Instalação Rápida

### 1. Clone o repositório

```bash
git clone https://github.com/lucassr-dev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 2. Execute o instalador

```bash
bash install.sh
```

Flags úteis (opcionais):

```bash
# Relatório pós-instalação detalhado (listas completas)
VERBOSE_REPORT=1 bash install.sh
```

O script irá, de forma interativa:
- ✅ Detectar seu sistema operacional (Linux, macOS, Windows, WSL2)
- ✅ Perguntar sobre dependências base e Nerd Fonts
- ✅ Selecionar shells, temas e plugins
- ✅ Selecionar CLI Tools, IA Tools e terminais
- ✅ **Perguntar quais apps GUI você deseja instalar** (por categoria)
- ✅ Selecionar extensões do VS Code (opcional, via `shared/vscode/extensions.txt`)
- ✅ Configurar Git multi-conta (opcional)
- ✅ Instalar runtimes via mise (opcional)
- ✅ Revisar seleções e editar antes de instalar
- ✅ Copiar configs com backup e aplicar presets/temas selecionados
- ✅ Instalar apps via Brewfile (macOS, **opcional**)

### 3. Reinicie o terminal

```bash
exec $SHELL
```

---

## 💻 Comandos Disponíveis

```bash
# Instalar configs (repositório → sistema) - Primeira vez
bash install.sh

# Exportar configs atuais (sistema → repositório) - Salvar mudanças
bash install.sh export

# Sincronizar bidirecional (exporta + instala)
bash install.sh sync

# Mostrar ajuda
bash install.sh help
```

## ✨ Novidades 2025

### 🎯 Seleção Interativa de Apps GUI

**Antes:** Script instalava 15+ apps automaticamente (30+ min, GBs de dados)

**Agora:** Você escolhe o que instalar!

Durante a instalação, o script pergunta categoria por categoria:

```
════════════════════════════════════════════════════════════
  🖥️  SELEÇÃO DE APLICATIVOS GUI
════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌐 NAVEGADORES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) firefox
  2) chrome
  3) brave
  4) zen
  a) Todos
  (Enter para nenhum)
  Selecione números separados por vírgula ou 'a': 2,3

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  💻 FERRAMENTAS DE DESENVOLVIMENTO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) vscode
  2) docker
  3) postman
  4) dbeaver
  a) Todos
  (Enter para nenhum)
  Selecione números separados por vírgula ou 'a': 1,4
```

**Categorias disponíveis:**
- 💡 **IDEs**: VS Code, Zed, IntelliJ (PHPStorm/WebStorm/PyCharm), Cursor, Xcode (macOS)
- 🌐 **Navegadores**: Firefox, Google Chrome, Brave, Zen, Arc (macOS/Windows)
- 💻 **Desenvolvimento**: Docker, Postman, DBeaver, etc.
- 🗄️ **Bancos de Dados**: PostgreSQL, Redis, MySQL, pgAdmin, MongoDB/Compass
- 📝 **Produtividade**: Slack, Notion, Obsidian
- 💬 **Comunicação**: Discord
- 🎵 **Mídia**: VLC, Spotify
- 🛠️ **Utilitários**: Screenshot tools, Keyboard visualizers
- 🍺 **Brewfile** (macOS): Arc, iTerm2, Raycast, Rectangle, etc.

**Funciona em:** Linux (apt/snap/flatpak), macOS (brew), Windows (winget/chocolatey)

### 🛠️ Seleção de CLI Tools e IA Tools

Agora você escolhe quais ferramentas CLI e IA instalar:
- **CLI Tools**: fzf, zoxide, eza, bat, ripgrep, fd, delta, lazygit, gh, jq, direnv, btop, tmux, starship, atuin.
- **IA Tools**: spec-kit, serena, codex, claude-code.

### 🔤 Nerd Fonts sob demanda

As fontes não ficam mais no repositório. O instalador baixa as fontes da **release oficial** do Nerd Fonts e instala apenas o que você selecionar.

### 🔐 Atuin - Histórico de Comandos Inteligente

**Disponível na seleção de CLI Tools** (opcional) usando [Atuin](https://github.com/atuinsh/atuin).

Atuin substitui o histórico padrão do shell com:
- ✅ Sincronização entre máquinas (opcional)
- ✅ Busca full-text no histórico
- ✅ Estatísticas de uso de comandos
- ✅ Contexto completo (diretório, status de saída, duração)
- ✅ Criptografia end-to-end

**Como usar:**

```bash
# Criar conta e sincronizar (opcional)
atuin register

# Ou fazer login se já tem conta
atuin login

# Buscar histórico
# Pressione Ctrl+R (Zsh) ou Ctrl+R (Fish) e comece a digitar
```

**Integrado com:** Zsh e Fish (quando instalado)

### 🎨 Starship com preset Catppuccin Powerline

- O script aplica o preset selecionado durante a instalação.
- Para trocar depois:
  - `starship preset <preset> -o ~/.config/starship.toml`
  - ou edite `~/.config/starship.toml`

### 📋 Relatório final compacto

- O relatório final abre em tela limpa e foca nas versões instaladas e no backup criado.
- Erros críticos/opcionais aparecem apenas quando ocorrem.
- Para listas completas, use `VERBOSE_REPORT=1`.

### 🛡️ Fail-Fast e Resumo Final

- Passos críticos (gerenciadores de pacotes, shells, Oh My Zsh, starship/tmux/nvim/git, cópia de configs) param o script e retornam exit code 1.
- Passos opcionais (apps GUI, CLI/IA Tools, Brewfile, etc.) geram avisos, mas o script continua.
- Ao final, o script imprime um resumo das falhas críticas/opcionais e o exit code reflete o estado final.

### 🌍 Suporte Aprimorado para WSL2

**Novo:** Detecção automática de WSL2 com otimizações específicas!

```bash
ℹ️  WSL2 detectado - usando configurações Linux com ajustes para Windows
```

**O que muda no WSL2:**
- ✅ Detecção automática via `/proc/version`
- ✅ Usa gerenciadores de pacotes Linux (apt, etc.)
- ✅ Configurações de terminal adaptadas
- ✅ Suporte a `wslpath` para conversão de caminhos do Windows

### ⚡ Instalação 10x Mais Rápida

**Novo:** Todos os repositórios Git usam shallow clones (`--depth=1`)!

**Antes:**
```bash
git clone https://github.com/romkatv/powerlevel10k.git  # ~50MB, 30s
```

**Agora:**
```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git  # ~5MB, 3s
```

**Resultado:** Instalação de plugins Zsh é 10x mais rápida! 🚀

### 🔧 Spec-Kit (IA Tools)

**Opcional:** disponível na seleção de IA Tools.

```bash
▶ spec-kit (Spec-Driven Development) selecionado
  📚 Toolkit do GitHub para desenvolvimento guiado por especificações
  🤖 Integra com Claude para gerar specs e implementações
```

**Se já estiver instalado:**
```bash
ℹ️  spec-kit já instalado: <versão>
💡 Para atualizar: uv tool upgrade specify-cli
```

### 💾 Backup Aprimorado

**Novo:** Backups preservam symlinks, permissions e timestamps!

```bash
# Usa cp -a em vez de cp -R
cp -a ~/.zshrc ~/.dotfiles-backup-20251217/
```

**Resultado:** Backups perfeitos, restauração 100% fiel! 🎯

---

## 🛠️ O que está Incluído

Tudo abaixo é **opcional e selecionável** durante a execução (quando aplicável ao OS).

### Shells e Prompts

| Ferramenta | Descrição |
|------------|-----------|
| **Zsh** | Shell avançado (selecionável) com Oh My Zsh + Powerlevel10k, Starship ou Oh My Posh |
| **Fish** | Shell moderno (selecionável) com Starship ou Oh My Posh |
| **Plugins Zsh** | seleção de plugins built-in e externos (ex: autosuggestions, syntax-highlighting) |

### 📦 Catálogo de Apps e Tools (resumo)

**Lista completa:** veja `data/apps.sh`.

- **CLI Tools**: fzf, zoxide, eza, bat, ripgrep, fd, delta, lazygit, gh, jq, direnv, btop, tmux, starship, atuin.
- **IA Tools**: spec-kit, serena, codex, claude-code.
- **Terminais**: ghostty, kitty, alacritty, iterm2, gnome-terminal, windows-terminal.
- **IDEs**: vscode, zed, cursor, intellij-idea, pycharm, webstorm, phpstorm, goland, rubymine, clion, rider, datagrip, android-studio, xcode.
- **Navegadores**: firefox, chrome, brave, arc, zen, vivaldi, edge, opera.
- **Dev Tools**: docker, podman, postman, insomnia, dbeaver, pgadmin, mongodb-compass, redis-insight.
- **Bancos de Dados**: postgresql, mysql, mariadb, redis, mongodb, sqlite, neo4j.
- **Produtividade**: notion, obsidian, logseq, todoist, trello, clickup.
- **Comunicação**: slack, discord, whatsapp, telegram, teams, zoom.
- **Mídia**: vlc, spotify, obs-studio, gimp, inkscape.
- **Utilitários**: flameshot, screenkey, ksnip, sharex, powertoys, rectangle, bitwarden, syncthing, rclone.

### Terminais

- **Linux**: Ghostty (múltiplos métodos por distro, quando selecionado)
  - Ubuntu/derivados: via script mkasberg
  - Debian: via repositório griffo.io
  - Arch/Manjaro: via pacman
  - Fedora/RHEL: via snap
  - openSUSE: via zypper
  - Fallback: Flatpak ou Snap
- **macOS**: Ghostty (via Homebrew, quando selecionado)
- **Windows**: Windows Terminal (via winget/chocolatey, quando selecionado)
- **WSL2** 🆕: Suporte completo com detecção automática

### Desenvolvimento

- **Neovim** configurado
- **Git** com suporte a perfis (work/personal)
- **VS Code** settings + extensões (opcional)
- **tmux** configurado
- **mise** (Runtime Manager) - instalado quando você seleciona runtimes
- **uv** (Python Package Manager) - instalado quando você seleciona IA Tools que dependem dele
- **Rust/cargo** - instalado quando necessário para CLI Tools
- **spec-kit** (Spec-driven development) - disponível na seleção de IA Tools 🆕
- **atuin** (Shell history) - disponível na seleção de CLI Tools 🆕

### Fontes

- Nerd Fonts são baixadas das **releases oficiais** (sem arquivos pesados no repo).
- Você escolhe quais instalar ou pode instalar todas.

---

## 📁 Estrutura do Projeto

```
config/
├── install.sh              # Script principal (install/export/sync)
├── data/                   # Catálogos de apps e runtimes
│   ├── apps.sh
│   └── runtimes.sh
├── lib/                    # Módulos do instalador
│   ├── banner.sh
│   ├── selections.sh
│   ├── nerd_fonts.sh
│   ├── themes.sh
│   ├── tools.sh
│   ├── app_installers.sh
│   ├── os_linux.sh
│   ├── os_macos.sh
│   ├── os_windows.sh
│   └── report.sh
├── shared/                 # Configs compartilhadas (todos OS)
│   ├── fish/
│   │   └── config.fish
│   ├── zsh/
│   │   ├── .zshrc
│   │   └── .p10k.zsh
│   ├── git/
│   │   ├── .gitconfig
│   │   ├── .gitconfig-personal
│   │   └── .gitconfig-work
│   ├── nvim/
│   ├── tmux/
│   ├── starship.toml
│   └── vscode/
│       ├── settings.json
│       └── extensions.txt
├── linux/                  # Configs específicas Linux
│   └── ghostty/
│       └── config
├── macos/                  # Configs específicas macOS
│   ├── ghostty/
│   │   └── config
│   └── Brewfile           # Apps do Homebrew (instalação opcional)
├── windows/                # Configs específicas Windows
│   ├── windows-terminal-settings.json
│   └── powershell/
│       └── profile.ps1
```

---

## 🔐 Repositório privado (opcional)

Para manter chaves SSH e credenciais fora do repo público, use um repo privado separado.
O instalador detecta automaticamente:

- `../config-private` (pasta irmã do repo público)
- `~/.dotfiles-private`
- ou defina `DOTFILES_PRIVATE_DIR=/caminho/para/seu-repo-privado`

Estrutura sugerida:

```
config-private/
└── shared/
    ├── .ssh/
    └── git/
        ├── .gitconfig-personal
        └── .gitconfig-work
```

Se existir, os arquivos do repo privado têm prioridade na instalação.
No repo público, esses arquivos ficam como exemplos (`.gitconfig-*.example` e `shared/.ssh.example`).

---

## 🔁 Atualizar o repositório público (mantenedor)

O repo privado é a fonte da verdade. Para atualizar o público, rode:

```bash
bash scripts/sync_public.sh
```

Por padrão, ele sincroniza para `../dotfiles`. Para usar outro caminho:

```bash
DOTFILES_PUBLIC_DIR="/caminho/para/dotfiles" bash scripts/sync_public.sh
```

Depois, no repo público:

```bash
git status
git add .
git commit -m "Atualiza do privado"
git push
```

---

## 🔄 Workflow Recomendado

### Primeira Instalação (Máquina Nova)

```bash
# 1. Clone o repo
git clone https://github.com/lucassr-dev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# 2. Instale tudo (com seleção interativa de apps)
bash install.sh

# 3. Reinicie o terminal
exec $SHELL

# 4. Configure Git com suas informações
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"

# 5. (Opcional) Mude para Zsh
chsh -s $(which zsh)

# 6. (Opcional) Se você instalou Atuin, configure o sync
atuin register  # Ou: atuin login
```

### Salvar Customizações Feitas

```bash
# Você editou suas configs (~/.zshrc, config.fish, etc.)
# Agora quer salvar no repositório:

cd ~/.dotfiles
bash install.sh export

# Verificar mudanças
git status
git diff

# Commitar
git add .
git commit -m "Update: melhorias nas configs"
git push
```

### Sincronizar Entre Múltiplas Máquinas

```bash
# Na máquina A (desktop):
cd ~/.dotfiles
bash install.sh export
git add . && git commit -m "Desktop configs" && git push

# Na máquina B (laptop):
cd ~/.dotfiles
git pull
bash install.sh            # Aplicar
exec $SHELL
```

---

## 🎨 Customização

### Aliases Úteis Já Incluídos

#### Navegação e Arquivos
```bash
ll        # eza -la --icons --git
ls        # eza --icons
cat       # bat (syntax highlighting)
cd        # z (zoxide - jump inteligente)
```

#### Git
```bash
g         # git
gs        # git status
ga        # git add
gc        # git commit
gp        # git push
gl        # git log --oneline --graph --all
gcom      # git add . && git commit -m "mensagem"
```

#### Funções
```bash
mkcd <dir>       # Cria diretório e entra nele
extract <file>   # Extrai qualquer arquivo compactado
create-react     # Cria projeto Vite + React + TS
create-laravel   # Cria projeto Laravel
dev-clean        # Limpa node_modules, cache, Docker
port <numero>    # Mostra processo usando porta
gpush           # Git push com upstream automático
backup <file>   # Cria backup com timestamp
dirsize         # Mostra tamanho dos diretórios
```

### Adicionar Seus Próprios Aliases

**Fish** (`config/shared/fish/config.fish`):
```fish
alias meucomando='echo "Olá!"'
```

**Zsh** (`config/shared/zsh/.zshrc`):
```bash
alias meucomando='echo "Olá!"'
```

Depois:
```bash
bash install.sh
exec $SHELL
```

### Trocar prompt no Fish

O Fish usa Starship por padrão. Para alternar:

```fish
# ~/.config/fish/config.fish
set -gx DEV_PROMPT_FISH starship   # ou: default
```

Se você configurou Oh My Posh, a linha `oh-my-posh init fish --config <tema>` fica no mesmo arquivo.
Troque o tema ali ou remova a linha para voltar ao prompt padrão.

### Adicionar Extensões VS Code

Edite `config/shared/vscode/extensions.txt`:
```
# Adicione o ID da extensão
ms-python.python
golang.go
rust-lang.rust-analyzer
```

Durante a instalação, você escolhe se quer instalar essas extensões. Para aplicar depois:
```bash
bash install.sh
```

### Usar Atuin (Histórico Inteligente)

Se você selecionou Atuin na etapa de CLI Tools, ele oferece um histórico de comandos muito superior!

#### Configuração Inicial

```bash
# Criar conta gratuita (opcional - para sync entre máquinas)
atuin register

# Ou fazer login se já tem conta
atuin login

# Importar histórico existente
atuin import auto
```

#### Como Usar

**Buscar no histórico:**
- Pressione `Ctrl + R` (Zsh ou Fish)
- Digite para filtrar
- Use setas para navegar
- Enter para executar

**Ver estatísticas:**
```bash
atuin stats
```

**Buscar comandos específicos:**
```bash
atuin search "docker"
atuin search "git commit"
```

**Sincronizar entre máquinas:**
```bash
atuin sync
```

#### Recursos do Atuin

- ✅ Histórico ilimitado (não perde comandos antigos)
- ✅ Busca full-text (encontra qualquer parte do comando)
- ✅ Sincronização criptografada entre máquinas
- ✅ Mostra diretório, exit status, duração
- ✅ Estatísticas de uso
- ✅ Filtragem avançada

**Mais info:** https://atuin.sh/

### Usar spec-kit para Desenvolvimento com IA

Se você selecionou **spec-kit** na etapa de IA Tools, ele permite desenvolvimento orientado por especificações com Claude Code, GitHub Copilot e outras IAs.

#### Inicializar spec-kit em um Projeto

```bash
# Navegar para seu projeto
cd ~/seu-projeto

# Inicializar com Claude Code
specify init . --ai claude

# Ou com GitHub Copilot
specify init . --ai copilot

# Ou com Cursor
specify init . --ai cursor
```

#### Comandos Disponíveis

Após inicialização, os seguintes comandos ficam disponíveis no projeto:

| Comando | Descrição |
|---------|-----------|
| `/speckit.constitution` | Definir princípios e guidelines do projeto |
| `/speckit.specify` | Descrever requisitos funcionais e user stories |
| `/speckit.plan` | Criar estratégia técnica de implementação |
| `/speckit.tasks` | Gerar lista de tarefas acionáveis |
| `/speckit.implement` | Executar implementação conforme o plano |
| `/speckit.clarify` | Esclarecer requisitos ambíguos |
| `/speckit.analyze` | Analisar código existente |
| `/speckit.checklist` | Validar qualidade da implementação |

#### Workflow Recomendado

```bash
# 1. Definir princípios do projeto
/speckit.constitution

# 2. Especificar o que você quer construir
/speckit.specify "Adicionar autenticação de usuários com JWT"

# 3. Criar plano técnico
/speckit.plan

# 4. Gerar tarefas
/speckit.tasks

# 5. Implementar
/speckit.implement
```

#### Compatibilidade com Agentes de IA

O spec-kit funciona com:

- ✅ **Claude Code** (CLI)
- ✅ **GitHub Copilot** (VSCode extensão)
- ✅ **Cursor** (IDE)
- ✅ **Windsurf, Qwen, Codex** e mais 17+ agentes

#### Recursos Adicionais

- [Documentação oficial do spec-kit](https://github.com/github/spec-kit)
- [Vídeo tutorial](https://github.com/github/spec-kit#video-overview)
- [Metodologia spec-driven](https://github.com/github/spec-kit/blob/main/docs/spec-driven.md)

---

### Adicionar Apps no macOS (Brewfile)

O Brewfile já vem pré-configurado com apps essenciais. Edite `config/macos/Brewfile` para adicionar mais:
```ruby
# CLI tools
brew "git"
brew "docker"

# Apps gráficos
cask "arc"              # Browser moderno
cask "slack"            # Comunicação
cask "raycast"          # Launcher
```

Depois de editar:
```bash
cd ~/.dotfiles
bash install.sh
```

Apps incluídos no Brewfile (macOS, instalação opcional):

> Esses apps são instalados **apenas se** você escolher instalar o Brewfile durante a etapa interativa no macOS.

- **Browsers**: Arc, Firefox
- **Terminals**: Ghostty, iTerm2
- **Development**: VS Code, Docker (Colima), Postman, DBeaver
- **Productivity**: Slack, Notion, Obsidian
- **Communication**: Discord
- **Media**: VLC, Spotify
- **Utilities**:
  - Raycast (launcher com plugins)
  - Rectangle (window manager) - **configurado automaticamente**
  - Stats (system monitor) - **configurado automaticamente**
  - Alt-tab (app switcher)
  - Hidden Bar (menu bar organizer)
  - KeyCastr (keyboard visualizer) - **configurado**
  - CleanShot (screenshots)
  - Command X (cut & paste)
  - AppCleaner (uninstaller gratuito)

### Apps com Configuração Automática (macOS)

Quando você opta por instalar o Brewfile, alguns apps também recebem configuração automática via arquivos deste repositório:

#### Rectangle (Window Manager)

Atalhos configurados:

- `Ctrl + Opt + Left` - Meia tela esquerda
- `Ctrl + Opt + Right` - Meia tela direita
- `Ctrl + Opt + Up` - Topo
- `Ctrl + Opt + Down` - Baixo
- `Ctrl + Opt + Enter` - Maximizar
- `Ctrl + Opt + C` - Centralizar
- `Ctrl + Opt + M` - Quase maximizar
- `Ctrl + Opt + Cmd + Left/Right` - Mover entre monitores

#### Stats (System Monitor)

Configurado para exibir na menu bar:

- CPU usage (atualização a cada 2s)
- RAM usage (atualização a cada 2s)
- Disk usage (atualização a cada 10s)
- Network speed (atualização a cada 2s)
- Battery status (laptops)

#### KeyCastr (Keyboard Visualizer)

Configuração disponível (aplicação pode exigir ajustes manuais) com:

- Fonte: JetBrains Mono, 48px
- Posição: Canto inferior esquerdo
- Exibe teclas modificadoras (⌘⌥⌃⇧)
- Atalho para ativar/desativar: `Cmd + Shift + K`

**Importante:** KeyCastr requer permissão de Acessibilidade:

1. Preferências do Sistema → Segurança e Privacidade
2. Aba "Acessibilidade"
3. Adicione KeyCastr à lista

#### Raycast (Launcher)

Plugins recomendados (instalar manualmente via Raycast Store):

- Homebrew
- Clipboard History
- Window Management
- Google Search
- GitHub
- Kill Process
- npm Search

Veja [config/macos/raycast/README.md](config/macos/raycast/README.md) para guia completo.

---

## 🌍 Apps Cross-Platform

Muitos apps do macOS também estão disponíveis em **Linux e Windows** e ficam disponíveis na seleção interativa do script.

> Por padrão, o script instala/atualiza **apenas** o que você selecionar (ou tudo, se `INTERACTIVE_GUI_APPS=false`).

### ✅ Disponíveis na seleção interativa (cross-platform)

**Browsers:** Firefox, Arc (Windows)

**Development:** VS Code, Docker, Postman, DBeaver, PostgreSQL, Redis, MySQL

**Productivity:** Slack, Notion, Obsidian

**Communication:** Discord

**Media:** VLC, Spotify

### 🔧 Utilities com Equivalentes

Alguns apps têm equivalentes funcionais em outros sistemas:

| macOS | Linux | Windows |
|-------|-------|---------|
| **Rectangle** | Tiling WMs (i3, bspwm, Sway) | PowerToys FancyZones ✅ |
| **Stats** | btop/htop ✅ | Task Manager (nativo) |
| **CleanShot** | Flameshot ✅ | ShareX ✅ |
| **KeyCastr** | Screenkey ✅ | Carnac ✅ |
| **Hidden Bar** | - | - |
| **Alt-tab** | Nativo | Nativo |
| **Command X** | Nativo | Nativo |
| **AppCleaner** | apt remove | winget uninstall |
| **Raycast** | - | PowerToys Run |

**✅ = O script tenta instalar quando aplicável (depende do OS/seleção)**

### 📦 Linux: Gerenciadores de Pacotes

O script tenta instalar apps na seguinte ordem:

1. **APT** (Debian/Ubuntu) - Repositórios oficiais
2. **Snap** - Fallback para apps modernos
3. **Flatpak** - Fallback final (apps sandboxed)

Apps disponíveis para seleção no Linux (instalados **apenas se selecionados** na etapa interativa, ou se `INTERACTIVE_GUI_APPS=false`):
- Firefox, Google Chrome (apenas distros apt), Brave, Zen
- VS Code, Docker, PostgreSQL, Redis, MySQL, VLC
- Slack, Discord, Spotify, Obsidian, Notion, Postman, DBeaver (via Snap/Flatpak, quando disponível)
- Flameshot (screenshots), Screenkey (keyboard viz)

### 🪟 Windows: Winget e Chocolatey

O script usa **Winget** (preferencial) ou **Chocolatey** como fallback.

Apps disponíveis para seleção no Windows (instalados **apenas se selecionados** na etapa interativa, ou se `INTERACTIVE_GUI_APPS=false`):
- Firefox, Google Chrome, Brave, Arc
- VS Code, Docker Desktop, PostgreSQL, Redis, MySQL, VLC
- Slack, Discord, Spotify, Obsidian, Notion, Postman, DBeaver
- **PowerToys** (opcional)
- **ShareX** (screenshots avançados)
- **Carnac** (exibe teclas pressionadas)

### 🐧 WSL2: Melhor dos Dois Mundos

**Novo:** Suporte completo para WSL2!

O script detecta automaticamente WSL2 e aplica otimizações:
- ✅ Usa gerenciadores Linux (apt, snap, flatpak)
- ✅ Detecta automaticamente via `/proc/version`
- ✅ Configurações adaptadas para ambiente híbrido
- ✅ Suporte a `wslpath` para integração com Windows

### 💡 Dicas Cross-Platform

**Sincronização de Configs:**
- VS Code: Settings Sync (nativo)
- Obsidian: Via Obsidian Sync ou Git
- Notion, Slack, Discord: Sincronizam na nuvem automaticamente
- **Atuin:** Sincronização criptografada de histórico entre máquinas (se instalado) 🆕

**Export/Import Manual:**
- DBeaver: Export connections
- Postman: Export collections
- Docker: Export containers/images

**Atualizar todos os apps:**

⚠️ Isso é opcional e **não** é executado automaticamente pelo script (por padrão ele atualiza apenas o que você selecionou).

```bash
# macOS
brew update && brew upgrade

# Linux (Debian/Ubuntu)
sudo apt update && sudo apt upgrade -y && snap refresh && flatpak update -y

# Windows
winget upgrade --all

# WSL2
sudo apt update && sudo apt upgrade -y
```

---

## 🔀 Alternância Automática de Contas Git

O sistema está configurado para alternar automaticamente entre suas contas pessoal e de trabalho baseado no diretório do projeto.

### Como Funciona

O Git usa a diretiva `includeIf` no arquivo [.gitconfig](shared/git/.gitconfig) para carregar configurações diferentes dependendo do diretório:

**Conta Pessoal** (projetos pessoais):

- `~/personal/` → usa `.gitconfig-personal`
- `~/projects/` → usa `.gitconfig-personal`

**Conta Trabalho** (projetos Humu):

- `~/work/` → usa `.gitconfig-work`
- `~/workspace/` → usa `.gitconfig-work`
- `~/humu/` → usa `.gitconfig-work`

### Configuração Inicial

**Crie os diretórios:**

```bash
mkdir -p ~/personal ~/work
```

**Clone seus projetos nos diretórios corretos:**

```bash
# Projetos pessoais
cd ~/personal
git clone git@github.com:seu-usuario/seu-projeto.git

# Projetos de trabalho
cd ~/work
git clone git@github.com:humu/projeto-trabalho.git
```

**Verifique qual conta está ativa:**

```bash
cd ~/personal/seu-projeto
git config user.name    # Deve mostrar: lucassr-dev
git config user.email   # Deve mostrar: lucassr.job@gmail.com

cd ~/work/projeto-trabalho
git config user.name    # Deve mostrar: humu-lucassrdev
git config user.email   # Deve mostrar: lucas.rosa@humu.com.br
```

### Arquivos de Configuração

- [.gitconfig](shared/git/.gitconfig) - Configuração principal com `includeIf`
- [.gitconfig-personal](shared/git/.gitconfig-personal) - Credenciais pessoais (recomendado manter no repo privado)
- [.gitconfig-work](shared/git/.gitconfig-work) - Credenciais trabalho (recomendado manter no repo privado)

### Personalizando Diretórios

Edite `~/.gitconfig` para adicionar mais diretórios:

```ini
# Adicionar mais diretórios para conta pessoal
[includeIf "gitdir:~/github/"]
    path = ~/.gitconfig-personal

# Adicionar mais diretórios para conta trabalho
[includeIf "gitdir:~/company/"]
    path = ~/.gitconfig-work
```

### Troubleshooting

**Problema:** Git ainda usa a conta errada

**Solução:**

```bash
# 1. Verifique se os arquivos existem
ls -la ~/.gitconfig*

# 2. Teste a configuração
cd ~/personal/seu-projeto
git config --show-origin user.email

# 3. Se necessário, force a reconfiguração
cd ~/.dotfiles
bash install.sh
```

---

## ❓ FAQ

### Preciso rodar o script toda vez que mudar algo?

**Sim**, mas:
- ✅ O script é idempotente (pode rodar múltiplas vezes)
- ✅ Faz backup automático antes de sobrescrever
- ✅ Leva apenas alguns segundos

**Ou** você pode editar diretamente (`~/.zshrc`) e depois exportar:
```bash
bash install.sh export
```

### O que acontece com minhas configs antigas?

São criados backups em `~/.dotfiles-backup-YYYYMMDD-HHMMSS/` com:
- ✅ Symlinks preservados 🆕
- ✅ Permissions preservadas 🆕
- ✅ Timestamps preservados 🆕

### Como sincronizar entre Windows/Linux/macOS?

O script detecta automaticamente o OS e aplica configs específicas:
- `shared/` → aplicado em todos
- `linux/`, `macos/`, `windows/` → específicos
- **WSL2** → detectado automaticamente 🆕

### Posso usar apenas Zsh OU Fish?

Sim! Você escolhe qual instalar (ou ambos) durante a execução:
```bash
chsh -s $(which zsh)   # Ou
chsh -s $(which fish)
```

### As fontes são instaladas automaticamente?

**Sim, quando você aceita a etapa de Nerd Fonts.** Você pode escolher fontes específicas ou instalar todas. O script baixa das releases oficiais e instala em:
- **Linux**: `~/.local/share/fonts`
- **macOS**: `~/Library/Fonts`
- **Windows**: `%LOCALAPPDATA%/Microsoft/Windows/Fonts`

E executa `fc-cache` para atualizar o cache.

### Como atualizar tudo?

```bash
cd ~/.dotfiles
git pull
bash install.sh            # Aplicar
exec $SHELL
```

### VS Code extensions não instalam?

Certifique-se de que:
1. VS Code está instalado
2. Comando `code` está no PATH
3. Você selecionou **VS Code Extensions: instalar** na revisão final
4. Execute: `bash install.sh` novamente

### Brewfile não funciona no macOS?

Certifique-se de que:
1. Homebrew está instalado: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. Execute: `bash install.sh` novamente
3. Durante a instalação, escolha se quer instalar o Brewfile 🆕

### Posso desativar a seleção interativa de apps GUI?

Sim! Isso afeta apenas apps GUI. Edite `install.sh` e mude:
```bash
INTERACTIVE_GUI_APPS=false  # Instala todos os apps GUI automaticamente
```

### Como funciona o histórico com Atuin?

Se você instalou Atuin, ele substitui o histórico padrão e oferece:
- Busca inteligente com `Ctrl+R`
- Sincronização entre máquinas
- Histórico ilimitado
- Mais info: https://atuin.sh/

---

## 🔧 Como Funciona

### Modo Install (Padrão)

```bash
bash install.sh
```

1. Detecta o sistema operacional (Linux, macOS, Windows, **WSL2** 🆕)
2. Mostra o banner de boas-vindas e explica o fluxo
3. Pergunta sobre dependências base e Nerd Fonts
4. Seleciona shells, temas e plugins
5. Seleciona CLI Tools, IA Tools e terminais
6. **Pergunta quais apps GUI instalar** 🆕
7. Seleciona extensões do VS Code (opcional)
8. Seleciona runtimes via mise (opcional)
9. Configura Git multi-conta (opcional)
10. Revisão final com opção de editar antes de instalar
11. Instala extensões do VS Code (se habilitado)
12. Copia configs do repositório → sistema (com backup)
13. Instala apps via Brewfile (macOS - **instalação opcional** 🆕)

### Modo Export

```bash
bash install.sh export
```

1. Detecta o sistema operacional
2. Copia configs do sistema → repositório
3. Exporta lista de extensões VS Code
4. Exporta Brewfile atualizado (macOS)
5. Mostra mensagem para fazer commit

### Modo Sync

```bash
bash install.sh sync
```

1. Executa export primeiro
2. Depois executa install
3. Sincronização bidirecional completa

---

## 🎯 Recursos Importantes

### Backup Automático

Toda instalação cria backup em:
```
~/.dotfiles-backup-20251217-143022/
├── .zshrc
├── config.fish
└── ...
```

**Melhorias no backup:** 🆕
- ✅ Preserva symlinks (`cp -a` em vez de `cp -R`)
- ✅ Preserva permissions
- ✅ Preserva timestamps
- ✅ Restauração 100% fiel

### Idempotência

Pode rodar o script múltiplas vezes sem problemas:
- ✅ Não duplica configurações
- ✅ Não reinstala o que já existe
- ✅ Atualiza apenas o que mudou

### Cross-Platform

Um único repositório funciona em:
- ✅ Linux (Debian, Ubuntu, Fedora, Arch, openSUSE)
- ✅ macOS (Intel e Apple Silicon)
- ✅ Windows (via Git Bash, MSYS2, Cygwin)
- ✅ **WSL2** (detecção automática) 🆕

### Performance

**Melhorias de velocidade:** 🆕
- ⚡ Shallow git clones (`--depth=1`) - 10x mais rápido
- ⚡ Instalação de plugins Zsh: ~3s em vez de ~30s
- ⚡ Redução de downloads: ~5MB em vez de ~50MB por plugin

---

## 🚦 Troubleshooting

### Erro: "Oh My Zsh já está instalado"

Não é problema! O script detecta e pula a instalação.

### Erro: "Ferramentas como eza não foram instaladas"

**Não precisa se preocupar!** Se você selecionou ferramentas que dependem de `cargo`, o script tenta instalar Rust/cargo automaticamente.

Caso a instalação automática falhe:
```bash
# Instale Rust manualmente
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Execute o instalador novamente
bash install.sh
```

### Erro: "Fontes não aparecem no terminal"

```bash
# Linux/macOS: Atualize cache de fontes
fc-cache -fv

# Reinicie o terminal
# Configure o terminal para usar "JetBrains Mono Nerd Font"
```

### Erro: "Git config não funciona"

O script instala uma configuração de Git com `includeIf` para alternar conta por diretório.

Checklist:
```bash
# Verificar de onde vem o e-mail (mostra a origem do config)
git config --show-origin user.email

# Verificar se os arquivos existem
ls -la ~/.gitconfig*
```

Se precisar ajustar nomes/e-mails, edite os arquivos do repositório e rode o instalador novamente:
- `config/shared/git/.gitconfig-personal`
- `config/shared/git/.gitconfig-work`

### Erro: "Ghostty não foi instalado"

Se você selecionou Ghostty, o script tenta múltiplos métodos de instalação específicos para sua distro:

- **Ubuntu/Pop!_OS**: Script mkasberg
- **Debian**: Repositório griffo.io com GPG
- **Arch/Manjaro**: Pacman nativo
- **Fedora/RHEL**: Snap
- **openSUSE**: Zypper

Se todos falharem, consulte a [documentação oficial do Ghostty](https://ghostty.org/) para instalação manual.

### Erro: "mise não foi instalado"

Se você selecionou runtimes via mise, o script instala mise automaticamente via script oficial. Se falhar:
```bash
# Instale manualmente
curl https://mise.run | sh

# Execute o instalador novamente
bash install.sh
```

### Erro: "uv não foi instalado"

Se você selecionou IA Tools que dependem de uv, o script instala uv automaticamente via script oficial. Se falhar:
```bash
# Instale manualmente
curl -LsSf https://astral.sh/uv/install.sh | sh

# Gere os completions para seu shell
uv generate-shell-completion fish > ~/.config/fish/completions/uv.fish  # Fish
uv generate-shell-completion zsh > ~/.oh-my-zsh/completions/_uv        # Zsh

# Execute o instalador novamente
bash install.sh
```

### Erro: "Atuin não foi instalado" 🆕

Se você selecionou Atuin nas CLI Tools, o script tenta instalar automaticamente. Se falhar:
```bash
# Instale manualmente
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

# Configure para seu shell
# Fish: já configurado automaticamente quando Atuin é instalado
# Zsh: adicione ao ~/.zshrc:
eval "$(atuin init zsh)"

# Execute o instalador novamente
bash install.sh
```

### Validar starship.toml manualmente

Se quiser checar sua configuração do Starship:

```bash
# Teste manualmente
cd ~/.dotfiles

# Testar o arquivo do repo (antes de aplicar)
STARSHIP_CONFIG="config/shared/starship.toml" starship print-config

# (opcional) Testar a config já instalada no sistema
STARSHIP_CONFIG="$HOME/.config/starship.toml" starship print-config

# Se houver erros, corrija em: config/shared/starship.toml
# Depois execute novamente
bash install.sh
```

### Problema: "Instalação está demorando muito"

**Solução:** Desmarque apps GUI desnecessários durante a seleção interativa!

A instalação completa de todos os apps pode levar 30+ minutos. Selecione apenas o que precisa.

### Problema: "WSL2 não foi detectado" 🆕

```bash
# Verifique se é WSL2
cat /proc/version | grep -i microsoft

# Se não aparecer nada, não é WSL2
# Se aparecer "microsoft" ou "WSL", o script deve detectar automaticamente
```

---

## 📝 Contribuindo

Sugestões e melhorias são bem-vindas! Abra uma issue ou PR.

---

## 📚 Recursos Úteis

### Documentação Oficial
- [Oh My Zsh](https://ohmyz.sh/)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Starship](https://starship.rs/)
- [Ghostty](https://ghostty.org/)
- [Fish Shell](https://fishshell.com/)
- [Atuin](https://atuin.sh/) 🆕
- [spec-kit](https://github.com/github/spec-kit)

### Ferramentas CLI Modernas
- [eza](https://github.com/eza-community/eza)
- [bat](https://github.com/sharkdp/bat)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [fzf](https://github.com/junegunn/fzf)
- [lazygit](https://github.com/jesseduffield/lazygit)
- [atuin](https://github.com/atuinsh/atuin) 🆕

### Inspiração
- [Awesome Dotfiles](https://github.com/webpro/awesome-dotfiles)
- [dotfiles.github.io](https://dotfiles.github.io/)

---

## 🎉 Changelog (2025)

### ✨ Novidades Principais

- 🎯 **Seleção Interativa de Apps GUI** - Escolha o que instalar (economize tempo e espaço)
- 🔐 **Atuin** - Histórico inteligente com sincronização entre máquinas
- 🐧 **Suporte WSL2** - Detecção automática com otimizações específicas
- ✅ **Presets do Starship** - Aplicação automática do preset selecionado
- ⚡ **10x Mais Rápido** - Shallow git clones (`--depth=1`)
- 💾 **Backups Perfeitos** - Preserva symlinks, permissions e timestamps
- 🔧 **Spec-kit Melhorado** - Instalação com guia detalhado

### 🛠️ Melhorias Técnicas

- Oh My Zsh totalmente silencioso (`CHSH=no RUNZSH=no`)
- Git clones otimizados (5MB em vez de 50MB por plugin)
- Validação de configurações antes de copiar
- Detecção aprimorada de sistemas operacionais
- Mensagens de erro mais claras

---

**Desenvolvido com ❤️ para aumentar sua produtividade em 2025!**

## 📜 Licença

MIT License - use livremente!
