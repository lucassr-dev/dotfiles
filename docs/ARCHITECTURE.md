# Arquitetura — Sistema de Dotfiles

## Visao Geral

```text
install.sh (orquestrador)
    │
    ├── lib/state.sh          Estado centralizado (_STATE associative array)
    ├── lib/colors.sh         Design tokens Catppuccin Mocha (26 cores)
    ├── lib/utils.sh          Text utilities (_strip_ansi, _visible_len, _wrap_text)
    ├── lib/components.sh     UI components (ui_box, ui_section, ui_progress)
    ├── lib/ui.sh             Interação usuario (fzf/gum/bash fallback)
    ├── lib/banner.sh         Banner ASCII responsivo
    ├── lib/selections.sh     Menus de seleção + lógica de workflow
    ├── lib/checkpoint.sh     Resume de instalação (state persistence)
    ├── lib/fileops.sh        Operações de arquivo (copy/export/backup/diff)
    ├── lib/install_priority.sh  Motor de instalação + catálogo APP_SOURCES
    ├── lib/themes.sh         Temas shell (P10k/Starship/Oh My Posh)
    ├── lib/git_config.sh     Git multi-conta
    ├── lib/tools.sh          CLI tools + Rust/Cargo + VSCode extensions
    ├── lib/nerd_fonts.sh     Download paralelo de Nerd Fonts
    ├── lib/runtimes.sh       Runtimes via mise
    ├── lib/gui_apps.sh       Seleção de apps GUI
    ├── lib/os_linux.sh       Linux (apt/dnf/pacman/zypper)
    ├── lib/os_macos.sh       macOS (Homebrew + batch)
    ├── lib/os_windows.sh     Windows (winget/choco/scoop)
    ├── lib/report.sh         Dashboard pos-instalação
    │
    ├── data/apps.sh          Catálogo de apps GUI por categoria
    └── data/runtimes.sh      Definições de runtimes
```

## Fluxo de Dados

```text
                    ┌──────────┐
                    │  state   │ ← _STATE associative array
                    └────┬─────┘
                         │
  ┌──────────────────────┼──────────────────────┐
  │                      │                      │
  ▼                      ▼                      ▼
selections           install                  report
(ask_* → state)    (state → pkg managers)   (state → dashboard)
```

## Ordem de Carregamento

1. `state.sh` — Disponível para todos os módulos
2. `checkpoint.sh` — Resume de instalação anterior
3. `colors.sh` → `utils.sh` → `components.sh` — Design system
4. `ui.sh` → `banner.sh` → `selections.sh` — Interface
5. `nerd_fonts.sh` → `themes.sh` — Fontes e temas
6. `install_priority.sh` — Motor de instalação (lazy-load catalog)
7. `os_linux.sh` / `os_macos.sh` / `os_windows.sh` — Platform
8. `gui_apps.sh` → `tools.sh` → `git_config.sh` → `runtimes.sh`
9. `report.sh` — Dashboard final

## Convenções

### Funções
- `snake_case` para todas as funções
- Prefixo `_` para funções internas/privadas
- Prefixo `ui_` para componentes visuais
- Prefixo `state_` para gestão de estado

### Estado
- `state_set "namespace.key" "value"` em vez de globals
- Globals legadas sincronizadas via `_sync_globals_to_state()`
- Checkpoint salva/carrega via state automaticamente

### Como Adicionar um Novo App

1. Adicionar entrada em `lib/install_priority.sh` → `init_app_catalog()`:
   ```bash
   APP_SOURCES[myapp]="apt:myapp,brew:myapp,winget:MyOrg.MyApp"
   ```
2. Se for GUI app, adicionar em `data/apps.sh`
3. Se for CLI tool, adicionar em `lib/tools.sh`

### Como Adicionar um Novo Package Manager

1. Criar `_install_via_newpm()` em `lib/install_priority.sh`
2. Adicionar ao `case` em `install_with_priority()`
3. Adicionar detecção em `is_app_installed()` (install.sh)
