#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ═══════════════════════════════════════════════════════════════════════════════
# Sistema de Prioridade de Instalação
# ═══════════════════════════════════════════════════════════════════════════════
#
# Ordem de prioridade configurável por OS via variáveis de ambiente:
#   INSTALL_PRIORITY_LINUX="official,cargo,snap,flatpak,apt"
#   INSTALL_PRIORITY_MACOS="official,cargo,brew"
#   INSTALL_PRIORITY_WINDOWS="official,cargo,winget,scoop,choco"
#
# ═══════════════════════════════════════════════════════════════════════════════

# Prioridades padrão por OS
PRIORITY_LINUX_DEFAULT="official,cargo,snap,flatpak,apt"
PRIORITY_MACOS_DEFAULT="official,cargo,brew"
PRIORITY_WINDOWS_DEFAULT="official,cargo,winget,scoop,choco"

# ═══════════════════════════════════════════════════════════════════════════════
# Catálogo de Apps - define quais fontes estão disponíveis para cada app
# ═══════════════════════════════════════════════════════════════════════════════
# Formato: APP_SOURCES[app]="fonte1:pkg1,fonte2:pkg2,..."
# Fontes: official, cargo, snap, flatpak, apt, brew, winget, scoop, choco

declare -A APP_SOURCES

init_app_catalog() {
  # ─────────────────────────────────────────────────────────────────────────────
  # CLI Tools
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[lazygit]="official:github/jesseduffield/lazygit,brew:lazygit,winget:jesseduffield.lazygit,scoop:lazygit"
  APP_SOURCES[btop]="snap:btop,apt:btop,brew:btop,flatpak:io.github.AstroTechPy.Btop"
  APP_SOURCES[gh]="official:github-cli,apt:gh,brew:gh,winget:GitHub.cli"
  APP_SOURCES[fzf]="official:github/junegunn/fzf,apt:fzf,brew:fzf,winget:junegunn.fzf"
  APP_SOURCES[eza]="cargo:eza,apt:eza,brew:eza,winget:eza-community.eza"
  APP_SOURCES[zoxide]="cargo:zoxide,apt:zoxide,brew:zoxide,winget:ajeetdsouza.zoxide"
  APP_SOURCES[bat]="cargo:bat,apt:bat,brew:bat,winget:sharkdp.bat"
  APP_SOURCES[ripgrep]="cargo:ripgrep,apt:ripgrep,brew:ripgrep,winget:BurntSushi.ripgrep"
  APP_SOURCES[fd]="cargo:fd-find,apt:fd-find,brew:fd,winget:sharkdp.fd"
  APP_SOURCES[delta]="cargo:git-delta,apt:git-delta,brew:git-delta,winget:dandavison.delta"
  APP_SOURCES[starship]="official:starship.rs,cargo:starship,brew:starship,winget:Starship.Starship"
  APP_SOURCES[atuin]="official:atuin.sh,cargo:atuin,brew:atuin"
  APP_SOURCES[tealdeer]="cargo:tealdeer,brew:tealdeer,winget:dbrgn.tealdeer"
  APP_SOURCES[yazi]="cargo:yazi-fm,brew:yazi,winget:sxyazi.yazi"
  APP_SOURCES[procs]="cargo:procs,brew:procs,winget:dalance.procs"
  APP_SOURCES[dust]="cargo:du-dust,brew:dust,winget:bootandy.dust"
  APP_SOURCES[sd]="cargo:sd,brew:sd,winget:chmln.sd"
  APP_SOURCES[tokei]="cargo:tokei,brew:tokei,winget:XAMPPRocky.tokei"
  APP_SOURCES[hyperfine]="cargo:hyperfine,brew:hyperfine,winget:sharkdp.hyperfine"
  APP_SOURCES[mise]="official:mise.run,brew:mise,cargo:mise"
  APP_SOURCES[tmux]="apt:tmux,brew:tmux"
  APP_SOURCES[neovim]="apt:neovim,brew:neovim,winget:Neovim.Neovim,flatpak:io.neovim.nvim"
  APP_SOURCES[jq]="apt:jq,brew:jq,winget:jqlang.jq"
  APP_SOURCES[direnv]="apt:direnv,brew:direnv,winget:direnv.direnv"

  # ─────────────────────────────────────────────────────────────────────────────
  # Apps GUI - Produtividade
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[slack]="snap:slack --classic,flatpak:com.slack.Slack,brew:slack,winget:SlackTechnologies.Slack"
  APP_SOURCES[obsidian]="snap:obsidian --classic,flatpak:md.obsidian.Obsidian,brew:obsidian,winget:Obsidian.Obsidian"
  APP_SOURCES[notion]="snap:notion-snap-reborn,brew:notion,winget:Notion.Notion"
  APP_SOURCES[logseq]="flatpak:com.logseq.Logseq,brew:logseq,winget:Logseq.Logseq"
  APP_SOURCES[anki]="flatpak:net.ankiweb.Anki,brew:anki,winget:Anki.Anki"
  APP_SOURCES[joplin]="flatpak:net.cozic.joplin_desktop,brew:joplin,winget:Joplin.Joplin"
  APP_SOURCES[appflowy]="flatpak:io.appflowy.AppFlowy,brew:appflowy,winget:AppFlowy.AppFlowy"

  # ─────────────────────────────────────────────────────────────────────────────
  # Apps GUI - Comunicação
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[discord]="snap:discord,flatpak:com.discordapp.Discord,brew:discord,winget:Discord.Discord"
  APP_SOURCES[telegram]="flatpak:org.telegram.desktop,brew:telegram,winget:Telegram.TelegramDesktop"
  APP_SOURCES[whatsapp]="flatpak:io.github.mimbrero.WhatsAppDesktop,brew:whatsapp,winget:WhatsApp.WhatsApp"
  APP_SOURCES[signal]="flatpak:org.signal.Signal,brew:signal,winget:OpenWhisperSystems.Signal"
  APP_SOURCES[teams]="flatpak:com.github.IsmaelMartinez.teams_for_linux,brew:microsoft-teams,winget:Microsoft.Teams"
  APP_SOURCES[zoom]="flatpak:us.zoom.Zoom,brew:zoom,winget:Zoom.Zoom"
  APP_SOURCES[thunderbird]="flatpak:org.mozilla.Thunderbird,brew:thunderbird,winget:Mozilla.Thunderbird"

  # ─────────────────────────────────────────────────────────────────────────────
  # Apps GUI - Mídia
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[spotify]="snap:spotify,flatpak:com.spotify.Client,brew:spotify,winget:Spotify.Spotify"
  APP_SOURCES[vlc]="apt:vlc,flatpak:org.videolan.VLC,brew:vlc,winget:VideoLAN.VLC"
  APP_SOURCES[obs-studio]="flatpak:com.obsproject.Studio,brew:obs,winget:OBSProject.OBSStudio"
  APP_SOURCES[gimp]="flatpak:org.gimp.GIMP,brew:gimp,winget:GIMP.GIMP"
  APP_SOURCES[inkscape]="flatpak:org.inkscape.Inkscape,brew:inkscape,winget:Inkscape.Inkscape"
  APP_SOURCES[blender]="flatpak:org.blender.Blender,brew:blender,winget:BlenderFoundation.Blender"
  APP_SOURCES[audacity]="flatpak:org.audacityteam.Audacity,brew:audacity,winget:Audacity.Audacity"
  APP_SOURCES[kdenlive]="flatpak:org.kde.kdenlive,brew:kdenlive,winget:KDE.Kdenlive"

  # ─────────────────────────────────────────────────────────────────────────────
  # Apps GUI - Desenvolvimento
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[vscode]="official:code.visualstudio.com,apt:code,snap:code --classic,brew:visual-studio-code,winget:Microsoft.VisualStudioCode"
  APP_SOURCES[docker]="official:docker.com,apt:docker-ce,brew:docker,winget:Docker.DockerDesktop"
  APP_SOURCES[postman]="snap:postman,flatpak:com.getpostman.Postman,brew:postman,winget:Postman.Postman"
  APP_SOURCES[dbeaver]="snap:dbeaver-ce --classic,flatpak:io.dbeaver.DBeaverCommunity,brew:dbeaver-community,winget:dbeaver.dbeaver"
  APP_SOURCES[bruno]="flatpak:com.usebruno.Bruno,brew:bruno,winget:Bruno.Bruno"
  APP_SOURCES[insomnia]="flatpak:rest.insomnia.Insomnia,brew:insomnia,winget:Insomnia.Insomnia"
  APP_SOURCES[gitkraken]="flatpak:com.axosoft.GitKraken,brew:gitkraken,winget:Axosoft.GitKraken"
  APP_SOURCES[mongodb-compass]="flatpak:com.mongodb.Compass,brew:mongodb-compass,winget:MongoDB.Compass.Full"
  APP_SOURCES[zed]="flatpak:dev.zed.Zed,brew:zed,winget:Zed.Zed"
  APP_SOURCES[sublime-text]="flatpak:com.sublimetext.three,brew:sublime-text,winget:SublimeHQ.SublimeText.4"
  APP_SOURCES[wezterm]="official:wezfurlong.org,flatpak:org.wezfurlong.wezterm,brew:wezterm,winget:wez.wezterm"

  # ─────────────────────────────────────────────────────────────────────────────
  # Apps GUI - Navegadores
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[firefox]="apt:firefox,flatpak:org.mozilla.firefox,brew:firefox,winget:Mozilla.Firefox"
  APP_SOURCES[chrome]="official:google.com/chrome,flatpak:com.google.Chrome,brew:google-chrome,winget:Google.Chrome"
  APP_SOURCES[brave]="official:brave.com,flatpak:com.brave.Browser,brew:brave-browser,winget:Brave.Brave"
  APP_SOURCES[zen]="flatpak:io.github.AstroTechPy.Zen,brew:zen-browser"
  APP_SOURCES[arc]="brew:arc,winget:TheBrowserCompany.Arc"
  APP_SOURCES[vivaldi]="apt:vivaldi-stable,brew:vivaldi,winget:VivaldiTechnologies.Vivaldi"
  APP_SOURCES[edge]="flatpak:com.microsoft.Edge,brew:microsoft-edge,winget:Microsoft.Edge"
  APP_SOURCES[opera]="flatpak:com.opera.Opera,brew:opera,winget:Opera.Opera"
  APP_SOURCES[librewolf]="flatpak:io.gitlab.librewolf-community,brew:librewolf,winget:LibreWolf.LibreWolf"

  # ─────────────────────────────────────────────────────────────────────────────
  # Apps GUI - Utilitários
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[flameshot]="flatpak:org.flameshot.Flameshot,apt:flameshot,brew:flameshot"
  APP_SOURCES[bitwarden]="flatpak:com.bitwarden.desktop,brew:bitwarden,winget:Bitwarden.Bitwarden"
  APP_SOURCES[1password]="flatpak:com.1password.1Password,brew:1password,winget:AgileBits.1Password"
  APP_SOURCES[keepassxc]="flatpak:org.keepassxc.KeePassXC,brew:keepassxc,winget:KeePassXCTeam.KeePassXC"
  APP_SOURCES[syncthing]="apt:syncthing,brew:syncthing,winget:Syncthing.Syncthing"

  # ─────────────────────────────────────────────────────────────────────────────
  # Bancos de Dados
  # ─────────────────────────────────────────────────────────────────────────────
  APP_SOURCES[postgresql]="apt:postgresql,brew:postgresql@16,winget:PostgreSQL.PostgreSQL"
  APP_SOURCES[redis]="apt:redis,brew:redis,winget:Redis.Redis"
  APP_SOURCES[mysql]="apt:mysql-server,brew:mysql,winget:Oracle.MySQL"
  APP_SOURCES[mariadb]="apt:mariadb-server,brew:mariadb,winget:MariaDB.Server"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Obter prioridade de instalação para o OS atual
# ═══════════════════════════════════════════════════════════════════════════════

get_install_priority() {
  case "$TARGET_OS" in
    linux|wsl2)
      echo "${INSTALL_PRIORITY_LINUX:-$PRIORITY_LINUX_DEFAULT}"
      ;;
    macos)
      echo "${INSTALL_PRIORITY_MACOS:-$PRIORITY_MACOS_DEFAULT}"
      ;;
    windows)
      echo "${INSTALL_PRIORITY_WINDOWS:-$PRIORITY_WINDOWS_DEFAULT}"
      ;;
    *)
      echo "$PRIORITY_LINUX_DEFAULT"
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# Funções de instalação por fonte
# ═══════════════════════════════════════════════════════════════════════════════

