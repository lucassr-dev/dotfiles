# Arquitetura — Sistema de Dotfiles

## Visao Geral

```text
config/
├── install.sh                 Orquestrador principal (~2800 linhas)
├── lib/                       22 modulos de biblioteca
│   ├── state.sh               Estado centralizado (_STATE associative array)
│   ├── colors.sh              Design tokens Catppuccin Mocha (26 cores)
│   ├── utils.sh               Text utilities (_strip_ansi, _visible_len, _wrap_text)
│   ├── components.sh          UI components (ui_box, ui_section, ui_progress)
│   ├── ui.sh                  Interacao usuario (fzf/gum/bash fallback)
│   ├── banner.sh              Banner ASCII responsivo
│   ├── selections.sh          Menus de selecao + logica de workflow
│   ├── checkpoint.sh          Resume de instalacao (state persistence)
│   ├── fileops.sh             Operacoes de arquivo (copy/export/backup/diff)
│   ├── install_priority.sh    Motor de instalacao + catalogo APP_SOURCES (lazy-load)
│   ├── themes.sh              Temas shell (P10k/Starship/Oh My Posh)
│   ├── git_config.sh          Git multi-conta (includeIf por diretorio)
│   ├── tools.sh               CLI tools + Rust/Cargo + VSCode extensions
│   ├── app_installers.sh      Instaladores especiais (Ghostty, spec-kit, etc.)
│   ├── editors.sh             Configuracao de editores (Neovim, VSCode, Zed, Helix)
│   ├── gui_apps.sh            Selecao de apps GUI (8 categorias)
│   ├── runtimes.sh            Runtimes via mise
│   ├── nerd_fonts.sh          Download paralelo de Nerd Fonts (8 simultaneas)
│   ├── os_linux.sh            Linux (apt/dnf/pacman/zypper) + PHP deps
│   ├── os_macos.sh            macOS (Homebrew + batch install) + PHP deps
│   ├── os_windows.sh          Windows (winget/choco/scoop) + PHP + PowerShell
│   └── report.sh              Dashboard pos-instalacao
├── data/
│   ├── apps.sh                Apps GUI por categoria (150+)
│   └── runtimes.sh            Definicoes de runtimes (10 linguagens)
├── shared/                    Configs agnosticas de plataforma (25 apps)
│   ├── zsh/                   .zshrc, .p10k.zsh
│   ├── fish/                  config.fish, conf.d/, functions/
│   ├── nushell/               config.nu, env.nu
│   ├── git/                   .gitconfig-personal, .gitconfig-work
│   ├── nvim/                  Configuracao Neovim
│   ├── tmux/                  .tmux.conf
│   ├── vscode/                settings.json, extensions.txt
│   ├── kitty/                 kitty.conf
│   ├── alacritty/             alacritty.toml
│   ├── wezterm/               wezterm.lua
│   ├── lazygit/               config.yml
│   ├── yazi/                  yazi.toml, keymap.toml, theme.toml
│   ├── btop/                  btop.conf
│   ├── bat/                   config + temas
│   ├── atuin/                 config.toml
│   ├── mise/                  config.toml
│   ├── zed/                   settings.json
│   ├── helix/                 config.toml
│   ├── direnv/                .direnvrc
│   ├── docker/                config.json
│   ├── npm/                   .npmrc
│   ├── pnpm/                  .pnpmrc
│   ├── yarn/                  .yarnrc
│   ├── pip/                   pip.conf
│   └── cargo/                 config.toml
├── linux/                     Configs especificas Linux
├── macos/                     Configs especificas macOS
├── windows/                   Configs especificas Windows
├── tests/                     Testes BATS
│   ├── test_state.bats        State management (13 testes)
│   ├── test_utils.bats        Text utilities (5 testes)
│   └── test_install_idempotence.bats  Idempotencia de instalacao
├── scripts/
│   └── sync_public.sh         Sync para repo publico (exclui segredos)
└── .github/workflows/
    └── validate.yml           CI: syntax, shellcheck, dry-run (3 OS), BATS
```

## Modos de Operacao

```bash
bash install.sh           # install: Repo -> Sistema (interativo)
bash install.sh export    # export:  Sistema -> Repo (automatico)
bash install.sh sync      # sync:    export + install (bidirecional)
DRY_RUN=1 bash install.sh # dry-run: simula sem instalar
```

## Fluxo de Instalacao

```text
1. Checkpoint check (resume anterior?)
2. Banner + welcome
3. Dependencias base (git, curl, fzf, gum)
4. Selecoes interativas:
   ├── Shells (Zsh, Fish, Nushell)
   ├── Temas (OMZ+P10k, Starship, OMP) + presets/plugins
   ├── Nerd Fonts (recomendadas / manual / todas)
   ├── Terminais (Ghostty, Kitty, Alacritty, WezTerm)
   ├── CLI Tools (19 ferramentas)
   ├── IA Tools (7 ferramentas)
   ├── GUI Apps (8 categorias, 150+ apps)
   ├── Runtimes (10 linguagens via mise)
   └── Git multi-conta (pessoal + trabalho)
5. _auto_enable_configs() -> habilita COPY_* para apps selecionados
6. RESUMO FINAL (review_selections)
   ├── Stats: pacotes, configs, OS
   ├── Secoes: AMBIENTE, FERRAMENTAS, APPS GUI, COPIAR CONFIGS
   ├── EDITAR SELECOES: 0-8 para re-selecionar, 0 = toggle configs
   └── Enter para instalar, S para sair
7. Checkpoint save
8. Instalacao (12 steps com progress bar)
9. Dashboard pos-instalacao (print_post_install_report)
```

