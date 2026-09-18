#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# set_theme.sh — aplica um tema as regioes marcadas com `tema:*` nos
# arquivos de configuracao das ferramentas de terminal.
# ══════════════════════════════════════════════════════════════════════════════
#
# Escopo (o que este script toca, e por que exatamente isso):
#
#   linux/ghostty/config              tema:nome
#   macos/ghostty/config              tema:nome
#   shared/bat/config                 tema:nome
#   shared/starship.toml              tema:nome (palette) + tema:cores (bloco de cores)
#   shared/lazygit/config.yml         tema:cores + tema:pager (mesmo arquivo, 2 rotulos)
#   shared/fish/config.fish           tema:nome (BAT_THEME) + tema:cores (FZF_DEFAULT_OPTS)
#   shared/tmux/.tmux.conf             tema:cores
#   shared/btop/btop.conf              SEM marcador — ver _apply_btop_file
#   shared/nvim/lua/config/lazy.lua    tema:nome — o `colorscheme` do spec.
#     NAO o `install.colorscheme`, que e so fallback do lazy.nvim.
#
# Fora de escopo, de proposito:
#   - shared/zsh/.zshrc       nunca teve FZF_DEFAULT_OPTS.
#   - shared/yazi/theme.toml  usa 26 cores; o catalogo tem 10 por tema. Cobrir
#     exigiria paleta estendida de fonte oficial para os outros dois temas, e
#     nenhuma cor aqui e inventada. Fica em Catppuccin Mocha, e o resumo avisa.
#
# Onde escreve:
#   Por padrao so no repositorio, que e a fonte versionada — ~/.config guarda
#   copias que o install.sh sincroniza por outro caminho. Com APPLY_LIVE=1
#   espelha tambem para o caminho vivo, e so se ele ja existir.
#
# Regra de ouro sobre backup (Requisito 4 — bug ja aconteceu neste repositorio):
#   _ensure_backup_dir() so pode ser chamada como statement direto. Chamá-la
#   dentro de $( ) roda num subshell e a mutacao de global se perde. Por isso
#   as funcoes que so CALCULAM conteudo sao puras e podem ser capturadas;
#   _ensure_backup_dir, _warn_if_asset_missing e _write_file_if_changed mutam
#   global e sao SEMPRE chamadas como statement solto.
#
# Tema com asset faltante: o script escreve o nome mesmo assim e avisa no
#   resumo. Pular a escrita quebraria a reversibilidade — o btop e nativo em
#   tokyo-night e falta em catppuccin-mocha, entao voltar de um para o outro
#   deixaria o valor antigo gravado.
#
# Cor sem entrada no catalogo de 10 (aqua/teal, rosewater, cyan/black/pink/
#   lavender do tmux): nunca e escrita, a linha existente fica byte a byte.
#   Na pratica esses acentos seguem em Catppuccin Mocha em qualquer tema.

set -uo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -lt 3 ]]; }; then
  echo "bash 4.3+ necessario. Versao atual: ${BASH_VERSION}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_FILE="$SCRIPT_DIR/data/themes.sh"
if [[ ! -f "$THEMES_FILE" ]]; then
  echo "catalogo nao encontrado: $THEMES_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1091
# shellcheck source=../data/themes.sh
source "$THEMES_FILE"

THEME_ASSETS_FILE="$SCRIPT_DIR/lib/theme_assets.sh"
if [[ ! -f "$THEME_ASSETS_FILE" ]]; then
  echo "instalador de assets nao encontrado: $THEME_ASSETS_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1091
# shellcheck source=../lib/theme_assets.sh
source "$THEME_ASSETS_FILE"

DRY_RUN="${DRY_RUN:-0}"
APPLY_LIVE="${APPLY_LIVE:-0}"

