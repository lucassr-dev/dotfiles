#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Catalogo de temas — Fase 3 (Tarefa 1)
#
# Contrato lido pelas Tarefas 2-5 para aplicar um unico tema as dez
# ferramentas de terminal que hoje declaram tema de cinco formas diferentes:
#   - nome de tema embutido:      ghostty, bat, btop, delta, nvim
#   - nome de paleta + definicao: starship
#   - hex inline em env var:      fzf (FZF_DEFAULT_OPTS, fish e zsh)
#   - hex inline em arquivo:      lazygit, yazi
#   - variaveis proprias:         tmux (thm_*)
#
# delta nao apareceu na lista original do dono (fica embutido dentro de
# shared/lazygit/config.yml, na linha do "pager": --syntax-theme="..."), mas
# declara tema por nome exatamente como bat/ghostty/btop, usando o MESMO
# catalogo de temas do bat (confirmado comparando `bat --list-themes` com
# `delta --list-syntax-themes` — os nomes usados aqui aparecem nos dois).
#
# Regra desta tarefa: nenhum nome nem cor aqui foi inventado. Cada valor tem
# fonte verificavel — ferramenta instalada nesta maquina, arquivo do proprio
# repositorio, ou paleta oficial do projeto do tema. A lista completa de
# fontes e os comandos de verificacao estao em task-1-report.md, ao lado
# deste brief.

# ════════════════════════════════════════════════════════════════════════
# Temas suportados
# ════════════════════════════════════════════════════════════════════════

THEMES=(catppuccin-mocha tokyo-night gruvbox-dark)

# ════════════════════════════════════════════════════════════════════════
# Nome de tema por ferramenta (ferramentas que escolhem tema pelo nome)
# ════════════════════════════════════════════════════════════════════════

# Confirmado com `ghostty +list-themes` nesta maquina.
declare -A THEME_GHOSTTY=(
  [catppuccin-mocha]="Catppuccin Mocha"
  [tokyo-night]="TokyoNight Night"  # ghostty tambem lista "TokyoNight" sem sufixo — mesmo arquivo, mesmas cores (bg #1a1b26); "Night" deixa explicito que e a variante usada no nvim (style = "night")
  [gruvbox-dark]="Gruvbox Dark"
)

# Confirmado com `bat --list-themes` nesta maquina.
declare -A THEME_BAT=(
  [catppuccin-mocha]="Catppuccin Mocha"
  [tokyo-night]="TokyoNight"  # falta instalar — ver THEME_ASSET_STATUS
  [gruvbox-dark]="gruvbox-dark"
)

# delta usa o mesmo registro de temas do bat (syntect). Confirmado com
# `delta --list-syntax-themes` nesta maquina. E chamado de dentro do
# shared/lazygit/config.yml (git.pagers[].pager), nao tem arquivo de tema proprio.
declare -A THEME_DELTA=(
  [catppuccin-mocha]="Catppuccin Mocha"
  [tokyo-night]="TokyoNight"  # mesma lacuna do bat — o mesmo asset resolve os dois
  [gruvbox-dark]="gruvbox-dark"
)

# btop empacota varios temas dentro do proprio snap
# (/snap/btop/*/usr/local/share/btop/themes/*.theme), confirmado nesta maquina.
# "tokyo-night" e "gruvbox_dark" sao nativos (o arquivo .theme ja esta no
# pacote); "catppuccin_mocha" nao esta — precisa de asset (THEME_ASSET_STATUS).
declare -A THEME_BTOP=(
  [catppuccin-mocha]="catppuccin_mocha"  # nome que o shared/btop/btop.conf atual ja usa (hoje aponta pra um tema que nao existe no sistema)
  [tokyo-night]="tokyo-night"
  [gruvbox-dark]="gruvbox_dark"
)

# Confirmado com `nvim --headless -c 'colorscheme <nome>'` nesta maquina —
# nomes de variante especifica, nao dependem da opcao flavour/style
# configurada em shared/nvim/lua/plugins/theme.lua.
declare -A THEME_NVIM=(
  [catppuccin-mocha]="catppuccin-mocha"
  [tokyo-night]="tokyonight-night"
  [gruvbox-dark]="gruvbox"  # confirmado na Tarefa 5 apos instalar ellisonleao/gruvbox.nvim (theme.lua) — nome ja estava certo, sem correcao necessaria
)

# Nome do bloco [palettes.X] dentro do proprio shared/starship.toml — o
# starship nao tem "tema instalavel", a definicao mora no arquivo (as cores
# saem de THEME_PALETTES, abaixo). "gruvbox_dark" e o nome que o arquivo ja
# usa hoje — e a causa da fase (paleta certa, ferramenta errada).
declare -A THEME_STARSHIP_PALETTE=(
  [catppuccin-mocha]="catppuccin_mocha"
  [tokyo-night]="tokyo_night"
  [gruvbox-dark]="gruvbox_dark"
)

# ════════════════════════════════════════════════════════════════════════
# Paleta hex por tema
#
# fzf, lazygit, yazi e tmux nao escolhem tema pelo nome — a Tarefa 2 monta o
# formato de cada um a partir destas cores. Vocabulario do Catppuccin porque
# e o que os arquivos atuais (shared/yazi/theme.toml, FZF_DEFAULT_OPTS) ja
# usam. Cobre so as cores essenciais (base/texto/superficie/borda + as 6 de
# status/acento); nao cobre o conjunto estendido de 26 cores que
# shared/yazi/theme.toml usa nas regras de icone por extensao — ver
# task-1-report.md, secao "Preocupacoes".
# ════════════════════════════════════════════════════════════════════════

