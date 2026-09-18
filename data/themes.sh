#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Catalogo de temas. As dez ferramentas declaram tema de cinco formas: nome
# embutido (ghostty, bat, btop, delta, nvim), nome de paleta mais definicao
# (starship), hex em env var (fzf), hex em arquivo (lazygit, yazi) e
# variaveis proprias (tmux).
#
# Nenhum nome aqui foi inventado: cada um saiu do `--list-themes` da propria
# ferramenta. Ao acrescentar tema, confira antes -- nome errado nao da erro,
# a ferramenta cai no padrao em silencio.

# ════════════════════════════════════════════════════════════════════════
# Temas suportados
# ════════════════════════════════════════════════════════════════════════

THEMES=(catppuccin-mocha tokyo-night gruvbox-dark)

# ════════════════════════════════════════════════════════════════════════
# Nome de tema por ferramenta (ferramentas que escolhem tema pelo nome)
# ════════════════════════════════════════════════════════════════════════

declare -A THEME_GHOSTTY=(
  [catppuccin-mocha]="Catppuccin Mocha"
  [tokyo-night]="TokyoNight Night"  # "TokyoNight" sem sufixo e o mesmo arquivo; o sufixo casa com o nvim
  [gruvbox-dark]="Gruvbox Dark"
)

declare -A THEME_BAT=(
  [catppuccin-mocha]="Catppuccin Mocha"
  [tokyo-night]="TokyoNight"  # falta instalar — ver THEME_ASSET_STATUS
  [gruvbox-dark]="gruvbox-dark"
)

# delta usa o registro do bat (syntect) e e chamado de dentro do lazygit.
declare -A THEME_DELTA=(
  [catppuccin-mocha]="Catppuccin Mocha"
  [tokyo-night]="TokyoNight"  # mesma lacuna do bat — o mesmo asset resolve os dois
  [gruvbox-dark]="gruvbox-dark"
)

# "tokyo-night" e "gruvbox_dark" vem no pacote; "catppuccin_mocha" precisa
# de asset (ver THEME_ASSET_STATUS).
declare -A THEME_BTOP=(
  [catppuccin-mocha]="catppuccin_mocha"  # nome que o shared/btop/btop.conf atual ja usa (hoje aponta pra um tema que nao existe no sistema)
  [tokyo-night]="tokyo-night"
  [gruvbox-dark]="gruvbox_dark"
)

# Nomes de variante especifica: nao dependem da opcao flavour/style em
# shared/nvim/lua/plugins/theme.lua.
declare -A THEME_NVIM=(
  [catppuccin-mocha]="catppuccin-mocha"
  [tokyo-night]="tokyonight-night"
  [gruvbox-dark]="gruvbox"
)

# Nome do bloco [palettes.X] dentro do proprio shared/starship.toml: o
# starship nao tem tema instalavel, a definicao mora no arquivo.
declare -A THEME_STARSHIP_PALETTE=(
  [catppuccin-mocha]="catppuccin_mocha"
  [tokyo-night]="tokyo_night"
  [gruvbox-dark]="gruvbox_dark"
)

# ════════════════════════════════════════════════════════════════════════
# Paleta hex por tema
#
# fzf, lazygit, yazi e tmux nao escolhem tema pelo nome: o formato de cada
# um e montado a partir destas cores. Vocabulario do Catppuccin porque e o
# que os arquivos atuais ja usam. Cobre so as cores essenciais.

# Fonte: shared/yazi/theme.toml e shared/fish/config.fish, que coincidem.
declare -A THEME_PALETTE_CATPPUCCIN_MOCHA=(
  [base]="#1e1e2e"
  [text]="#cdd6f4"
  [surface0]="#313244"
  [overlay0]="#6c7086"
  [red]="#f38ba8"
  [green]="#a6e3a1"
  [yellow]="#f9e2af"
  [blue]="#89b4fa"
  [mauve]="#cba6f7"
  [peach]="#fab387"
  [crust]="#11111b"      # shared/starship.toml:198 (palettes.catppuccin_mocha.crust)
  [lavender]="#b4befe"   # shared/starship.toml:186 (palettes.catppuccin_mocha.lavender)
  [sapphire]="#74c7ec"   # shared/starship.toml:184 (palettes.catppuccin_mocha.sapphire)
)