# BACKUP_DIR e criado sob demanda: nenhuma execucao deve deixar um diretorio
# vazio em $HOME quando nada precisa ser copiado (ex.: DRY_RUN=1, ou tema ja
# aplicado em tudo). Mesmo padrao do install.sh:_ensure_backup_dir.
BACKUP_DIR=""
_ensure_backup_dir() {
  [[ -n "$BACKUP_DIR" ]] && return 0
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$(mktemp -d "$HOME/.bkp-theme-${stamp}-XXXXXX" 2>/dev/null || echo "$HOME/.bkp-theme-${stamp}-$$")"
  mkdir -p "$BACKUP_DIR"
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

msg()  { printf '%b\n' "$1"; }
warn() { msg "  ⚠️  $1"; }
# msg/warn/err vem de lib/core.sh quando ele existir; as definicoes locais sao
# o fallback para rodar este script de forma independente.
if ! declare -F err >/dev/null 2>&1; then
  err() { printf '%b\n' "  ❌ $1" >&2; }
fi

FAILED=0
declare -a CHANGED_FILES=()
declare -a ASSET_WARNINGS=()
declare -A _ASSET_WARNED=()

# Registra aviso de asset faltante uma unica vez por tema:ferramenta, mesmo
# que a ferramenta apareca em mais de um arquivo (ghostty: linux+macos; bat:
# shared/bat/config + BAT_THEME do fish). Muta ASSET_WARNINGS — SEMPRE
# chamada como statement solto (ver "Regra de ouro" no cabecalho).
#
# Ordem: a essa altura install_theme_assets_for ja tentou
# instalar o asset do $TEMA atual — theme_asset_present (lib/theme_assets.sh)
# confere o disco de novo, sem rede, e so quem ainda falta depois da
# tentativa vira aviso. Antes isto avisava sempre que o status
# do catalogo era "asset", sem checar se o arquivo ja tinha sido instalado.
_warn_if_asset_missing() {
  local ferramenta="$1"
  local key="${TEMA}:${ferramenta}"
  [[ -n "${_ASSET_WARNED[$key]:-}" ]] && return 0
  _ASSET_WARNED["$key"]=1
  local status="${THEME_ASSET_STATUS[$key]:-native}"
  [[ "$status" != "asset" ]] && return 0
  theme_asset_present "$ferramenta" && return 0
  ASSET_WARNINGS+=("$ferramenta: tema \"$TEMA\" gravado, mas o asset correspondente NAO esta instalado nesta maquina (a instalacao automatica nao concluiu — o aviso logo acima diz por que) — a ferramenta vai cair no tema padrao (ou no anterior) em silencio.")
}

# ────────────────────────────────────────────────────────────────────────────
# Primitivas de marcador — puras (só stdout, seguras dentro de $( ))
# ────────────────────────────────────────────────────────────────────────────

# Devolve as linhas estritamente entre "tema:$label inicio" e "tema:$label
# fim" (exclusive), a partir de um CONTEUDO (nao de um arquivo). Erra se o
# rotulo nao existir, existir mais de uma vez, ou estiver invertido.
_region_interior_content() {
  local content="$1" label="$2"
  local start_needle="tema:${label} inicio"
  local end_needle="tema:${label} fim"
  local -a linhas=()
  mapfile -t linhas <<<"$content"
  local start_idx=-1 end_idx=-1 i
  for i in "${!linhas[@]}"; do
    case "${linhas[$i]}" in
      *"$start_needle"*)
        [[ $start_idx -ge 0 ]] && { err "marcador '$label' duplicado (inicio)"; return 1; }
        start_idx=$i
        ;;
      *"$end_needle"*)
        [[ $end_idx -ge 0 ]] && { err "marcador '$label' duplicado (fim)"; return 1; }
        end_idx=$i
        ;;
    esac
  done
  if [[ $start_idx -lt 0 || $end_idx -lt 0 || $end_idx -le $start_idx ]]; then
    err "marcador '$label' nao encontrado ou malformado"
    return 1
  fi
  local count=$((end_idx - start_idx - 1))
  [[ $count -gt 0 ]] && printf '%s\n' "${linhas[@]:$((start_idx + 1)):$count}"
  return 0
}

_region_interior_file() {
  local file="$1" label="$2"
  [[ -f "$file" ]] || { err "arquivo nao existe: $file"; return 1; }
  _region_interior_content "$(cat "$file")" "$label"
}

