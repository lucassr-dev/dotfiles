#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════
# IDEs e Editores de Código
# ═══════════════════════════════════════════════════════════

install_zed() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask zed optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app dev.zed.Zed "Zed" zed zed optional
      else
        warn "Zed requer Flatpak no Linux"
      fi
      ;;
    windows)
      winget_install "Zed.Zed" "Zed" optional
      ;;
  esac
}

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

install_neovim() {
  case "$TARGET_OS" in
    macos)
      brew_install neovim optional
      ;;
    linux|wsl2)
      install_linux_packages optional neovim
      ;;
    windows)
      winget_install "Neovim.Neovim" "Neovim" optional
      ;;
  esac
}

install_sublime_text() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask sublime-text optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.sublimetext.three "Sublime Text" sublime-text sublime optional
      fi
      ;;
    windows)
      winget_install "SublimeHQ.SublimeText.4" "Sublime Text" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Navegadores Web
# ═══════════════════════════════════════════════════════════

install_arc() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask arc optional
      ;;
    windows)
      winget_install "TheBrowserCompany.Arc" "Arc" optional
      ;;
    *)
      warn "Arc ainda não disponível para $TARGET_OS"
      ;;
  esac
}

install_vivaldi() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask vivaldi optional
      ;;
    linux|wsl2)
      install_linux_packages optional vivaldi-stable
      ;;
    windows)
      winget_install "VivaldiTechnologies.Vivaldi" "Vivaldi" optional
      ;;
  esac
}

install_edge() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask microsoft-edge optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.microsoft.Edge "Microsoft Edge" microsoft-edge edge optional
      fi
      ;;
    windows)
      winget_install "Microsoft.Edge" "Microsoft Edge" optional
      ;;
  esac
}

install_opera() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask opera optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.opera.Opera "Opera" opera opera optional
      fi
      ;;
    windows)
      winget_install "Opera.Opera" "Opera" optional
      ;;
  esac
}

install_librewolf() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask librewolf optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app io.gitlab.librewolf-community "LibreWolf" librewolf librewolf optional
      fi
      ;;
    windows)
      winget_install "LibreWolf.LibreWolf" "LibreWolf" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Ferramentas de Desenvolvimento
# ═══════════════════════════════════════════════════════════

install_bruno() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask bruno optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.usebruno.Bruno "Bruno" bruno bruno optional
      fi
      ;;
    windows)
      winget_install "Bruno.Bruno" "Bruno" optional
      ;;
  esac
}

install_insomnia() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask insomnia optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app rest.insomnia.Insomnia "Insomnia" insomnia insomnia optional
      fi
      ;;
    windows)
      winget_install "Insomnia.Insomnia" "Insomnia" optional
      ;;
  esac
}

install_gitkraken() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask gitkraken optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.axosoft.GitKraken "GitKraken" gitkraken gitkraken optional
      fi
      ;;
    windows)
      winget_install "Axosoft.GitKraken" "GitKraken" optional
      ;;
  esac
}

install_mongodb_compass() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask mongodb-compass optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.mongodb.Compass "MongoDB Compass" mongodb-compass mongodb-compass optional
      fi
      ;;
    windows)
      winget_install "MongoDB.Compass.Full" "MongoDB Compass" optional
      ;;
  esac
}

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

# ═══════════════════════════════════════════════════════════
# Bancos de Dados
# ═══════════════════════════════════════════════════════════

install_mariadb() {
  case "$TARGET_OS" in
    macos)
      brew_install mariadb optional
      ;;
    linux|wsl2)
      install_linux_packages optional mariadb-server
      ;;
    windows)
      winget_install "MariaDB.Server" "MariaDB" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Produtividade e Organização
# ═══════════════════════════════════════════════════════════

install_logseq() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask logseq optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.logseq.Logseq "Logseq" logseq logseq optional
      fi
      ;;
    windows)
      winget_install "Logseq.Logseq" "Logseq" optional
      ;;
  esac
}

install_anki() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask anki optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app net.ankiweb.Anki "Anki" anki anki optional
      fi
      ;;
    windows)
      winget_install "Anki.Anki" "Anki" optional
      ;;
  esac
}

install_joplin() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask joplin optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app net.cozic.joplin_desktop "Joplin" joplin joplin optional
      fi
      ;;
    windows)
      winget_install "Joplin.Joplin" "Joplin" optional
      ;;
  esac
}

install_appflowy() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask appflowy optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app io.appflowy.AppFlowy "AppFlowy" appflowy appflowy optional
      fi
      ;;
    windows)
      winget_install "AppFlowy.AppFlowy" "AppFlowy" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Comunicação e Colaboração
# ═══════════════════════════════════════════════════════════

install_telegram() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask telegram optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.telegram.desktop "Telegram" telegram telegram optional
      fi
      ;;
    windows)
      winget_install "Telegram.TelegramDesktop" "Telegram" optional
      ;;
  esac
}