# Fonte: tokyonight.nvim, variante "night".
#
# Tokyo Night nao tem cor chamada mauve, peach, crust, lavender nem
# sapphire: cada uma usa o PAPEL equivalente da mesma fonte, nunca um hex
# inventado. As tres ultimas estao anotadas caso a caso abaixo.
declare -A THEME_PALETTE_TOKYO_NIGHT=(
  [base]="#1a1b26"      # night.lua: bg
  [text]="#c0caf5"      # storm.lua: fg (night nao sobrescreve)
  [surface0]="#292e42"  # storm.lua: bg_highlight
  [overlay0]="#565f89"  # storm.lua: comment
  [red]="#f7768e"       # storm.lua: red
  [green]="#9ece6a"     # storm.lua: green
  [yellow]="#e0af68"    # storm.lua: yellow
  [blue]="#7aa2f7"      # storm.lua: blue
  [mauve]="#bb9af7"     # storm.lua: magenta
  [peach]="#ff9e64"     # storm.lua: orange
  # papel "crust": bg_dark1, o tom mais escuro que night.lua define.
  [crust]="#0C0E14"      # night.lua: bg_dark1
  # papel "roxo claro": purple, a unica roxa ainda nao usada.
  [lavender]="#9d7cd8"   # storm.lua: purple
  # papel "azul ciano": cyan, o mais proximo do sapphire.
  [sapphire]="#7dcfff"   # storm.lua: cyan
)

# Fonte: paleta oficial do gruvbox (morhetz/gruvbox, secao "neutral"),
# conferida contra o starship.toml, o ghostty e o btop deste sistema.
declare -A THEME_PALETTE_GRUVBOX_DARK=(
  [base]="#282828"      # dark0
  [text]="#ebdbb2"      # light1
  [surface0]="#3c3836"  # dark1
  [overlay0]="#665c54"  # dark3
  [red]="#cc241d"       # neutral red
  [green]="#98971a"     # neutral green
  [yellow]="#d79921"    # neutral yellow
  [blue]="#458588"      # neutral blue
  [mauve]="#b16286"     # neutral purple — papel equivalente, gruvbox nao tem "mauve"
  [peach]="#d65d0e"     # neutral orange — papel equivalente, gruvbox nao tem "peach"
  # papel "crust": dark0_hard, o mais escuro dos tres fundos.
  [crust]="#1d2021"      # gruvbox dark0_hard — btop (snap): theme[main_bg]
  # papel "roxo claro": bright purple ([mauve] ja usa o neutral).
  [lavender]="#d3869b"   # gruvbox bright purple
  # papel "azul ciano": bright blue ([blue] ja usa o neutral).
  [sapphire]="#83a598"   # gruvbox bright blue
)

# Bash nao tem array de array. THEME_PALETTES indica, por tema, o NOME do
# array de paleta acima — quem consome resolve com nameref, no mesmo padrao
# usado em lib/*.sh (ex.: lib/state.sh, lib/ui.sh):
#
#   local tema="tokyo-night"
#   local -n pal="${THEME_PALETTES[$tema]}"
#   echo "${pal[base]}"
declare -A THEME_PALETTES=(
  [catppuccin-mocha]="THEME_PALETTE_CATPPUCCIN_MOCHA"
  [tokyo-night]="THEME_PALETTE_TOKYO_NIGHT"
  [gruvbox-dark]="THEME_PALETTE_GRUVBOX_DARK"
)

# ════════════════════════════════════════════════════════════════════════
# Nativo vs. precisa de asset
#
# Chave "<tema>:<ferramenta>". "native" = a ferramenta ja reconhece o nome
# hoje, sem instalar nada. "asset" = precisa baixar/instalar antes de
# escrever o nome, senao a ferramenta cai num tema que nao existe.
# Confirmado nesta maquina em
# Set/2026, nao copiado do brief:
#
#   - bat/delta: Catppuccin e gruvbox-dark nativos; falta Tokyo Night (sem
#     .tmTheme em ~/.config/bat/themes/, que nem existe ainda)
#   - btop: o pacote (snap) JA vem com tokyo-night.theme e gruvbox_dark.theme
#     — a lacuna real e so catppuccin_mocha (justamente o tema que o
#     btop.conf atual ja referencia; ja estava quebrado antes desta tarefa)
#   - nvim: catppuccin e tokyonight resolvem hoje (plugins instalados);
#     gruvbox tambem — ellisonleao/gruvbox.nvim instalado,
#     colorscheme confirmado como "gruvbox" (o nome que ja estava aqui,
#     agora verificado). Sem lacuna nos tres temas.
#   - ghostty e starship: sem lacuna em nenhum dos tres temas — starship nem
#     entra nesta tabela, porque a paleta mora no proprio arquivo, nao ha
#     "asset" para instalar
declare -A THEME_ASSET_STATUS=(
  ["catppuccin-mocha:ghostty"]="native"
  ["catppuccin-mocha:bat"]="native"
  ["catppuccin-mocha:delta"]="native"
  ["catppuccin-mocha:btop"]="asset"
  ["catppuccin-mocha:nvim"]="native"

  ["tokyo-night:ghostty"]="native"
  ["tokyo-night:bat"]="asset"
  ["tokyo-night:delta"]="asset"
  ["tokyo-night:btop"]="native"
  ["tokyo-night:nvim"]="native"

  ["gruvbox-dark:ghostty"]="native"
  ["gruvbox-dark:bat"]="native"
  ["gruvbox-dark:delta"]="native"
  ["gruvbox-dark:btop"]="native"
  ["gruvbox-dark:nvim"]="native"
)