# Fonte: shared/yazi/theme.toml (comentario de cabecalho com a paleta oficial
# do Catppuccin Mocha) e shared/fish/config.fish (FZF_DEFAULT_OPTS) — e a
# paleta que o dono ja usa em produção, os dois arquivos coincidem.
#
# crust/lavender/sapphire (Tarefa 3b, Problema 3): copiados de dentro do
# proprio shared/starship.toml, bloco [palettes.catppuccin_mocha] (marcador
# tema:cores) — linhas 198, 186 e 184 respectivamente. Sao os modulos do
# starship (fg:crust, fg:lavender, bg:sapphire) que exigem essas 3 cores;
# ver task-3b-brief.md, Problema 1.
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

# Fonte: plugin tokyonight.nvim, ja instalado nesta maquina, em
# ~/.local/share/nvim/lazy/tokyonight.nvim/lua/tokyonight/colors/{night,storm}.lua
# (variante "night", igual ao style configurado em
# shared/nvim/lua/plugins/theme.lua). Tokyo Night nao tem cor chamada "mauve"
# ou "peach" — usei o papel equivalente (magenta/orange), que e a mesma
# escolha feita pelos proprios extras oficiais do plugin (extras/fzf,
# extras/lazygit) para os destaques quentes/frios.
#
# crust/lavender/sapphire (Tarefa 3b, Problema 3): Tokyo Night nao tem cores
# com esses nomes — sem "papel" 1:1 como mauve/peach ja tinham (magenta e
# orange sao aceitos como sinonimos; nao ha sinonimo para crust/lavender/
# sapphire). Usei o papel equivalente na MESMA fonte (night.lua/storm.lua),
# documentado caso a caso abaixo; nenhum hex inventado, todos vem do arquivo.
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
  # papel "crust" = fundo mais escuro que o base. night.lua define bg_dark1 =
  # "#0C0E14", mais escuro que bg_dark ("#16161e", ja usado internamente pelo
  # plugin para popup/sidebar/statusline — o papel de "mantle", que fica de
  # fora do catalogo). bg_dark1 e o unico tom MAIS escuro que isso: e usado
  # como camada mais profunda em extras/discord.lua ("background-tertiary"),
  # o mesmo papel de "camada mais escura" que crust tem no Catppuccin.
  [crust]="#0C0E14"      # night.lua: bg_dark1
  # papel "roxo claro". storm.lua tem duas cores roxas: magenta ("#bb9af7",
  # ja usada acima para mauve) e purple ("#9d7cd8"). purple e a unica que
  # resta sem reaproveitar uma cor ja atribuida a outro papel.
  [lavender]="#9d7cd8"   # storm.lua: purple
  # papel "azul ciano". storm.lua: cyan ("#7dcfff") — tom mais proximo do
  # sapphire do Catppuccin (#74c7ec: tambem azul-ciano claro) entre as
  # variantes de azul do arquivo (blue/blue0/blue1/blue2/blue5/blue6/cyan).
  [sapphire]="#7dcfff"   # storm.lua: cyan
)

# Fonte: paleta oficial do gruvbox — morhetz/gruvbox, colors/gruvbox.vim
# (secao "neutral"). Conferida contra tres fontes independentes ja neste
# sistema: shared/starship.toml (mesmos hex, sob o nome errado — a causa da
# fase), o tema "Gruvbox Dark" empacotado no ghostty e o gruvbox_dark.theme
# empacotado no btop.
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
  # papel "crust" = fundo mais escuro que o base (dark0). Paleta oficial
  # gruvbox tem tres tons de fundo: dark0_hard/dark0/dark0_soft; dark0 e o
  # que ja esta em [base]. dark0_hard e o mais escuro dos tres — confirmado
  # nesta maquina em /snap/btop/*/usr/local/share/btop/themes/gruvbox_dark.theme
  # (theme[main_bg]), pacote instalado que empacota a mesma paleta oficial.
  [crust]="#1d2021"      # gruvbox dark0_hard — btop (snap): theme[main_bg]
  # papel "roxo claro". [mauve] acima ja usa o "neutral purple" (#b16286);
  # a paleta tambem define um "bright purple" mais claro — confirmado nesta
  # maquina em "/snap/ghostty/*/share/ghostty/themes/Gruvbox Dark" (palette
  # 13) e no mesmo gruvbox_dark.theme do btop (temp_mid/upload_end).
  [lavender]="#d3869b"   # gruvbox bright purple
  # papel "azul ciano". [blue] acima ja usa o "neutral blue" (#458588); a
  # paleta tambem define um "bright blue" mais claro e mais ciano —
  # confirmado nesta maquina no mesmo ghostty theme (palette 12) e no
  # gruvbox_dark.theme do btop (cached_end).
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
# escrever o nome, senao a ferramenta cai num tema que nao existe (Tarefa 3
# avisa em vez de gravar; Tarefa 4 baixa). Confirmado nesta maquina em
# Set/2026, nao copiado do brief:
#
#   - bat/delta: Catppuccin e gruvbox-dark nativos; falta Tokyo Night (sem
#     .tmTheme em ~/.config/bat/themes/, que nem existe ainda)
#   - btop: o pacote (snap) JA vem com tokyo-night.theme e gruvbox_dark.theme
#     — a lacuna real e so catppuccin_mocha (justamente o tema que o
#     btop.conf atual ja referencia; ja estava quebrado antes desta tarefa)
#   - nvim: catppuccin e tokyonight resolvem hoje (plugins instalados);
#     gruvbox tambem — ellisonleao/gruvbox.nvim instalado na Tarefa 5,
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
  ["gruvbox-dark:nvim"]="native"  # Tarefa 5: ellisonleao/gruvbox.nvim instalado, plugin nao falta mais
)