install_whatsapp() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask whatsapp optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app io.github.mimbrero.WhatsAppDesktop "WhatsApp" whatsapp whatsapp optional
      fi
      ;;
    windows)
      winget_install "WhatsApp.WhatsApp" "WhatsApp" optional
      ;;
  esac
}

install_signal() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask signal optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.signal.Signal "Signal" signal signal optional
      fi
      ;;
    windows)
      winget_install "OpenWhisperSystems.Signal" "Signal" optional
      ;;
  esac
}

install_teams() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask microsoft-teams optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.github.IsmaelMartinez.teams_for_linux "Teams" teams teams optional
      fi
      ;;
    windows)
      winget_install "Microsoft.Teams" "Microsoft Teams" optional
      ;;
  esac
}

install_zoom() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask zoom optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app us.zoom.Zoom "Zoom" zoom zoom optional
      fi
      ;;
    windows)
      winget_install "Zoom.Zoom" "Zoom" optional
      ;;
  esac
}

install_thunderbird() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask thunderbird optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.mozilla.Thunderbird "Thunderbird" thunderbird thunderbird optional
      fi
      ;;
    windows)
      winget_install "Mozilla.Thunderbird" "Thunderbird" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Mídia e Entretenimento
# ═══════════════════════════════════════════════════════════

install_obs_studio() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask obs optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.obsproject.Studio "OBS Studio" obs-studio obs optional
      fi
      ;;
    windows)
      winget_install "OBSProject.OBSStudio" "OBS Studio" optional
      ;;
  esac
}

install_gimp() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask gimp optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.gimp.GIMP "GIMP" gimp gimp optional
      fi
      ;;
    windows)
      winget_install "GIMP.GIMP" "GIMP" optional
      ;;
  esac
}

install_inkscape() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask inkscape optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.inkscape.Inkscape "Inkscape" inkscape inkscape optional
      fi
      ;;
    windows)
      winget_install "Inkscape.Inkscape" "Inkscape" optional
      ;;
  esac
}

install_blender() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask blender optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.blender.Blender "Blender" blender blender optional
      fi
      ;;
    windows)
      winget_install "BlenderFoundation.Blender" "Blender" optional
      ;;
  esac
}

install_audacity() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask audacity optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.audacityteam.Audacity "Audacity" audacity audacity optional
      fi
      ;;
    windows)
      winget_install "Audacity.Audacity" "Audacity" optional
      ;;
  esac
}

install_kdenlive() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask kdenlive optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.kde.kdenlive "Kdenlive" kdenlive kdenlive optional
      fi
      ;;
    windows)
      winget_install "KDE.Kdenlive" "Kdenlive" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Utilitários
# ═══════════════════════════════════════════════════════════

install_flameshot() {
  case "$TARGET_OS" in
    macos)
      brew_install flameshot optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.flameshot.Flameshot "Flameshot" flameshot flameshot optional
      else
        install_linux_packages optional flameshot
      fi
      ;;
    windows)
      warn "Flameshot não está disponível para Windows. Use ShareX."
      ;;
  esac
}

install_bitwarden() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask bitwarden optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.bitwarden.desktop "Bitwarden" bitwarden bitwarden optional
      fi
      ;;
    windows)
      winget_install "Bitwarden.Bitwarden" "Bitwarden" optional
      ;;
  esac
}

install_1password() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask 1password optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app com.1password.1Password "1Password" 1password 1password optional
      fi
      ;;
    windows)
      winget_install "AgileBits.1Password" "1Password" optional
      ;;
  esac
}

install_keepassxc() {
  case "$TARGET_OS" in
    macos)
      brew_install_cask keepassxc optional
      ;;
    linux|wsl2)
      if has_cmd flatpak; then
        ensure_flatpak_app org.keepassxc.KeePassXC "KeePassXC" keepassxc keepassxc optional
      fi
      ;;
    windows)
      winget_install "KeePassXCTeam.KeePassXC" "KeePassXC" optional
      ;;
  esac
}

install_syncthing() {
  case "$TARGET_OS" in
    macos)
      brew_install syncthing optional
      ;;
    linux|wsl2)
      install_linux_packages optional syncthing
      ;;
    windows)
      winget_install "Syncthing.Syncthing" "Syncthing" optional
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Utilitários específicos por OS
# ═══════════════════════════════════════════════════════════

install_powertoys() {
  [[ "$TARGET_OS" != "windows" ]] && return
  winget_install "Microsoft.PowerToys" "PowerToys" optional
}

install_sharex() {
  [[ "$TARGET_OS" != "windows" ]] && return
  winget_install "ShareX.ShareX" "ShareX" optional
}

install_rectangle() {
  [[ "$TARGET_OS" != "macos" ]] && return
  brew_install_cask rectangle optional
}

install_alfred() {
  [[ "$TARGET_OS" != "macos" ]] && return
  brew_install_cask alfred optional
}
