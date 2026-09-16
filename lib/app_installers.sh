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
        msg "  📥 Baixe Cursor manualmente em: https://cursor.com"
      fi
      ;;
    linux|wsl2)
      if ! has_cmd cursor; then
        msg "  📥 Baixe Cursor AppImage em: https://cursor.com"
      fi
      ;;
    windows)
      if ! has_cmd cursor; then
        msg "  📥 Baixe Cursor em: https://cursor.com"
      fi
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Devin Desktop - IDE AI-first da Cognition (ex-Windsurf, rebrand de 02/06/2026)
# ─────────────────────────────────────────────────────────────────────────────

install_devin_desktop() {
  case "$TARGET_OS" in
    macos)
      # Cask antigo era "windsurf" (removido do homebrew-cask); a Cognition
      # publicou o cask "devin-desktop" no lugar dele.
      brew_install_cask devin-desktop optional
      ;;
    linux|wsl2)
      if ! has_cmd devin-desktop; then
        msg "  📥 Baixe Devin Desktop em: https://devin.ai/desktop"
      fi
      ;;
    windows)
      if has_cmd winget; then
        winget_install "CognitionAI.DevinDesktop" "Devin Desktop" optional
      else
        msg "  📥 Baixe Devin Desktop em: https://devin.ai/desktop"
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
      winget_install "RedisInsight.RedisInsight" "Redis Insight" optional
      ;;
  esac
}
