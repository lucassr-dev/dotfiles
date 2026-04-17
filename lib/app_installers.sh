#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════════════════════════
# Instaladores especiais de apps (casos que requerem tratamento manual)
# ═══════════════════════════════════════════════════════════════════════════════


# ─────────────────────────────────────────────────────────────────────────────
# Cursor - IDE baseada em VS Code com IA integrada
# ─────────────────────────────────────────────────────────────────────────────

install_cursor() {
  case "$TARGET_OS" in
    macos)
      if ! has_cmd cursor; then
        msg "  📥 Baixe Cursor manualmente em: https://cursor.sh"
      fi
      ;;
    linux|wsl2)
      if ! has_cmd cursor; then
        msg "  📥 Baixe Cursor AppImage em: https://cursor.sh"
      fi
      ;;
    windows)
      if ! has_cmd cursor; then
        msg "  📥 Baixe Cursor em: https://cursor.sh"
      fi
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Windsurf - IDE AI-first da Codeium (tem installers nativos)
# ─────────────────────────────────────────────────────────────────────────────

install_windsurf() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask windsurf optional
      ;;
    linux|wsl2)
      if ! has_cmd windsurf; then
        msg "  📥 Baixe Windsurf em: https://codeium.com/windsurf"
      fi
      ;;
    windows)
      if has_cmd winget; then
        winget_install "Codeium.Windsurf" "Windsurf" optional
      else
        msg "  📥 Baixe Windsurf em: https://codeium.com/windsurf"
      fi
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Redis Insight - GUI para Redis (download manual no Linux)
# ─────────────────────────────────────────────────────────────────────────────

install_redis_insight() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask redis-insight optional
      ;;
    linux|wsl2)
      msg "  📥 Baixe RedisInsight em: https://redis.io/insight/"
      ;;
    windows)
      winget_install "RedisLabs.RedisInsight" "Redis Insight" optional
      ;;
  esac
}