_install_via_official() {
  local app="$1"
  local source_info="$2"
  local level="${3:-optional}"

  case "$source_info" in
    github/jesseduffield/lazygit)
      _install_lazygit_official "$level"
      ;;
    github/junegunn/fzf)
      install_fzf_latest
      ;;
    github-cli)
      _install_gh_official "$level"
      ;;
    starship.rs)
      _install_starship_official "$level"
      ;;
    atuin.sh)
      _install_atuin_official "$level"
      ;;
    mise.run)
      _install_mise_official "$level"
      ;;
    code.visualstudio.com)
      _install_vscode_official "$level"
      ;;
    docker.com)
      _install_docker_official "$level"
      ;;
    google.com/chrome)
      _install_chrome_official "$level"
      ;;
    brave.com)
      _install_brave_official "$level"
      ;;
    wezfurlong.org)
      install_wezterm_linux
      ;;
    *)
      return 1
      ;;
  esac
}

_install_lazygit_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando lazygit via GitHub Releases..."

  local version=""
  version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" 2>/dev/null | grep -Po '"tag_name": *"v\K[^"]*' || echo "")"

  if [[ -z "$version" ]]; then
    record_failure "$level" "Falha ao obter versão do lazygit do GitHub"
    return 1
  fi

  local arch="x86_64"
  [[ "$(uname -m)" == "aarch64" ]] && arch="arm64"

  local url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch}.tar.gz"
  local tmp_dir=""
  tmp_dir="$(mktemp -d)"

  if curl -fsSL "$url" -o "$tmp_dir/lazygit.tar.gz" && \
     tar xf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir" lazygit && \
     run_with_sudo install "$tmp_dir/lazygit" -D -t /usr/local/bin/; then
    INSTALLED_MISC+=("lazygit: v${version} (official)")
    rm -rf "$tmp_dir" 2>/dev/null || true
    return 0
  fi

  rm -rf "$tmp_dir" 2>/dev/null || true
  record_failure "$level" "Falha ao instalar lazygit via GitHub"
  return 1
}

