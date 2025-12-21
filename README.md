# Dotfiles Installer

Script interativo para instalar e configurar ambiente de desenvolvimento em
Linux, macOS, Windows e WSL2.

## Instalação rápida

```bash
git clone https://github.com/lucassr-dev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash install.sh
```

## O que o script faz

- Instala shells (Zsh/Fish) e temas
- Configura plugins e presets
- Instala CLI Tools e IA Tools (opcional)
- Instala terminais e apps GUI por categoria
- Configura Git multi-conta (opcional)
- Instala runtimes via mise (opcional)
- Faz backup automático das configs atuais

## Comandos

```bash
bash install.sh          # instala (repositório -> sistema)
bash install.sh export   # exporta configs (sistema -> repositório)
bash install.sh sync     # exporta + instala
bash install.sh help     # ajuda
```

Observação: `export` e `sync` são úteis se você mantém um fork ou quer guardar
suas configurações no próprio repositório. Se só quer instalar, use `install`.

## Segurança

- Coloque suas chaves SSH em `~/.ssh` (não são versionadas)
- As informações de Git multi-conta são configuradas no assistente e ficam
  no seu sistema

## Estrutura

- `install.sh` (orquestrador)
- `lib/` (módulos do instalador)
- `data/` (catálogos de apps e runtimes)
- `shared/` (configs compartilhadas)
- `linux/`, `macos/`, `windows/` (configs específicas por OS)

## Dica

Relatório detalhado após a instalação:

```bash
VERBOSE_REPORT=1 bash install.sh
```
