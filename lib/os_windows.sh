#!/usr/bin/env bash
# Instaladores e configurações específicas do Windows
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Anti-duplicidade: rastrear apps já processados nesta execução
# ═══════════════════════════════════════════════════════════

declare -A APPS_PROCESSED

mark_app_processed() {
  local app="$1"
  APPS_PROCESSED["$app"]=1
}

is_app_processed() {
  local app="$1"
  [[ "${APPS_PROCESSED[$app]:-0}" == "1" ]]
}

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
    if winget upgrade --id "$package_id" --silent --accept-source-agreements --accept-package-agreements >/dev/null 2>&1; then
      INSTALLED_MISC+=("winget: $friendly_name (upgrade)")
    fi
    return 0
  fi

  msg "  📦 Instalando $friendly_name via winget..."
  if winget install --id "$package_id" --silent --accept-source-agreements --accept-package-agreements >/dev/null 2>&1; then
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

  if winget source update --accept-source-agreements >/dev/null 2>&1; then
    INSTALLED_MISC+=("winget: source update")
  fi

  winget_install "Git.Git" "Git" "critical"
  winget_install "Microsoft.WindowsTerminal" "Windows Terminal" "critical"
  winget_install "ImageMagick.ImageMagick" "ImageMagick" "critical"
  winget_install "junegunn.fzf" "fzf" "critical"

  if ! has_cmd curl; then
    msg "  📦 curl não encontrado, instalando..."
    winget_install "cURL.cURL" "curl" "critical"
  fi
}

# ═══════════════════════════════════════════════════════════
# Aplicação de configurações específicas do Windows
# ═══════════════════════════════════════════════════════════

apply_windows_configs() {
  [[ -d "$CONFIG_WINDOWS" ]] || return
  msg "▶ Copiando configs Windows"

  copy_windows_terminal_settings
  copy_powershell_profile
}

copy_windows_terminal_settings() {
  local wt_settings="$CONFIG_WINDOWS/windows-terminal-settings.json"
  [[ -f "$wt_settings" ]] || return

  local base="${LOCALAPPDATA:-}"
  if [[ -z "$base" ]]; then
    base="$HOME/AppData/Local"
  fi

  local wt_stable="$base/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -d "$(dirname "$wt_stable")" ]]; then
    copy_file "$wt_settings" "$wt_stable"
  fi

  local wt_preview="$base/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -d "$(dirname "$wt_preview")" ]]; then
    copy_file "$wt_settings" "$wt_preview"
  fi
}

