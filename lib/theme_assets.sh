#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# theme_assets.sh — instala os arquivos que faltam para os DOIS asset gaps
# reais do catalogo (data/themes.sh:THEME_ASSET_STATUS):
#
#   tokyo-night:bat    e   tokyo-night:delta   (mesmo arquivo — delta usa o
#     registro de temas do bat via syntect; um .tmTheme resolve os dois)
#   catppuccin-mocha:btop
#
# A terceira lacuna do catalogo (gruvbox-dark:nvim) e plugin, nao asset
# baixavel — resolvido em shared/nvim/lua/plugins/theme.lua, esta
# tarefa nao toca nisso.
#
# Contrato com quem chama:
#   - has_cmd/msg/warn/is_truthy vem de quem sourceia este arquivo.
#   - install_theme_assets_for "$TEMA": chamar como statement solto (escreve
#     em disco e usa rede), antes de qualquer _warn_if_asset_missing.
#   - theme_asset_present "$ferramenta": checagem pura, so leitura.
#
# Estas funcoes escrevem em ~/.config independente de APPLY_LIVE. APPLY_LIVE
# controla espelhar CONFIG para copia viva que ja existe; instalar asset cria
# diretorio novo por definicao e e pre-requisito para a ferramenta reconhecer
# o nome que qualquer um dos dois caminhos vai gravar.

BAT_THEMES_DIR="${BAT_THEMES_DIR:-$HOME/.config/bat/themes}"
BTOP_THEMES_DIR="${BTOP_THEMES_DIR:-$HOME/.config/btop/themes}"

# Nome do arquivo IMPORTA: medido nesta maquina (bat 0.26.1) que o bat
# registra o tema pelo BASENAME do arquivo (sem extensao), nao pela tag
# <key>name</key> interna do .tmTheme — ao contrario do que o brief desta
# tarefa assumia ("nao ha divergencia de nome para resolver"). Instalado
# como "tokyonight_night.tmTheme", `bat --list-themes` listou
# "tokyonight_night" e `--theme=TokyoNight` continuou caindo no padrao.
# THEME_BAT[tokyo-night] e THEME_DELTA[tokyo-night] (data/themes.sh) exigem
# exatamente "TokyoNight" — por isso o arquivo e salvo com ESTE nome,
# independente do nome de origem (local ou download).
BAT_TOKYONIGHT_TMTHEME="$BAT_THEMES_DIR/TokyoNight.tmTheme"
BTOP_CATPPUCCIN_THEME="$BTOP_THEMES_DIR/catppuccin_mocha.theme"

# Copia oficial e offline: plugin tokyonight.nvim, ja instalado nesta
# maquina para o Neovim, empacota o mesmo .tmTheme que os extras do proprio
# projeto distribuem para bat/delta. Preferida ao download porque e a MESMA
# origem, funciona sem rede, e mantem editor e pager na mesma versao.
_local_tokyonight_tmtheme_source() {
  local candidate="$HOME/.local/share/nvim/lazy/tokyonight.nvim/extras/sublime/tokyonight_night.tmTheme"
  [[ -f "$candidate" ]] || return 1
  echo "$candidate"
}

TOKYONIGHT_TMTHEME_FALLBACK_URL="https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme"
BTOP_CATPPUCCIN_THEME_URL="https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_mocha.theme"

# ────────────────────────────────────────────────────────────────────────────
# Validacao — nunca gravar um asset sem antes confirmar que o conteudo e o
# que devia ser (bug ja custou caro neste repositorio, ver brief da tarefa).
# ────────────────────────────────────────────────────────────────────────────

_validate_tmtheme_xml() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  if has_cmd python3; then
    python3 -c 'import sys,xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "$file" 2>/dev/null
    return $?
  fi
  if has_cmd xmllint; then
    xmllint --noout "$file" 2>/dev/null
    return $?
  fi
  grep -q '<key>name</key>' "$file"
}

_validate_btop_theme_file() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  grep -qE '^theme\[main_bg\]=' "$file"
}

# ────────────────────────────────────────────────────────────────────────────
# Checagem pura — so leitura, sem rede, segura em qualquer contexto (inclusive
# dentro de $( ), embora nao precise: nao muta globais do chamador).
# ────────────────────────────────────────────────────────────────────────────