# Substitui o interior de um par de marcadores por conteudo novo, preservando
# as duas linhas de marcador e todo o resto do arquivo intactos.
_splice_region_content() {
  local content="$1" label="$2" new_interior="$3"
  local start_needle="tema:${label} inicio"
  local end_needle="tema:${label} fim"
  local -a linhas=()
  mapfile -t linhas <<<"$content"
  local start_idx=-1 end_idx=-1 i
  for i in "${!linhas[@]}"; do
    case "${linhas[$i]}" in
      *"$start_needle"*)
        [[ $start_idx -ge 0 ]] && { err "marcador '$label' duplicado (inicio)"; return 1; }
        start_idx=$i
        ;;
      *"$end_needle"*)
        [[ $end_idx -ge 0 ]] && { err "marcador '$label' duplicado (fim)"; return 1; }
        end_idx=$i
        ;;
    esac
  done
  if [[ $start_idx -lt 0 || $end_idx -lt 0 || $end_idx -le $start_idx ]]; then
    err "marcador '$label' nao encontrado ou malformado"
    return 1
  fi
  local -a new_lines=()
  mapfile -t new_lines <<<"$new_interior"
  local -a out=()
  out=("${linhas[@]:0:$((start_idx + 1))}" "${new_lines[@]}" "${linhas[@]:$end_idx}")
  printf '%s\n' "${out[@]}"
}

_reverse_lookup() {
  local -n arr="$1"
  local value="$2"
  local t
  for t in "${THEMES[@]}"; do
    if [[ "${arr[$t]:-}" == "$value" ]]; then
      echo "$t"
      return 0
    fi
  done
  echo "desconhecido"
  return 1
}

# ────────────────────────────────────────────────────────────────────────────
# Escrita — a unica funcao que toca disco. Muta CHANGED_FILES/BACKUP_DIR —
# SEMPRE chamada como statement solto.
# ────────────────────────────────────────────────────────────────────────────

_write_file_if_changed() {
  local file="$1" new_content="$2" origem="$3"
  local old_content=""
  [[ -f "$file" ]] && old_content="$(cat "$file")"

  if [[ "$old_content" == "$new_content" ]]; then
    msg "  ✅ $file (inalterado)"
    return 0
  fi

  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) $file seria alterado [$origem]"
    if has_cmd diff; then
      diff -u <(printf '%s\n' "$old_content") <(printf '%s\n' "$new_content") 2>/dev/null | head -n 40
    fi
    return 0
  fi

  _ensure_backup_dir
  if [[ -f "$file" ]]; then
    local backup_name backup_path
    backup_name="$(echo "$file" | sed 's#^/##; s#/#_#g')"
    backup_path="$BACKUP_DIR/$backup_name"
    if ! cp -a "$file" "$backup_path" 2>/dev/null; then
      err "falha ao fazer backup de $file — nao vou sobrescrever sem backup"
      FAILED=1
      return 1
    fi
  fi

  printf '%s\n' "$new_content" >"$file"
  msg "  📝 $file (alterado) [$origem]"
  CHANGED_FILES+=("$file")
}

_mirror_live() {
  local src="$1" dest="$2"
  if [[ ! -f "$dest" ]]; then
    warn "live: $dest nao existe — pulando espelhamento (nao crio arvore nova em ~/.config)"
    return 0
  fi
  _write_file_if_changed "$dest" "$(cat "$src")" "espelho ~/.config"
}

# ────────────────────────────────────────────────────────────────────────────
# Aplicacao por arquivo
# ────────────────────────────────────────────────────────────────────────────

_apply_ghostty_file() {
  local file="$1"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content new_interior
  content="$(cat "$file")"
  new_interior="theme = ${THEME_GHOSTTY[$TEMA]}"
  content="$(_splice_region_content "$content" "nome" "$new_interior")" || { FAILED=1; return 1; }
  _warn_if_asset_missing "ghostty"
  _write_file_if_changed "$file" "$content" "ghostty tema:nome"
}

_apply_bat_file() {
  local file="$SCRIPT_DIR/shared/bat/config"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content new_interior
  content="$(cat "$file")"
  new_interior="--theme-dark=\"${THEME_BAT[$TEMA]}\""
  content="$(_splice_region_content "$content" "nome" "$new_interior")" || { FAILED=1; return 1; }
  _warn_if_asset_missing "bat"
  _write_file_if_changed "$file" "$content" "bat tema:nome"
}

