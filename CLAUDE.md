# Lucas-Backup/config - Sistema de Dotfiles Multi-Plataforma

## Visao Geral

Sistema de gestao de dotfiles **production-ready** para automacao de ambientes de desenvolvimento em Linux, macOS e Windows. Oferece instalacao interativa, configuracao modular e sincronizacao bidirecional de configuracoes.

## Arquitetura

```text
config/
├── install.sh              # Orquestrador principal (~2,800 linhas)
├── lib/                    # 15 modulos de biblioteca
│   ├── banner.sh           # Banner ASCII responsivo
│   ├── ui.sh               # Sistema UI (fzf/gum/bash fallback)
│   ├── selections.sh       # Menus de selecao interativos
│   ├── report.sh           # Dashboard pos-instalacao
│   ├── themes.sh           # Temas shell (P10k/Starship/Oh My Posh)
│   ├── git_config.sh       # Configuracao Git multi-conta
│   ├── tools.sh            # Instalacao de CLI tools
│   ├── app_installers.sh   # Instaladores de IDEs/Editores
│   ├── gui_apps.sh         # Selecao de apps GUI
│   ├── runtimes.sh         # Gerenciamento de runtimes (mise)
│   ├── nerd_fonts.sh       # Download dinamico de fontes
│   ├── os_linux.sh         # Suporte Linux (apt/dnf/pacman/zypper)
│   ├── os_macos.sh         # Suporte macOS (Homebrew)
│   └── os_windows.sh       # Suporte Windows (winget/Chocolatey)
├── data/                   # Catalogos de dados
│   ├── apps.sh             # Apps GUI por categoria
│   └── runtimes.sh         # Definicoes de runtimes
├── shared/                 # Configs agnósticas de plataforma
│   ├── git/                # .gitconfig, multi-conta
│   ├── zsh/                # .zshrc, .p10k.zsh
│   ├── fish/               # config.fish
│   ├── nushell/            # config.nu, env.nu
│   ├── nvim/               # Configuracao Neovim
│   ├── tmux/               # Configuracao Tmux
│   ├── vscode/             # settings.json, extensions.txt
│   ├── mise/               # config.toml
│   └── starship.toml       # Tema universal
├── linux/                  # Configs especificas Linux
├── macos/                  # Configs especificas macOS
├── windows/                # Configs especificas Windows
└── scripts/
    └── sync_public.sh      # Sync para repo publico
```

## Modos de Operacao

```bash
bash install.sh           # install: Repo -> Sistema
bash install.sh export    # export: Sistema -> Repo
bash install.sh sync      # sync: Bidirecional
```

## Funcionalidades Principais

### 1. Instalacao Interativa

- Banner responsivo (adapta largura terminal)
- Menus com fzf/gum/bash fallback automatico
- Preview de selecoes antes de confirmar

### 2. Multi-Shell

- **Zsh**: Oh My Zsh, plugins, Powerlevel10k
- **Fish**: Starship, plugins nativos
- **Nushell**: Config modular

### 3. Temas

- Powerlevel10k (Zsh)
- Starship (universal)
- Oh My Posh (universal)
- Previews visuais (Chafa/Kitty/Sixel)

### 4. Git Multi-Conta

```bash
# Auto-switch por diretorio
~/personal/* -> .gitconfig-personal
~/work/*     -> .gitconfig-work
```

- Troca automatica de identidade
- Delta para diffs coloridos
- Credential helper configurado

### 5. Ferramentas CLI (19+)

zoxide, bat, eza, ripgrep, fd, lazygit, gh, jq, btop, tmux, atuin, tealdeer, yazi, direnv, hyperfine, fzf, delta, gum, dust

### 6. Ferramentas IA (7)

claude-code, aider, spec-kit, serena, codex, continue, goose

### 7. Apps GUI (150+)

Organizados por categoria: IDEs, Browsers, Databases, Communication, Productivity, Media

### 8. Runtimes (via mise)

- Padrao: Node.js, Python, PHP
- Opcionais: Rust, Go, Bun, Deno, Elixir, Java, Ruby

### 9. Nerd Fonts

Download dinamico de 100+ fontes do GitHub releases

### 10. Backup Automatico

- Timestamped: `~/.bkp-YYYYMMDD-HHMM/`
- Preserva configs existentes antes de sobrescrever

## Seguranca

### Arquivos Privados (gitignored)

- `.ssh/` - Chaves SSH
- `.gitconfig-personal` - Config pessoal
- `.gitconfig-work` - Config trabalho

### Protecoes Implementadas

- Sem `eval` com input de usuario
- Download seguro via temp files
- Validacao de permissoes (700/600)
- Sync publico exclui segredos

## Dependencias

### Obrigatorias

- bash 4.3+
- git
- curl ou wget

### Opcionais (melhor UX)

- fzf (menus interativos)
- gum (UI alternativa)

## Convencoes de Codigo

### Estilo

- Shellcheck: `SC2034,SC2329,SC1091` desabilitados globalmente
- Funcoes: snake_case
- Variaveis globais: UPPER_CASE
- Arrays: Uso de nameref para atribuicao segura

### Estrutura de Funcoes

```bash
funcao_exemplo() {
    local var="valor"
    # Implementacao
}
```

### Tratamento de Erros

```bash
CRITICAL_ERRORS=()   # Erros que impedem instalacao
OPTIONAL_ERRORS=()   # Erros nao-criticos
```

## Variaveis Globais Importantes

```bash
TARGET_OS=""              # linux, macos, windows, wsl2
LINUX_PKG_MANAGER=""      # apt-get, dnf, pacman, zypper
MODE="install"            # install, export, sync
BACKUP_DIR=""             # Diretorio de backup atual

INSTALL_ZSH=1
INSTALL_FISH=1
INSTALL_BASE_DEPS=1

SELECTED_CLI_TOOLS=()
SELECTED_IA_TOOLS=()
SELECTED_TERMINALS=()
SELECTED_RUNTIMES=()
```

## Fluxo de Execucao

```text
show_banner()
  -> detect_os()
  -> ask_shell_selection()
  -> ask_base_dependencies()
  -> install_nerd_fonts()
  -> ask_themes_selection()
  -> ask_cli_tools()
  -> ask_ia_tools()
  -> ask_gui_apps()
  -> ask_git_configuration()
  -> ask_runtimes()
  -> copy_configurations()
  -> print_post_install_report()
```

## Comandos Uteis para Desenvolvimento

```bash
# Testar sem modificar sistema
DRY_RUN=1 bash install.sh

# Verbose no report
VERBOSE_REPORT=1 bash install.sh

# Sync para repo publico
bash scripts/sync_public.sh
```

## Notas de Manutencao

- Janeiro 2025: Auditoria de seguranca completa
- Corrigido: RCE via curl|sh, command injection via eval
- Corrigido: Bugs de atribuicao de array com nameref
- Corrigido: Preservacao de PATH existente