_install_gh_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando GitHub CLI via repositório oficial..."

  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | run_with_sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null; then
        run_with_sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | run_with_sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        LINUX_PKG_UPDATED=0
        if install_linux_packages "$level" gh; then
          INSTALLED_MISC+=("gh: official repo")
          return 0
        fi
      fi
      ;;
    dnf)
      if run_with_sudo dnf install -y 'dnf-command(config-manager)' && \
         run_with_sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo && \
         run_with_sudo dnf install -y gh; then
        INSTALLED_MISC+=("gh: official repo")
        return 0
      fi
      ;;
  esac

  record_failure "$level" "Falha ao instalar gh via repositório oficial"
  return 1
}

_install_starship_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando Starship via script oficial..."

  if curl -fsSL https://starship.rs/install.sh | sh -s -- -y; then
    INSTALLED_MISC+=("starship: official")
    return 0
  fi

  record_failure "$level" "Falha ao instalar Starship via script oficial"
  return 1
}

_install_atuin_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando Atuin via script oficial..."

  if curl -fsSL https://setup.atuin.sh | bash; then
    INSTALLED_MISC+=("atuin: official")
    return 0
  fi

  record_failure "$level" "Falha ao instalar Atuin via script oficial"
  return 1
}

_install_mise_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando mise via script oficial..."

  if curl -fsSL https://mise.run | sh; then
    export PATH="$HOME/.local/bin:$PATH"
    INSTALLED_MISC+=("mise: official")
    return 0
  fi

  record_failure "$level" "Falha ao instalar mise via script oficial"
  return 1
}

