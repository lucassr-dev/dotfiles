# Dotfiles Installer (privado)

Este repositório é a fonte da verdade das minhas configurações.
Inclui dados sensíveis (SSH e contas Git), então deve permanecer privado.

## Instalação rápida

```bash
git clone git@github.com:lucassr-dev/.config.git ~/.config
cd ~/.config
bash install.sh
```

## Comandos

```bash
bash install.sh          # instala (repositório -> sistema)
bash install.sh export   # exporta configs (sistema -> repositório)
bash install.sh sync     # exporta + instala
bash install.sh help     # ajuda
```

## Atualizar o repo público

```bash
bash scripts/sync_public.sh
```

Opcional:

```bash
DOTFILES_PUBLIC_DIR="/caminho/para/dotfiles" bash scripts/sync_public.sh
```

Repo público: https://github.com/lucassr-dev/dotfiles

## Estrutura

- `install.sh` (orquestrador)
- `lib/` (módulos do instalador)
- `data/` (catálogos de apps e runtimes)
- `shared/` (configs compartilhadas, inclui `.ssh` e `.gitconfig-*`)
- `linux/`, `macos/`, `windows/` (configs específicas por OS)

## Observações

- Backups em `~/.dotfiles-backup-*`
- Relatório detalhado: `VERBOSE_REPORT=1 bash install.sh`
