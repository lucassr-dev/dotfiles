#!/usr/bin/env bash
set -uo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# Auditoria das fontes de instalacao contra os registries reais
# ══════════════════════════════════════════════════════════════════════════════
#
# Cada entrada de APP_SOURCES aponta para um pacote num registry de terceiro:
# uma formula do Homebrew, um ID do winget, um crate. Esses nomes MUDAM sem
# aviso — uma formula vira versionada, um publisher e renomeado, um pacote sai.
# Quando isso acontece, o instalador falha so na maquina de quem tentou usar,
# e normalmente com uma mensagem que nao diz o que aconteceu.
#
# Os testes de tests/test_crossplat.bats provam que o ID do catalogo chega
# INTACTO ao comando de instalacao. Nao provam que ele EXISTE — para isso
# precisa de rede, que nao cabe em teste unitario. Este script cobre essa metade.
#
# Rode de vez em quando, e sempre depois de acrescentar app ao catalogo.
#
#   bash scripts/audit_catalog_sources.sh            # tudo
#   bash scripts/audit_catalog_sources.sh brew       # so uma fonte
#
# Achados de Set/2026, para calibrar expectativa: 361 fontes auditadas, 7 erros
# reais — postgresql (formula sem versao removida do brew), zen-browser (cask
# chama-se zen), e cinco IDs de winget com publisher errado ou inexistente.
# ══════════════════════════════════════════════════════════════════════════════

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTRO="${1:-}"
ERROS=0
VERIFICADOS=0

if ! command -v curl >/dev/null 2>&1; then
  echo "curl e necessario para esta auditoria." >&2
  exit 2
fi

GH_AUTENTICADO=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  GH_AUTENTICADO=1
else
  echo "⚠️  gh nao autenticado: a checagem de winget vai usar a API anonima do" >&2
  echo "    GitHub, limitada a 60 requisicoes por hora. Com mais IDs que isso," >&2
  echo "    os excedentes aparecem como inexistentes. Rode 'gh auth login'." >&2
  echo "" >&2
fi

# shellcheck source=../lib/install_priority.sh
source "$ROOT_DIR/lib/install_priority.sh"
init_app_catalog

_ok()   { printf '  \033[32m✓\033[0m %-14s %s\n' "$1" "$2"; }
_falha() { printf '  \033[31m✗\033[0m %-14s %s  → %s\n' "$1" "$2" "$3"; ERROS=$((ERROS+1)); }

# Homebrew: a API cobre formulas e casks, mas NAO cobre tap de terceiro
# (confirmado: homebrew/core/git tambem da 404). Tap e pulado, nao reprovado.
_checa_brew() {
  local pkg="${1%% *}" app="$2"
  case "$pkg" in */*) printf '  \033[33m-\033[0m %-14s %s  (tap: a API nao indexa)\n' brew "$pkg"; return 0 ;; esac
  VERIFICADOS=$((VERIFICADOS+1))
  if curl -sf --max-time 10 "https://formulae.brew.sh/api/formula/${pkg}.json" >/dev/null 2>&1 \
  || curl -sf --max-time 10 "https://formulae.brew.sh/api/cask/${pkg}.json" >/dev/null 2>&1; then
    return 0
  fi
  _falha brew "$pkg" "nao existe (app: $app)"
}

# winget: os manifests do repositorio oficial sao a fonte da verdade. O caminho
# e manifests/<letra minuscula do publisher>/<Publisher>/<Pacote>, com a caixa
# exata — por isso a checagem tambem pega divergencia de caixa.
_checa_winget() {
  local id="$1" app="$2" pub letra caminho
  VERIFICADOS=$((VERIFICADOS+1))
  pub="$(printf '%s' "$id" | cut -d. -f1)"
  letra="$(printf '%s' "$pub" | cut -c1 | tr 'A-Z' 'a-z')"
  caminho="manifests/${letra}/$(printf '%s' "$id" | tr '.' '/')"

  # A API do GitHub sem autenticacao permite 60 requisicoes por hora — menos que
  # o numero de IDs aqui. Estourando o limite, TODOS passam a "nao existir", o
  # que parece catastrofe e nao e. Com o `gh` autenticado sao 5.000/hora.
  if [[ "$GH_AUTENTICADO" -eq 1 ]]; then
    gh api "repos/microsoft/winget-pkgs/contents/${caminho}" --jq '.[0].name' >/dev/null 2>&1 && return 0
  else
    curl -sf --max-time 10 "https://api.github.com/repos/microsoft/winget-pkgs/contents/${caminho}" >/dev/null 2>&1 && return 0
  fi
  _falha winget "$id" "nao existe com esta caixa (app: $app)"
}

# crates.io recusa requisicao sem User-Agent — sem ele TODO crate parece
# inexistente, inclusive os obvios. Validado com um controle: um nome inventado
# continua dando 404 com o UA, entao a checagem distingue de fato.
UA="dotfiles-audit/1.0 (+https://github.com/lucassr-dev/dotfiles)"

_checa_cargo() {
  local crate="$1" app="$2"
  VERIFICADOS=$((VERIFICADOS+1))
  curl -sf --max-time 10 -A "$UA" "https://crates.io/api/v1/crates/${crate}" >/dev/null 2>&1 \
    || _falha cargo "$crate" "nao existe (app: $app)"
}

echo "▶ Auditando as fontes de APP_SOURCES contra os registries"
echo ""

for app in "${!APP_SOURCES[@]}"; do
  IFS=',' read -ra fontes <<< "${APP_SOURCES[$app]}"
  for entrada in "${fontes[@]}"; do
    fonte="${entrada%%:*}"
    pkg="${entrada#*:}"
    [[ -n "$FILTRO" && "$fonte" != "$FILTRO" ]] && continue
    case "$fonte" in
      brew)   _checa_brew   "$pkg" "$app" ;;
      winget) _checa_winget "$pkg" "$app" ;;
      cargo)  _checa_cargo  "$pkg" "$app" ;;
      *) : ;;  # apt/dnf/pacman/flatpak/snap dependem do repositorio da maquina
    esac
  done
done

echo ""
if [[ "$ERROS" -eq 0 ]]; then
  echo "✅ $VERIFICADOS fontes verificadas, nenhuma quebrada."
else
  echo "❌ $VERIFICADOS fontes verificadas, $ERROS quebrada(s)."
fi
exit "$ERROS"