_install_vscode_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando VS Code via repositório oficial..."

  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | run_with_sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null; then
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | run_with_sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        LINUX_PKG_UPDATED=0
        if install_linux_packages "$level" code; then
          INSTALLED_MISC+=("vscode: official repo")
          return 0
        fi
      fi
      ;;
  esac

  record_failure "$level" "Falha ao instalar VS Code via repositório oficial"
  return 1
}

_install_docker_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando Docker via script oficial..."

  if curl -fsSL https://get.docker.com | sh; then
    run_with_sudo usermod -aG docker "$USER" 2>/dev/null || true
    INSTALLED_MISC+=("docker: official")
    return 0
  fi

  record_failure "$level" "Falha ao instalar Docker via script oficial"
  return 1
}

_install_chrome_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando Google Chrome via .deb oficial..."

  local tmp_deb=""
  tmp_deb="$(mktemp)"

  if curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$tmp_deb" && \
     run_with_sudo dpkg -i "$tmp_deb"; then
    rm -f "$tmp_deb"
    INSTALLED_MISC+=("chrome: official")
    return 0
  fi

  run_with_sudo apt-get install -f -y 2>/dev/null || true
  rm -f "$tmp_deb"
  record_failure "$level" "Falha ao instalar Chrome via .deb oficial"
  return 1
}