# shared/starship.toml tem DOIS marcadores desde a sync com o sistema
# (37a1da1): "tema:nome" so com a linha `palette = '...'`, e "tema:cores"
# com o bloco [palettes.X] inteiro — antes era um marcador so, com os dois
# juntos e vocabulario de cor generico (color_fg0/color_aqua/...). O
# vocabulario generico saiu de uso: o arquivo novo usa nomes nativos do
# Catppuccin (rosewater/peach/lavender/...) porque e o que os MODULOS do
# starship (format/os/directory/...) referenciam diretamente via bg:/fg:.
#
# So 13 das 26 cores do Catppuccin sao escritas aqui (as 10 do catalogo +
# crust/lavender/sapphire, Problema 3) — nao as 26. Escrever as outras 19
# exigiria inventar mapeamento pra cada uma nos temas que nao sao
# Catppuccin, o que este catalogo recusa fazer sem fonte.
_apply_starship_file() {
  local file="$SCRIPT_DIR/shared/starship.toml"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content
  content="$(cat "$file")"

  local nome_paleta="${THEME_STARSHIP_PALETTE[$TEMA]}"
  local new_nome="palette = '${nome_paleta}'"
  content="$(_splice_region_content "$content" "nome" "$new_nome")" || { FAILED=1; return 1; }

  local -n pal="${THEME_PALETTES[$TEMA]}"
  local new_cores
  new_cores="$(cat <<EOF
# Paleta reduzida: so os 13 nomes que o catalogo (data/themes.sh) sustenta —
# mauve, red, peach, yellow, green, sapphire, blue, lavender, text,
# overlay0, surface0, base, crust. Um modulo do starship que referencie
# qualquer OUTRO nome do Catppuccin (rosewater, flamingo, pink, maroon,
# teal, sky, subtext1, subtext0, overlay2, overlay1, surface2, surface1,
# mantle) vai falhar ao resolver a cor — adicione o nome ao catalogo antes.
#
# Vocabulario sempre Catppuccin, tema ativo tanto faz: quem usa essas
# chaves sao os modulos abaixo (bg:crust, fg:lavender...), e eles nao
# mudam de nome entre temas. Por isso este bloco pode ter uma chave
# chamada "peach" ou "mauve" mesmo quando a paleta oficial do tema ativo
# nao tem cor com esse nome (ex.: tokyo-night, gruvbox-dark) — ver
# data/themes.sh:THEME_PALETTE_* para a origem de cada hex (oficial ou
# papel equivalente documentado).
[palettes.${nome_paleta}]
mauve = "${pal[mauve]}"
red = "${pal[red]}"
peach = "${pal[peach]}"
yellow = "${pal[yellow]}"
green = "${pal[green]}"
sapphire = "${pal[sapphire]}"
blue = "${pal[blue]}"
lavender = "${pal[lavender]}"
text = "${pal[text]}"
overlay0 = "${pal[overlay0]}"
surface0 = "${pal[surface0]}"
base = "${pal[base]}"
crust = "${pal[crust]}"
EOF
)"
  content="$(_splice_region_content "$content" "cores" "$new_cores")" || { FAILED=1; return 1; }
  _write_file_if_changed "$file" "$content" "starship tema:nome+tema:cores"
}

_apply_lazygit_file() {
  local file="$SCRIPT_DIR/shared/lazygit/config.yml"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content interior cherry_bg_line
  content="$(cat "$file")"

  interior="$(_region_interior_content "$content" "cores")" || { FAILED=1; return 1; }
  cherry_bg_line="$(printf '%s\n' "$interior" | grep -A1 'cherryPickedCommitBgColor:' | tail -n1)"
  if [[ -z "$cherry_bg_line" ]]; then
    err "lazygit/config.yml: nao achei cherryPickedCommitBgColor dentro do marcador tema:cores — nao vou tocar o arquivo"
    FAILED=1
    return 1
  fi

  local -n pal="${THEME_PALETTES[$TEMA]}"
  local new_cores
  new_cores="$(cat <<EOF
    activeBorderColor:
      - '${pal[blue]}'
      - bold
    inactiveBorderColor:
      - '${pal[overlay0]}'
    optionsTextColor:
      - '${pal[blue]}'
    selectedLineBgColor:
      - '${pal[surface0]}'
    cherryPickedCommitBgColor:
${cherry_bg_line}
    cherryPickedCommitFgColor:
      - '${pal[blue]}'
    unstagedChangesColor:
      - '${pal[red]}'
    defaultFgColor:
      - '${pal[text]}'
EOF
)"
  content="$(_splice_region_content "$content" "cores" "$new_cores")" || { FAILED=1; return 1; }

  # git.paging (schema antigo, uma chave) virou git.pagers (schema atual,
  # uma LISTA — confirmado contra `lazygit --version` 0.60.0 nesta maquina).
  # A linha acima do marcador (fora dele, nunca reescrita por este script)
  # e "    - colorArg: always": 4 espacos, hifen, espaco, chave — a chave
  # "colorArg" comeca na coluna 6. "pager" precisa ser uma SEGUNDA chave do
  # MESMO item de lista, entao alinha com "colorArg": 6 espacos, nao 4. Com
  # 4 espacos, "pager" fica na mesma indentacao do "-" do item da lista, o
  # que e YAML invalido (testado com PyYAML: ParserError "expected <block
  # end>, but found '?'" — nao e so indentacao feia, o arquivo nao carrega).
  local new_pager
  new_pager="      pager: delta --dark --paging=never --syntax-theme=\"${THEME_DELTA[$TEMA]}\""
  content="$(_splice_region_content "$content" "pager" "$new_pager")" || { FAILED=1; return 1; }
  _warn_if_asset_missing "delta"

  _write_file_if_changed "$file" "$content" "lazygit tema:cores+tema:pager"
}