_bat_tokyonight_asset_present() {
  [[ -f "$BAT_TOKYONIGHT_TMTHEME" ]] || return 1
  has_cmd bat || return 0
  bat --list-themes 2>/dev/null | grep -qxF "${THEME_BAT[tokyo-night]}"
}

_btop_catppuccin_asset_present() {
  [[ -f "$BTOP_CATPPUCCIN_THEME" ]]
}

# ferramenta -> checagem correspondente. So as duas com lacuna real no
# catalogo tem checagem; qualquer outra ferramenta e considerada "presente"
# (native, nunca precisou de asset — quem decide isso e THEME_ASSET_STATUS,
# esta funcao so e chamada quando o status ja e "asset").
theme_asset_present() {
  local ferramenta="$1"
  case "$ferramenta" in
    bat|delta) _bat_tokyonight_asset_present ;;
    btop) _btop_catppuccin_asset_present ;;
    *) return 0 ;;
  esac
}

# ────────────────────────────────────────────────────────────────────────────
# Instalacao — as unicas duas funcoes que tocam rede/disco. Idempotentes
# (saem cedo se o asset ja existe e valida) e respeitam DRY_RUN (nunca
# escrevem no destino final; a copia local so e lida, o download so cai em
# arquivo temporario, os dois sao seguros de checar mesmo em dry-run porque
# nao persistem nada — só a ESCRITA final e pulada). Falha aqui nunca seta
# FAILED=1 do chamador: um asset que nao instalou (sem rede, por exemplo)
# deve continuar deixando o resto da troca de tema seguir.
# ────────────────────────────────────────────────────────────────────────────

ensure_bat_tokyonight_asset() {
  _bat_tokyonight_asset_present && return 0

  local origem="" tmp_download=""
  local local_src
  if local_src="$(_local_tokyonight_tmtheme_source)" && _validate_tmtheme_xml "$local_src"; then
    origem="$local_src"
  fi

  if [[ -z "$origem" ]]; then
    if is_truthy "${DRY_RUN:-0}"; then
      msg "  🔎 (dry-run) copia local do tema Tokyo Night nao encontrada/valida — baixaria $TOKYONIGHT_TMTHEME_FALLBACK_URL para instalar o asset do bat/delta"
      return 1
    fi
    if ! has_cmd curl; then
      warn "curl indisponivel — nao foi possivel instalar o tema Tokyo Night do bat/delta"
      return 1
    fi
    tmp_download="$(mktemp)" || { warn "falha ao criar arquivo temporario para o asset do bat/delta"; return 1; }
    local -a curl_args=(-fsSL --proto '=https' --tlsv1.2 --retry 2 --retry-delay 1 --connect-timeout "${CURL_CONNECT_TIMEOUT:-10}" --max-time "${CURL_TIMEOUT_NORMAL:-120}")
    if ! curl "${curl_args[@]}" "$TOKYONIGHT_TMTHEME_FALLBACK_URL" -o "$tmp_download"; then
      warn "falha ao baixar o tema Tokyo Night para bat/delta ($TOKYONIGHT_TMTHEME_FALLBACK_URL) — tema gravado, mas sem asset nesta maquina"
      rm -f "$tmp_download" 2>/dev/null
      return 1
    fi
    if ! _validate_tmtheme_xml "$tmp_download"; then
      warn "download do tema Tokyo Night (bat/delta) reprovado na validacao XML — nao instalado"
      rm -f "$tmp_download" 2>/dev/null
      return 1
    fi
    origem="$tmp_download"
  fi

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) instalaria $BAT_TOKYONIGHT_TMTHEME (origem: $origem)"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi

  if ! mkdir -p "$BAT_THEMES_DIR"; then
    warn "falha ao criar $BAT_THEMES_DIR"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi
  if ! cp "$origem" "$BAT_TOKYONIGHT_TMTHEME"; then
    warn "falha ao copiar o tema Tokyo Night para $BAT_TOKYONIGHT_TMTHEME"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi
  rm -f "$tmp_download" 2>/dev/null
  msg "  📦 asset instalado: $BAT_TOKYONIGHT_TMTHEME"

  if has_cmd bat; then
    if bat cache --build >/dev/null 2>&1; then
      msg "  ✅ bat cache --build ok — TokyoNight ja aparece em 'bat --list-themes'"
    else
      warn "asset instalado, mas 'bat cache --build' falhou — TokyoNight pode nao aparecer ainda em 'bat --list-themes'"
    fi
  fi
  return 0
}

