#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="${DOTFILES_PUBLIC_DIR:-$PRIVATE_DIR/../dotfiles}"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  echo "Public repo not found: $PUBLIC_DIR" >&2
  echo "Set DOTFILES_PUBLIC_DIR to override." >&2
  exit 1
fi

if [[ ! -d "$PUBLIC_DIR/.git" ]]; then
  echo "Public repo is not a git repo: $PUBLIC_DIR" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required to sync the public repo." >&2
  exit 1
fi

rsync -a --delete \
  --exclude '.git' \
  --exclude '.gitignore' \
  --exclude 'README.md' \
  --exclude 'scripts/sync_public.sh' \
  --exclude 'shared/.ssh' \
  --exclude 'shared/git/.gitconfig-personal' \
  --exclude 'shared/git/.gitconfig-work' \
  "$PRIVATE_DIR/" "$PUBLIC_DIR/"

# Ensure public .gitignore blocks sensitive files
PUBLIC_GITIGNORE="$PUBLIC_DIR/.gitignore"
if [[ -f "$PUBLIC_GITIGNORE" ]]; then
  grep -q '^shared/.ssh/$' "$PUBLIC_GITIGNORE" || cat <<'IGNORE' >> "$PUBLIC_GITIGNORE"
shared/.ssh/
.ssh/
shared/git/.gitconfig-personal
shared/git/.gitconfig-work
IGNORE
fi

# Ensure example files exist in public repo
mkdir -p "$PUBLIC_DIR/shared/git" "$PUBLIC_DIR/shared/.ssh.example"
cat <<'EOF_PERSONAL' > "$PUBLIC_DIR/shared/git/.gitconfig-personal.example"
[user]
  name = Seu Nome
  email = seu@email.com
EOF_PERSONAL

cat <<'EOF_WORK' > "$PUBLIC_DIR/shared/git/.gitconfig-work.example"
[user]
  name = Seu Nome (Work)
  email = seu@empresa.com
EOF_WORK

cat <<'EOF_SSH' > "$PUBLIC_DIR/shared/.ssh.example/README.md"
Coloque aqui seus arquivos SSH (id_ed25519, id_ed25519.pub, known_hosts, etc.)

Este diretorio e os arquivos reais ficam no repo privado.
No repo publico, use apenas este exemplo.
EOF_SSH

echo "Public repo synced to: $PUBLIC_DIR"