_apply_fish_file() {
  local file="$SCRIPT_DIR/shared/fish/config.fish"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content interior spinner_hex pointer_hex marker_hex
  content="$(cat "$file")"

  local new_nome="set -gx BAT_THEME \"${THEME_BAT[$TEMA]}\""
  content="$(_splice_region_content "$content" "nome" "$new_nome")" || { FAILED=1; return 1; }
  _warn_if_asset_missing "bat"

  interior="$(_region_interior_content "$content" "cores")" || { FAILED=1; return 1; }
  spinner_hex="$(printf '%s\n' "$interior" | grep -oE 'spinner:#[0-9a-fA-F]{6}' | head -n1 | cut -d: -f2)"
  pointer_hex="$(printf '%s\n' "$interior" | grep -oE 'pointer:#[0-9a-fA-F]{6}' | head -n1 | cut -d: -f2)"
  marker_hex="$(printf '%s\n' "$interior" | grep -oE 'marker:#[0-9a-fA-F]{6}' | head -n1 | cut -d: -f2)"
  if [[ -z "$spinner_hex" || -z "$pointer_hex" || -z "$marker_hex" ]]; then
    err "fish/config.fish: nao achei spinner/pointer/marker dentro do marcador tema:cores — nao vou tocar o arquivo"
    FAILED=1
    return 1
  fi

  local -n pal="${THEME_PALETTES[$TEMA]}"
  local new_cores
  new_cores="$(cat <<EOF
set -gx FZF_DEFAULT_OPTS "\\
--color=bg+:${pal[surface0]},bg:${pal[base]},spinner:${spinner_hex},hl:${pal[red]} \\
--color=fg:${pal[text]},header:${pal[red]},info:${pal[mauve]},pointer:${pointer_hex} \\
--color=marker:${marker_hex},fg+:${pal[text]},prompt:${pal[mauve]},hl+:${pal[red]}"
EOF
)"
  content="$(_splice_region_content "$content" "cores" "$new_cores")" || { FAILED=1; return 1; }

  _write_file_if_changed "$file" "$content" "fish tema:nome+tema:cores"
}