# btop empacotado como snap com confinamento estrito nao consegue ler NADA sob
# ~/.config — nem o proprio btop.conf. O perfil AppArmor do snapd exclui os
# diretorios ocultos do topo de $HOME (regra "owner @{HOME}/[^s.]** rwklix,"
# em /var/lib/snapd/apparmor/profiles/snap.btop.btop).
#
# Nesse cenario instalar o asset e PIOR do que nao instalar: o btop tolera nao
# conseguir criar o diretorio de temas, mas ABORTA com SIGABRT
# (std::filesystem_error: "directory iterator cannot open directory") se o
# diretorio existir e ele nao puder iterar. Verificado nesta maquina em
# Set/2026 com btop 1.4.7 do snap: criar ~/.config/btop/themes/ derrubou o
# btop na abertura, e remover o diretorio o restaurou.
#
# Snap em modo classic ou devmode nao aplica o perfil restritivo, entao esses
# seguem normalmente. btop de apt/dnf/brew tambem nao passa por aqui.
_btop_config_is_readable() {
  has_cmd btop || return 1
  case "$(command -v btop)" in
    /snap/bin/*) ;;
    *) return 0 ;;
  esac
  snap list btop 2>/dev/null | awk 'NR==2 {print $6}' | grep -qE 'classic|devmode' && return 0
  return 1
}

ensure_btop_catppuccin_asset() {
  _btop_catppuccin_asset_present && return 0

  if ! _btop_config_is_readable; then
    warn "btop instalado como snap com confinamento estrito: ele nao le nada sob ~/.config, nem o proprio btop.conf. Instalar o tema ali faria o btop abortar ao abrir — asset NAO instalado de proposito."
    if [[ -d "$BTOP_THEMES_DIR" ]]; then
      err "$BTOP_THEMES_DIR existe e o btop deste sistema ABORTA ao encontra-lo. Remova com: rm -rf \"$BTOP_THEMES_DIR\""
    fi
    return 1
  fi

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) baixaria $BTOP_CATPPUCCIN_THEME_URL para instalar o tema Catppuccin Mocha do btop"
    return 1
  fi

  if ! has_cmd curl; then
    warn "curl indisponivel — nao foi possivel instalar o tema Catppuccin Mocha do btop"
    return 1
  fi

  local tmp_download
  tmp_download="$(mktemp)" || { warn "falha ao criar arquivo temporario para o asset do btop"; return 1; }
  local -a curl_args=(-fsSL --proto '=https' --tlsv1.2 --retry 2 --retry-delay 1 --connect-timeout "${CURL_CONNECT_TIMEOUT:-10}" --max-time "${CURL_TIMEOUT_NORMAL:-120}")
  if ! curl "${curl_args[@]}" "$BTOP_CATPPUCCIN_THEME_URL" -o "$tmp_download"; then
    warn "falha ao baixar o tema Catppuccin Mocha para o btop ($BTOP_CATPPUCCIN_THEME_URL) — tema gravado, mas sem asset nesta maquina"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi
  if ! _validate_btop_theme_file "$tmp_download"; then
    warn "download do tema Catppuccin Mocha (btop) reprovado na validacao — nao instalado"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi

  if ! mkdir -p "$BTOP_THEMES_DIR"; then
    warn "falha ao criar $BTOP_THEMES_DIR"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi
  if ! cp "$tmp_download" "$BTOP_CATPPUCCIN_THEME"; then
    warn "falha ao copiar o tema Catppuccin Mocha para $BTOP_CATPPUCCIN_THEME"
    rm -f "$tmp_download" 2>/dev/null
    return 1
  fi
  rm -f "$tmp_download" 2>/dev/null
  msg "  📦 asset instalado: $BTOP_CATPPUCCIN_THEME"
  return 0
}

# Dispatcher — chamado uma vez por execucao do set_theme.sh, so com o tema
# que foi de fato pedido. Cada ensure_* age so quando ha lacuna para aquele
# tema; os outros dois temas passam por aqui sem nenhum efeito.
install_theme_assets_for() {
  local tema="$1"
  case "$tema" in
    tokyo-night) ensure_bat_tokyonight_asset ;;
  esac
  case "$tema" in
    catppuccin-mocha) ensure_btop_catppuccin_asset ;;
  esac
  return 0
}