## Logica de Configuracoes (COPY_*)

```text
Selecao de apps               _auto_enable_configs()         RESUMO FINAL
─────────────────────         ─────────────────────          ────────────────
tmux selecionado     ──────>  COPY_TMUX_CONFIG=1    ──────>  ✓ tmux
bat selecionado      ──────>  COPY_BAT_CONFIG=1     ──────>  ✓ bat
lazygit NAO selecionado ───>  (nao altera)          ──────>  (nao aparece)

                              Toggle via opcao 0:
                              1 ✓ tmux   2 ✓ bat
                              usuario digita "1" -> tmux ✗
```

Todos os `COPY_*` iniciam em 0. `_auto_enable_configs()` habilita apenas para apps
selecionados cujo config existe em `shared/`. Usuario pode toggle no RESUMO FINAL.

## State Management

Estado centralizado via associative array `_STATE` em `lib/state.sh`:

```bash
state_set "system.os" "linux"         # Definir
state_get "system.os"                 # Ler (com default opcional)
state_append "selections.tools" "fzf" # Adicionar a lista CSV
state_has "system.os"                 # Verificar existencia
state_save "$file"                    # Persistir para checkpoint
state_load "$file"                    # Restaurar de checkpoint
```

Globals legadas sincronizadas via `_sync_globals_to_state()` / `_sync_state_to_globals()`.

## Design System

Paleta Catppuccin Mocha (26 cores) em `lib/colors.sh`:
- Accent: rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, green, teal, sky, sapphire, blue, lavender
- Text: text, subtext1, subtext0
- Surface: overlay2..0, surface2..0, base, mantle, crust
- Semantic: UI_SUCCESS, UI_ERROR, UI_WARNING, UI_INFO, UI_ACCENT, UI_HIGHLIGHT, UI_LINK, UI_MUTED
- Fallback: true color -> 256 -> 8 cores -> sem cores (CI/pipe)

Layout sem bordas laterais — dividers horizontais (`── TITULO ────`) + `printf` com cores inline.

## CI/CD

`.github/workflows/validate.yml` roda em push/PR:

| Job | O que faz |
|-----|-----------|
| Bash Syntax Check | `bash -n` em todos os `.sh` |
| ShellCheck | Linting com exclusoes (SC2034, SC2329, SC1091) |
| Dry Run (ubuntu) | `DRY_RUN=1 bash install.sh` |
| Dry Run (macos) | `brew install bash` + dry-run com bash 5 |
| Dry Run (windows) | dry-run com Git Bash |
| BATS Tests | 18 testes unitarios |

## Convencoes

### Funcoes
- `snake_case` para todas as funcoes
- Prefixo `_` para funcoes internas/privadas
- Prefixo `ui_` para componentes visuais
- Prefixo `state_` para gestao de estado
- Prefixo `_rv_` para helpers do RESUMO FINAL
- Prefixo `_rpt_` para helpers do dashboard

### Estado
- `state_set "namespace.key" "value"` em vez de globals
- Globals legadas sincronizadas via `_sync_globals_to_state()`
- Checkpoint salva/carrega via state automaticamente

### Cores em printf
- ANSI no **format string**: `printf "${UI_GREEN}%s${UI_RESET}" "$val"` — funciona
- ANSI no **argumento**: usar `%b` (nao `%s`): `printf "%b" "$text_with_ansi"`
- `_strip_ansi` trata literal `\033`/`\e` alem de byte ESC `\x1b`

### Como Adicionar um Novo App

1. Adicionar entrada em `lib/install_priority.sh` -> `init_app_catalog()`:
   ```bash
   APP_SOURCES[myapp]="apt:myapp,brew:myapp,winget:MyOrg.MyApp"
   ```
2. Se for GUI app, adicionar em `data/apps.sh`
3. Se for CLI tool, adicionar em `lib/tools.sh`

### Como Adicionar Config de um App

1. Criar diretorio em `shared/myapp/` com os arquivos de config
2. Adicionar `COPY_MYAPP_CONFIG=0` nas globals do `install.sh` (linha ~40-68)
3. Adicionar guard em `_auto_enable_configs()` (install.sh):
   ```bash
   myapp) [[ -f "$CONFIG_SHARED/myapp/config" ]] && COPY_MYAPP_CONFIG=1 ;;
   ```
4. Adicionar entrada em `_toggle_configs()` para toggle no RESUMO FINAL
5. Adicionar logica de copia em `apply_shared_configs()` (install.sh)
6. Adicionar logica de export em `export_configs()` (install.sh)

### Como Adicionar um Novo Package Manager

1. Criar `_install_via_newpm()` em `lib/install_priority.sh`
2. Adicionar ao `case` em `install_with_priority()`
3. Adicionar deteccao em `is_app_installed()` (install.sh)