_apply_tmux_file() {
  local file="$SCRIPT_DIR/shared/tmux/.tmux.conf"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content interior cyan_line black_line pink_line lavender_line
  content="$(cat "$file")"
  interior="$(_region_interior_content "$content" "cores")" || { FAILED=1; return 1; }
  cyan_line="$(printf '%s\n' "$interior" | grep -m1 '^thm_cyan=')"
  black_line="$(printf '%s\n' "$interior" | grep -m1 '^thm_black=')"
  pink_line="$(printf '%s\n' "$interior" | grep -m1 '^thm_pink=')"
  lavender_line="$(printf '%s\n' "$interior" | grep -m1 '^thm_lavender=')"
  if [[ -z "$cyan_line" || -z "$black_line" || -z "$pink_line" || -z "$lavender_line" ]]; then
    err "tmux/.tmux.conf: nao achei thm_cyan/thm_black/thm_pink/thm_lavender dentro do marcador tema:cores — nao vou tocar o arquivo"
    FAILED=1
    return 1
  fi

  local -n pal="${THEME_PALETTES[$TEMA]}"
  local nome_bonito="${THEME_GHOSTTY[$TEMA]}"
  local new_interior
  new_interior="$(cat <<EOF
# Cores ${nome_bonito}
thm_bg="${pal[base]}"
thm_fg="${pal[text]}"
${cyan_line}
${black_line}
thm_gray="${pal[surface0]}"
thm_magenta="${pal[mauve]}"
${pink_line}
thm_red="${pal[red]}"
thm_green="${pal[green]}"
thm_yellow="${pal[yellow]}"
thm_blue="${pal[blue]}"
thm_orange="${pal[peach]}"
${lavender_line}
EOF
)"
  content="$(_splice_region_content "$content" "cores" "$new_interior")" || { FAILED=1; return 1; }
  _write_file_if_changed "$file" "$content" "tmux tema:cores"
}

# shared/nvim/lua/config/lazy.lua:35 — dentro de opts do spec da LazyVim,
# NAO a linha 56 (install.colorscheme, fallback de instalacao, sem marcador
# e nunca tocado por esta funcao). THEME_NVIM[$TEMA] escreve o nome exato de
# colorscheme confirmado com `colorscheme <nome>` nesta maquina.
_apply_nvim_file() {
  local file="$SCRIPT_DIR/shared/nvim/lua/config/lazy.lua"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content new_interior
  content="$(cat "$file")"
  new_interior="        colorscheme = \"${THEME_NVIM[$TEMA]}\","
  content="$(_splice_region_content "$content" "nome" "$new_interior")" || { FAILED=1; return 1; }
  _warn_if_asset_missing "nvim"
  _write_file_if_changed "$file" "$content" "nvim tema:nome"
}

# btop NAO tem marcador (de proposito — ver comentario em shared/btop/btop.conf:
# a ferramenta reescreve o proprio arquivo ao rodar e apagaria qualquer
# delimitador). "color_theme" e uma chave unica no arquivo — troco por match
# de chave, com checagem explicita de unicidade antes de escrever.
_apply_btop_file() {
  local file="$SCRIPT_DIR/shared/btop/btop.conf"
  [[ -f "$file" ]] || { warn "$file nao existe — pulando"; return 0; }
  local content matches
  content="$(cat "$file")"
  matches="$(printf '%s\n' "$content" | grep -c '^color_theme[[:space:]]*=')"
  if [[ "$matches" -ne 1 ]]; then
    err "btop.conf: esperava exatamente 1 linha 'color_theme =', encontrei $matches — nao vou tocar o arquivo"
    FAILED=1
    return 1
  fi

  local new_content
  new_content="$(printf '%s\n' "$content" | sed "s/^color_theme[[:space:]]*=.*/color_theme = \"${THEME_BTOP[$TEMA]}\"/")"
  _warn_if_asset_missing "btop"
  _write_file_if_changed "$file" "$new_content" "btop color_theme (sem marcador)"
}

# ────────────────────────────────────────────────────────────────────────────
# Modo lista (sem argumento)
# ────────────────────────────────────────────────────────────────────────────

