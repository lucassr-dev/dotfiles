#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Funções de suporte para winget
# ═══════════════════════════════════════════════════════════

winget_install() {
  local package_id="$1"
  local friendly_name="$2"
  local level="${3:-optional}"

  if ! has_cmd winget; then
    record_failure "$level" "winget não disponível; não foi possível instalar $friendly_name"
    return
  fi

  if winget list --id "$package_id" >/dev/null 2>&1; then
    msg "  🔄 Atualizando $friendly_name via winget..."
    if winget upgrade --id "$package_id" --accept-source-agreements --accept-package-agreements; then
      INSTALLED_MISC+=("winget: $friendly_name (upgrade)")
    fi
    return 0
  fi

  msg "  📦 Instalando $friendly_name via winget..."
  if winget install --id "$package_id" --accept-source-agreements --accept-package-agreements; then
    INSTALLED_MISC+=("winget: $friendly_name")
  else
    record_failure "$level" "Falha ao instalar via winget: $friendly_name ($package_id)"
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de dependências base no Windows
# ═══════════════════════════════════════════════════════════

install_windows_base_dependencies() {
  msg "▶ Verificando dependências Windows"

  if ! has_cmd winget; then
    record_failure "critical" "winget não encontrado. Atualize o Windows ou instale App Installer da Microsoft Store"
    return
  fi

  msg "  🔄 Atualizando fontes do winget..."
  if winget source update --accept-source-agreements; then
    INSTALLED_MISC+=("winget: source update")
  fi

  winget_install "Git.Git" "Git" "critical"
  winget_install "Microsoft.WindowsTerminal" "Windows Terminal" "critical"
  winget_install "ImageMagick.ImageMagick" "ImageMagick" "critical"
  winget_install "junegunn.fzf" "fzf" "critical"
  winget_install "charmbracelet.gum" "gum" "optional"

  if ! has_cmd curl; then
    msg "  📦 curl não encontrado, instalando..."
    winget_install "cURL.cURL" "curl" "critical"
  fi
}

install_php_windows() {
  local installed=0
  if has_cmd winget; then
    winget_install PHP.PHP "PHP" optional
    if has_cmd php; then
      installed=1
    else
      winget_install PHP.PHP.8.3 "PHP 8.3" optional
      has_cmd php && installed=1
    fi
  fi

  if [[ $installed -eq 0 ]] && has_cmd choco; then
    choco_install php "PHP (latest)" optional
    has_cmd php && installed=1
  fi

  if [[ $installed -eq 1 ]]; then
    msg "  ✅ PHP (latest) instalado/atualizado no Windows (winget/choco)"
    return 0
  fi

  record_failure "optional" "PHP não instalado no Windows: winget/choco indisponíveis ou falharam"
  return 1
}

# ═══════════════════════════════════════════════════════════
# Aplicação de configurações específicas do Windows
# ═══════════════════════════════════════════════════════════

apply_windows_configs() {
  [[ -d "$CONFIG_WINDOWS" ]] || return
  msg "▶ Copiando configs Windows"
  if [[ ${COPY_TERMINAL_CONFIG:-1} -eq 1 ]]; then
    copy_windows_terminal_settings
    copy_windows_powershell_profiles
  else
    msg "  ⏭️  Terminal config: usuário optou por não copiar"
  fi
}

copy_windows_terminal_settings() {
  local wt_settings="$CONFIG_WINDOWS/windows-terminal-settings.json"
  [[ -f "$wt_settings" ]] || return 0

  local base="${LOCALAPPDATA:-$HOME/AppData/Local}"

  local wt_stable="$base/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -d "$(dirname "$wt_stable")" ]]; then
    copy_file "$wt_settings" "$wt_stable"
  fi

  local wt_preview="$base/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -d "$(dirname "$wt_preview")" ]]; then
    copy_file "$wt_settings" "$wt_preview"
  fi

  local wt_unpackaged="$base/Microsoft/Windows Terminal/settings.json"
  if [[ -d "$(dirname "$wt_unpackaged")" ]]; then
    copy_file "$wt_settings" "$wt_unpackaged"
  fi
}

copy_windows_powershell_profiles() {
  local profile_src="$CONFIG_WINDOWS/powershell/profile.ps1"
  [[ -f "$profile_src" ]] || return

  local user_home="${USERPROFILE:-$HOME}"
  local docs="$user_home/Documents"
  if [[ ! -d "$docs" ]] && has_cmd powershell.exe; then
    local docs_win
    docs_win="$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("MyDocuments")' 2>/dev/null | tr -d '\r' || true)"
    if [[ -n "$docs_win" ]]; then
      if has_cmd wslpath; then
        docs="$(wslpath -u "$docs_win" 2>/dev/null || echo "$docs")"
      elif has_cmd cygpath; then
        docs="$(cygpath -u "$docs_win" 2>/dev/null || echo "$docs")"
      fi
    fi
  fi

  copy_file "$profile_src" "$docs/PowerShell/Microsoft.PowerShell_profile.ps1"
  copy_file "$profile_src" "$docs/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
}

export_windows_configs_back() {
  local base="${LOCALAPPDATA:-$HOME/AppData/Local}"

  local wt_stable="$base/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -f "$wt_stable" ]]; then
    export_file "$wt_stable" "$CONFIG_WINDOWS/windows-terminal-settings.json"
  fi

  local ps_profile="${USERPROFILE:-$HOME}/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
  if [[ -f "$ps_profile" ]]; then
    export_file "$ps_profile" "$CONFIG_WINDOWS/powershell/profile.ps1"
  fi
}

# ═══════════════════════════════════════════════════════════
# Helper: instalar app usando o catálogo ou fallback para winget
# ═══════════════════════════════════════════════════════════

_install_windows_app() {
  local app="$1"
  local cmd_check="${2:-$app}"
  local winget_id="${3:-}"
  local winget_name="${4:-$app}"

  if is_app_processed "$app"; then
    return 0
  fi
  mark_app_processed "$app"

  if [[ -n "${APP_SOURCES[$app]:-}" ]]; then
    install_with_priority "$app" "$cmd_check" optional
  elif [[ -n "$winget_id" ]]; then
    winget_install "$winget_id" "$winget_name" optional
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de apps selecionados no Windows
# ═══════════════════════════════════════════════════════════

install_windows_selected_apps() {
  if ! has_cmd winget; then
    warn "winget não disponível, pulando instalação de apps"
    return
  fi

  msg "▶ Instalando apps selecionados (Windows)"

  for ide in "${SELECTED_IDES[@]}"; do
    case "$ide" in
      vscode) _install_windows_app vscode code "Microsoft.VisualStudioCode" "VS Code" ;;
      zed) _install_windows_app zed zed "Zed.Zed" "Zed" ;;
      cursor) msg "  ℹ️  Cursor deve ser instalado manualmente: https://cursor.sh" ;;
      neovim) _install_windows_app neovim nvim "Neovim.Neovim" "Neovim" ;;
      sublime-text) _install_windows_app sublime-text subl "SublimeHQ.SublimeText.4" "Sublime Text" ;;
      android-studio) _install_windows_app android-studio studio "Google.AndroidStudio" "Android Studio" ;;
      intellij-idea) msg "  ℹ️  IntelliJ IDEA: use JetBrains Toolbox para instalar." ;;
      pycharm) msg "  ℹ️  PyCharm: use JetBrains Toolbox para instalar." ;;
      webstorm) msg "  ℹ️  WebStorm: use JetBrains Toolbox para instalar." ;;
      phpstorm) msg "  ℹ️  PhpStorm: use JetBrains Toolbox para instalar." ;;
      goland) msg "  ℹ️  GoLand: use JetBrains Toolbox para instalar." ;;
      rubymine) msg "  ℹ️  RubyMine: use JetBrains Toolbox para instalar." ;;
      clion) msg "  ℹ️  CLion: use JetBrains Toolbox para instalar." ;;
      rider) msg "  ℹ️  Rider: use JetBrains Toolbox para instalar." ;;
      datagrip) msg "  ℹ️  DataGrip: use JetBrains Toolbox para instalar." ;;
    esac
  done

  for terminal in "${SELECTED_TERMINALS[@]}"; do
    case "$terminal" in
      windows-terminal) ;;
      wezterm) _install_windows_app wezterm wezterm "wez.wezterm" "WezTerm" ;;
      alacritty) _install_windows_app alacritty alacritty "Alacritty.Alacritty" "Alacritty" ;;
      kitty) msg "  ℹ️  Kitty no Windows: visite https://sw.kovidgoyal.net/kitty/" ;;
    esac
  done

  for browser in "${SELECTED_BROWSERS[@]}"; do
    case "$browser" in
      firefox) _install_windows_app firefox firefox "Mozilla.Firefox" "Firefox" ;;
      chrome) _install_windows_app chrome chrome "Google.Chrome" "Chrome" ;;
      brave) _install_windows_app brave brave "Brave.Brave" "Brave" ;;
      arc) _install_windows_app arc arc "TheBrowserCompany.Arc" "Arc" ;;
      vivaldi) _install_windows_app vivaldi vivaldi "VivaldiTechnologies.Vivaldi" "Vivaldi" ;;
      edge) _install_windows_app edge edge "Microsoft.Edge" "Edge" ;;
      opera) _install_windows_app opera opera "Opera.Opera" "Opera" ;;
      librewolf) _install_windows_app librewolf librewolf "LibreWolf.LibreWolf" "LibreWolf" ;;
    esac
  done

  for tool in "${SELECTED_DEV_TOOLS[@]}"; do
    case "$tool" in
      docker) _install_windows_app docker docker "Docker.DockerDesktop" "Docker Desktop" ;;
      postman) _install_windows_app postman postman "Postman.Postman" "Postman" ;;
      dbeaver) _install_windows_app dbeaver dbeaver "dbeaver.dbeaver" "DBeaver" ;;
      bruno) _install_windows_app bruno bruno "Bruno.Bruno" "Bruno" ;;
      insomnia) _install_windows_app insomnia insomnia "Insomnia.Insomnia" "Insomnia" ;;
      gitkraken) _install_windows_app gitkraken gitkraken "Axosoft.GitKraken" "GitKraken" ;;
      mongodb-compass) _install_windows_app mongodb-compass "MongoDB Compass" "MongoDB.Compass.Full" "MongoDB Compass" ;;
      redis-insight) install_redis_insight ;;
    esac
  done

  for db in "${SELECTED_DATABASES[@]}"; do
    case "$db" in
      postgresql) _install_windows_app postgresql psql "PostgreSQL.PostgreSQL" "PostgreSQL" ;;
      redis) _install_windows_app redis redis-cli "Redis.Redis" "Redis" ;;
      mysql) _install_windows_app mysql mysql "Oracle.MySQL" "MySQL" ;;
      mariadb) _install_windows_app mariadb mariadb "MariaDB.Server" "MariaDB" ;;
      mongodb) _install_windows_app mongodb mongod "MongoDB.Compass" "MongoDB Compass" ;;
    esac
  done

  for app in "${SELECTED_PRODUCTIVITY[@]}"; do
    case "$app" in
      slack) _install_windows_app slack slack "SlackTechnologies.Slack" "Slack" ;;
      notion) _install_windows_app notion notion "Notion.Notion" "Notion" ;;
      obsidian) _install_windows_app obsidian obsidian "Obsidian.Obsidian" "Obsidian" ;;
      logseq) _install_windows_app logseq logseq "Logseq.Logseq" "Logseq" ;;
      anki) _install_windows_app anki anki "Anki.Anki" "Anki" ;;
      joplin) _install_windows_app joplin joplin "Joplin.Joplin" "Joplin" ;;
      appflowy) _install_windows_app appflowy appflowy "AppFlowy.AppFlowy" "AppFlowy" ;;
    esac
  done

  for app in "${SELECTED_COMMUNICATION[@]}"; do
    case "$app" in
      discord) _install_windows_app discord discord "Discord.Discord" "Discord" ;;
      telegram) _install_windows_app telegram telegram "Telegram.TelegramDesktop" "Telegram" ;;
      whatsapp) _install_windows_app whatsapp whatsapp "WhatsApp.WhatsApp" "WhatsApp" ;;
      signal) _install_windows_app signal signal "OpenWhisperSystems.Signal" "Signal" ;;
      teams) _install_windows_app teams teams "Microsoft.Teams" "Teams" ;;
      zoom) _install_windows_app zoom zoom "Zoom.Zoom" "Zoom" ;;
      thunderbird) _install_windows_app thunderbird thunderbird "Mozilla.Thunderbird" "Thunderbird" ;;
    esac
  done

  for app in "${SELECTED_MEDIA[@]}"; do
    case "$app" in
      vlc) _install_windows_app vlc vlc "VideoLAN.VLC" "VLC" ;;
      spotify) _install_windows_app spotify spotify "Spotify.Spotify" "Spotify" ;;
      obs-studio) _install_windows_app obs-studio obs "OBSProject.OBSStudio" "OBS Studio" ;;
      gimp) _install_windows_app gimp gimp "GIMP.GIMP" "GIMP" ;;
      inkscape) _install_windows_app inkscape inkscape "Inkscape.Inkscape" "Inkscape" ;;
      blender) _install_windows_app blender blender "BlenderFoundation.Blender" "Blender" ;;
      audacity) _install_windows_app audacity audacity "Audacity.Audacity" "Audacity" ;;
      kdenlive) _install_windows_app kdenlive kdenlive "KDE.Kdenlive" "Kdenlive" ;;
    esac
  done

  for app in "${SELECTED_UTILITIES[@]}"; do
    case "$app" in
      powertoys) winget_install "Microsoft.PowerToys" "PowerToys" optional ;;
      sharex) winget_install "ShareX.ShareX" "ShareX" optional ;;
      bitwarden) _install_windows_app bitwarden bitwarden "Bitwarden.Bitwarden" "Bitwarden" ;;
      1password) _install_windows_app 1password 1password "AgileBits.1Password" "1Password" ;;
      keepassxc) _install_windows_app keepassxc keepassxc "KeePassXCTeam.KeePassXC" "KeePassXC" ;;
      syncthing) _install_windows_app syncthing syncthing "Syncthing.Syncthing" "Syncthing" ;;
    esac
  done
}