_install_brave_official() {
  local level="${1:-optional}"
  msg "  📦 Instalando Brave via repositório oficial..."

  case "$LINUX_PKG_MANAGER" in
    apt-get)
      if curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | run_with_sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | run_with_sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
        LINUX_PKG_UPDATED=0
        if install_linux_packages "$level" brave-browser; then
          INSTALLED_MISC+=("brave: official repo")
          return 0
        fi
      fi
      ;;
  esac

  record_failure "$level" "Falha ao instalar Brave via repositório oficial"
  return 1
}

_install_via_cargo() {
  local app="$1"
  local crate="$2"
  local level="${3:-optional}"

  has_cmd cargo || return 1

  msg "  📦 Instalando $app via cargo ($crate)..."
  if cargo_smart_install "$crate" "$app"; then
    return 0
  fi

  return 1
}

_install_via_snap() {
  local app="$1"
  local pkg_with_args="$2"
  local level="${3:-optional}"

  has_cmd snap || return 1

  local pkg="${pkg_with_args%% *}"
  local args=""
  [[ "$pkg_with_args" == *" "* ]] && args="${pkg_with_args#* }"

  msg "  📦 Instalando $app via snap ($pkg)..."

  if has_snap_pkg "$pkg"; then
    if run_with_sudo snap refresh "$pkg"; then
      INSTALLED_MISC+=("$app: snap refresh")
      return 0
    fi
  else
    # shellcheck disable=SC2086
    if run_with_sudo snap install $args "$pkg"; then
      INSTALLED_MISC+=("$app: snap install")
      return 0
    fi
  fi

  return 1
}

_install_via_flatpak() {
  local app="$1"
  local ref="$2"
  local level="${3:-optional}"

  has_cmd flatpak || return 1

  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

  msg "  📦 Instalando $app via flatpak ($ref)..."

  if flatpak info "$ref" >/dev/null 2>&1; then
    if flatpak update -y "$ref"; then
      INSTALLED_MISC+=("$app: flatpak update")
      return 0
    fi
  else
    if flatpak install -y flathub "$ref"; then
      INSTALLED_MISC+=("$app: flatpak install")
      return 0
    fi
  fi

  return 1
}