_list_mode() {
  msg "Temas disponiveis: ${THEMES[*]}"
  msg ""
  msg "Estado atual por ferramenta (deteccao por nome de tema gravado):"
  msg ""

  local -a rows=()
  local val tema_detectado

  val="$(_region_interior_file "$SCRIPT_DIR/linux/ghostty/config" "nome" 2>/dev/null | sed -n 's/^theme = //p')"
  tema_detectado="$(_reverse_lookup THEME_GHOSTTY "$val")"
  rows+=("ghostty|${val:-?}|$tema_detectado")

  val="$(_region_interior_file "$SCRIPT_DIR/shared/bat/config" "nome" 2>/dev/null | sed -n 's/^--theme-dark="\(.*\)"$/\1/p')"
  tema_detectado="$(_reverse_lookup THEME_BAT "$val")"
  rows+=("bat|${val:-?}|$tema_detectado")

  val="$(_region_interior_file "$SCRIPT_DIR/shared/lazygit/config.yml" "pager" 2>/dev/null | sed -n 's/.*--syntax-theme="\(.*\)".*/\1/p')"
  tema_detectado="$(_reverse_lookup THEME_DELTA "$val")"
  rows+=("delta (lazygit pager)|${val:-?}|$tema_detectado")

  val="$(grep -m1 '^color_theme' "$SCRIPT_DIR/shared/btop/btop.conf" 2>/dev/null | sed -n 's/.*= *"\(.*\)"/\1/p')"
  tema_detectado="$(_reverse_lookup THEME_BTOP "$val")"
  rows+=("btop|${val:-?}|$tema_detectado")

  # A linha "palette = '...'" mora no marcador tema:nome, nao no tema:cores —
  # o starship.toml passou a ter dois marcadores quando veio do sistema. Ler o
  # marcador errado devolvia vazio e fazia o resumo acusar deriva inexistente.
  val="$(_region_interior_file "$SCRIPT_DIR/shared/starship.toml" "nome" 2>/dev/null | sed -n "s/^palette = '\\(.*\\)'/\\1/p")"
  tema_detectado="$(_reverse_lookup THEME_STARSHIP_PALETTE "$val")"
  rows+=("starship (palette)|${val:-?}|$tema_detectado")

  val="$(_region_interior_file "$SCRIPT_DIR/shared/fish/config.fish" "nome" 2>/dev/null | sed -n 's/^set -gx BAT_THEME "\(.*\)"$/\1/p')"
  tema_detectado="$(_reverse_lookup THEME_BAT "$val")"
  rows+=("fish (BAT_THEME)|${val:-?}|$tema_detectado")

  val="$(_region_interior_file "$SCRIPT_DIR/shared/nvim/lua/config/lazy.lua" "nome" 2>/dev/null | sed -n 's/^ *colorscheme = "\(.*\)",$/\1/p')"
  tema_detectado="$(_reverse_lookup THEME_NVIM "$val")"
  rows+=("nvim (colorscheme)|${val:-?}|$tema_detectado")

  printf '  %-24s %-20s %s\n' "FERRAMENTA" "VALOR ATUAL" "TEMA DETECTADO"
  local r nome valor tema
  for r in "${rows[@]}"; do
    IFS='|' read -r nome valor tema <<<"$r"
    printf '  %-24s %-20s %s\n' "$nome" "$valor" "$tema"
  done

  local -a unique_temas=()
  for r in "${rows[@]}"; do
    IFS='|' read -r _ _ tema <<<"$r"
    unique_temas+=("$tema")
  done
  local first="${unique_temas[0]}" consistente=1 t
  for t in "${unique_temas[@]}"; do
    [[ "$t" != "$first" ]] && consistente=0
  done

  msg ""
  if [[ $consistente -eq 1 && "$first" != "desconhecido" ]]; then
    msg "Tema ativo: $first"
  else
    msg "⚠️  Sem tema unico ativo — ferramentas em temas diferentes entre si (deriva). Ver tabela acima."
  fi

  msg ""
  msg "Fora do escopo deste script: shared/yazi/theme.toml (sem marcador — fica fixo em Catppuccin Mocha)."
  msg ""
  msg "Uso: bash scripts/set_theme.sh <tema>   (DRY_RUN=1 para simular, APPLY_LIVE=1 para tambem espelhar em ~/.config)"
}

# ────────────────────────────────────────────────────────────────────────────
# Relatorio final
# ────────────────────────────────────────────────────────────────────────────