copy_powershell_profile() {
  local ps_profile_src="$CONFIG_WINDOWS/powershell/profile.ps1"
  [[ -f "$ps_profile_src" ]] || return

  local docs="${USERPROFILE:-$HOME}/Documents"
  [[ -d "$docs" ]] || docs="$HOME/Documents"

  copy_file "$ps_profile_src" "$docs/PowerShell/Microsoft.PowerShell_profile.ps1"
  copy_file "$ps_profile_src" "$docs/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
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
# Instalação de apps selecionados no Windows via winget
# ═══════════════════════════════════════════════════════════

install_windows_selected_apps() {
  if ! has_cmd winget; then
    warn "winget não disponível, pulando instalação de apps"
    return
  fi

  msg "▶ Instalando apps selecionados via winget"

  for ide in "${SELECTED_IDES[@]}"; do
    if is_app_processed "$ide"; then
      continue
    fi
    mark_app_processed "$ide"

    case "$ide" in
      vscode) install_vscode_windows ;;
      zed) winget_install "Zed.Zed" "Zed" ;;
      cursor) msg "  ℹ️  Cursor deve ser instalado manualmente: https://cursor.sh" ;;
      neovim) winget_install "Neovim.Neovim" "Neovim" ;;
      intellij-idea) msg "  ℹ️  IntelliJ IDEA: use JetBrains Toolbox para instalar." ;;
      pycharm) msg "  ℹ️  PyCharm: use JetBrains Toolbox para instalar." ;;
      webstorm) msg "  ℹ️  WebStorm: use JetBrains Toolbox para instalar." ;;
      phpstorm) msg "  ℹ️  PhpStorm: use JetBrains Toolbox para instalar." ;;
      goland) msg "  ℹ️  GoLand: use JetBrains Toolbox para instalar." ;;
      rubymine) msg "  ℹ️  RubyMine: use JetBrains Toolbox para instalar." ;;
      clion) msg "  ℹ️  CLion: use JetBrains Toolbox para instalar." ;;
      rider) msg "  ℹ️  Rider: use JetBrains Toolbox para instalar." ;;
      datagrip) msg "  ℹ️  DataGrip: use JetBrains Toolbox para instalar." ;;
      sublime-text) winget_install "SublimeHQ.SublimeText.4" "Sublime Text" ;;
      android-studio) winget_install "Google.AndroidStudio" "Android Studio" ;;
      *) warn "IDE sem instalador automático no Windows: $ide" ;;
    esac
  done

  for terminal in "${SELECTED_TERMINALS[@]}"; do
    if is_app_processed "$terminal"; then
      continue
    fi
    mark_app_processed "$terminal"

    case "$terminal" in
      windows-terminal) ;;
      wezterm)
        winget_install "wez.wezterm" "WezTerm"
        ;;
      kitty)
        msg "  ℹ️  Kitty no Windows: visite https://sw.kovidgoyal.net/kitty/"
        ;;
      alacritty)
        winget_install "Alacritty.Alacritty" "Alacritty"
        ;;
    esac
  done

  for browser in "${SELECTED_BROWSERS[@]}"; do
    if is_app_processed "$browser"; then
      continue
    fi
    mark_app_processed "$browser"

    case "$browser" in
      firefox) winget_install "Mozilla.Firefox" "Firefox" ;;
      chrome) winget_install "Google.Chrome" "Google Chrome" ;;
      brave) winget_install "Brave.Brave" "Brave" ;;
      arc) winget_install "TheBrowserCompany.Arc" "Arc" ;;
    esac
  done

  for tool in "${SELECTED_DEV_TOOLS[@]}"; do
    if is_app_processed "$tool"; then
      continue
    fi
    mark_app_processed "$tool"

    case "$tool" in
      vscode) install_vscode_windows ;;
      docker) winget_install "Docker.DockerDesktop" "Docker Desktop" ;;
      postman) winget_install "Postman.Postman" "Postman" ;;
      dbeaver) winget_install "dbeaver.dbeaver" "DBeaver" ;;
    esac
  done

  for db in "${SELECTED_DATABASES[@]}"; do
    if is_app_processed "$db"; then
      continue
    fi
    mark_app_processed "$db"

    case "$db" in
      postgresql) winget_install "PostgreSQL.PostgreSQL" "PostgreSQL" ;;
      redis) winget_install "Redis.Redis" "Redis" ;;
      mysql) winget_install "Oracle.MySQL" "MySQL" ;;
      mongodb) winget_install "MongoDB.Compass" "MongoDB Compass" ;;
    esac
  done

  for app in "${SELECTED_PRODUCTIVITY[@]}"; do
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      slack) winget_install "SlackTechnologies.Slack" "Slack" ;;
      notion) winget_install "Notion.Notion" "Notion" ;;
      obsidian) winget_install "Obsidian.Obsidian" "Obsidian" ;;
    esac
  done

  for app in "${SELECTED_COMMUNICATION[@]}"; do
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      discord) winget_install "Discord.Discord" "Discord" ;;
    esac
  done

  for app in "${SELECTED_MEDIA[@]}"; do
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      vlc) winget_install "VideoLAN.VLC" "VLC" ;;
      spotify) winget_install "Spotify.Spotify" "Spotify" ;;
    esac
  done

  for app in "${SELECTED_UTILITIES[@]}"; do
    if is_app_processed "$app"; then
      continue
    fi
    mark_app_processed "$app"

    case "$app" in
      powertoys) winget_install "Microsoft.PowerToys" "PowerToys" ;;
      sharex) winget_install "ShareX.ShareX" "ShareX" ;;
      bitwarden) winget_install "Bitwarden.Bitwarden" "Bitwarden" ;;
      1password) winget_install "AgileBits.1Password" "1Password" ;;
      keepassxc) winget_install "KeePassXCTeam.KeePassXC" "KeePassXC" ;;
      *) warn "Utilitário sem instalador automático no Windows: $app" ;;
    esac
  done
}