_install_via_apt() {
  local app="$1"
  local pkg="$2"
  local level="${3:-optional}"

  [[ "$LINUX_PKG_MANAGER" == "apt-get" ]] || return 1

  msg "  📦 Instalando $app via apt ($pkg)..."
  if install_linux_packages "$level" "$pkg"; then
    return 0
  fi

  return 1
}

_install_via_brew() {
  local app="$1"
  local formula="$2"
  local level="${3:-optional}"

  has_cmd brew || return 1

  msg "  📦 Instalando $app via brew ($formula)..."

  if brew list --cask "$formula" &>/dev/null || brew list "$formula" &>/dev/null; then
    if brew upgrade "$formula" 2>/dev/null || brew upgrade --cask "$formula" 2>/dev/null; then
      INSTALLED_MISC+=("$app: brew upgrade")
      return 0
    fi
    return 0
  fi

  if brew install --cask "$formula" 2>/dev/null || brew install "$formula" 2>/dev/null; then
    INSTALLED_MISC+=("$app: brew install")
    return 0
  fi

  return 1
}

_install_via_winget() {
  local app="$1"
  local pkg="$2"
  local level="${3:-optional}"

  has_cmd winget || return 1

  msg "  📦 Instalando $app via winget ($pkg)..."

  if winget install --id "$pkg" --accept-source-agreements --accept-package-agreements -e; then
    INSTALLED_MISC+=("$app: winget install")
    return 0
  fi

  return 1
}

_install_via_scoop() {
  local app="$1"
  local pkg="$2"
  local level="${3:-optional}"

  has_cmd scoop || return 1

  msg "  📦 Instalando $app via scoop ($pkg)..."

  if scoop install "$pkg"; then
    INSTALLED_MISC+=("$app: scoop install")
    return 0
  fi

  return 1
}

_install_via_choco() {
  local app="$1"
  local pkg="$2"
  local level="${3:-optional}"

  has_cmd choco || return 1

  msg "  📦 Instalando $app via choco ($pkg)..."

  if choco install "$pkg" -y; then
    INSTALLED_MISC+=("$app: choco install")
    return 0
  fi

  return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Função principal: instalar app usando prioridade configurada
# ═══════════════════════════════════════════════════════════════════════════════

install_with_priority() {
  local app="$1"
  local cmd_check="${2:-$app}"
  local level="${3:-optional}"

  if has_cmd "$cmd_check"; then
    msg "  ✅ $app já instalado"
    return 0
  fi

  local sources="${APP_SOURCES[$app]:-}"
  if [[ -z "$sources" ]]; then
    warn "App '$app' não encontrado no catálogo"
    return 1
  fi

  local priority
  priority="$(get_install_priority)"

  IFS=',' read -ra priority_list <<< "$priority"

  for method in "${priority_list[@]}"; do
    local pkg=""
    IFS=',' read -ra source_list <<< "$sources"
    for source_entry in "${source_list[@]}"; do
      local source_method="${source_entry%%:*}"
      local source_pkg="${source_entry#*:}"
      if [[ "$source_method" == "$method" ]]; then
        pkg="$source_pkg"
        break
      fi
    done

    [[ -z "$pkg" ]] && continue

    case "$method" in
      official)
        if _install_via_official "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      cargo)
        if _install_via_cargo "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      snap)
        if _install_via_snap "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      flatpak)
        if _install_via_flatpak "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      apt)
        if _install_via_apt "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      brew)
        if _install_via_brew "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      winget)
        if _install_via_winget "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      scoop)
        if _install_via_scoop "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
      choco)
        if _install_via_choco "$app" "$pkg" "$level"; then
          return 0
        fi
        ;;
    esac
  done

  record_failure "$level" "Nenhum método de instalação funcionou para $app"
  return 1
}

# Inicializar catálogo ao carregar o módulo
init_app_catalog