_report() {
  msg ""
  msg "═══ Resumo — tema \"$TEMA\" ═══"
  if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
    if is_truthy "$DRY_RUN"; then
      msg "(dry-run) Nada foi escrito. Os arquivos acima marcados com 🔎 mudariam se rodasse sem DRY_RUN."
    else
      msg "Nenhum arquivo mudou — o tema \"$TEMA\" ja estava aplicado em tudo que este script gerencia."
    fi
  else
    msg "Arquivos alterados (${#CHANGED_FILES[@]}):"
    local f
    for f in "${CHANGED_FILES[@]}"; do msg "  - $f"; done
  fi

  if [[ ${#ASSET_WARNINGS[@]} -gt 0 ]]; then
    msg ""
    msg "Avisos — asset de tema faltando nesta maquina (instalacao automatica tentada e sem sucesso — ver mensagens acima):"
    local w
    for w in "${ASSET_WARNINGS[@]}"; do warn "$w"; done
  fi

  msg ""
  msg "Fora do escopo deste script (nao alterado): shared/yazi/theme.toml (sem marcador — fica fixo em Catppuccin Mocha)."

  if ! is_truthy "$DRY_RUN" && [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    msg ""
    msg "Acao do usuario:"
    msg "  - Reabra o ghostty e recarregue o fish (nova sessao ou 'exec fish') para ver as novas cores."
    msg "  - tmux: rode 'tmux source-file ~/.tmux.conf' na sessao ativa (ou saia e reabra)."
    msg "  - lazygit/bat/delta/btop pegam o valor novo na proxima vez que abrirem."
    msg "  - nvim: pega o colorscheme novo na proxima vez que abrir (o <leader>uC em sessao ja aberta e so preview e nao muda com este script)."
    if ! is_truthy "$APPLY_LIVE"; then
      msg "  - Isto alterou SO o repositorio. Para propagar para ~/.config agora, rode de novo com APPLY_LIVE=1, ou use o fluxo normal de install/sync do install.sh."
    fi
  fi

  if [[ -n "$BACKUP_DIR" ]]; then
    msg ""
    msg "Backup dos arquivos originais em: $BACKUP_DIR"
  fi
}

# ────────────────────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────────────────────

show_usage() {
  cat <<EOF
Uso:
  bash scripts/set_theme.sh                       lista temas disponiveis e o ativo
  bash scripts/set_theme.sh <tema>                aplica o tema
  DRY_RUN=1 bash scripts/set_theme.sh <tema>      mostra o que faria, sem escrever
  APPLY_LIVE=1 bash scripts/set_theme.sh <tema>   tambem espelha em ~/.config

Temas disponiveis: ${THEMES[*]}
EOF
}

if [[ $# -eq 0 ]]; then
  _list_mode
  exit 0
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  err "argumentos demais"
  show_usage >&2
  exit 1
fi

TEMA="$1"
_valid=0
for _t in "${THEMES[@]}"; do
  [[ "$_t" == "$TEMA" ]] && _valid=1
done
if [[ $_valid -ne 1 ]]; then
  err "tema invalido: '$TEMA'"
  show_usage >&2
  exit 2
fi

msg "Aplicando tema: $TEMA"
is_truthy "$DRY_RUN" && msg "(dry-run — nada sera escrito)"
msg ""

# Tenta instalar o asset do tema pedido (bat/delta em tokyo-night,
# btop em catppuccin-mocha) ANTES de aplicar qualquer arquivo — e o que
# permite _warn_if_asset_missing, mais abaixo, parar de avisar quando a
# instalacao funcionou. Sempre roda (nao gatea em APPLY_LIVE — ver cabecalho
# de lib/theme_assets.sh para a justificativa).
install_theme_assets_for "$TEMA"
msg ""

_apply_ghostty_file "$SCRIPT_DIR/linux/ghostty/config"
_apply_ghostty_file "$SCRIPT_DIR/macos/ghostty/config"
_apply_bat_file
_apply_starship_file
_apply_lazygit_file
_apply_fish_file
_apply_tmux_file
_apply_btop_file
_apply_nvim_file

if is_truthy "$APPLY_LIVE"; then
  msg ""
  msg "Espelhando para ~/.config (APPLY_LIVE=1)..."
  _mirror_live "$SCRIPT_DIR/linux/ghostty/config" "$HOME/.config/ghostty/config"
  _mirror_live "$SCRIPT_DIR/shared/bat/config" "$HOME/.config/bat/config"
  _mirror_live "$SCRIPT_DIR/shared/starship.toml" "$HOME/.config/starship.toml"
  _mirror_live "$SCRIPT_DIR/shared/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
  _mirror_live "$SCRIPT_DIR/shared/fish/config.fish" "$HOME/.config/fish/config.fish"
  _mirror_live "$SCRIPT_DIR/shared/tmux/.tmux.conf" "$HOME/.tmux.conf"
  _mirror_live "$SCRIPT_DIR/shared/btop/btop.conf" "$HOME/.config/btop/btop.conf"
  _mirror_live "$SCRIPT_DIR/shared/nvim/lua/config/lazy.lua" "$HOME/.config/nvim/lua/config/lazy.lua"
fi

_report

exit "$FAILED"
