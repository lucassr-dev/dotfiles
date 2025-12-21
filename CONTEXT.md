# Context - Dotfiles Installer Refactor

## Estado atual
- Script principal: `install.sh` (orquestrador).
- Dados externos:
  - `data/apps.sh` (listas de apps por categoria).
  - `data/runtimes.sh` (runtimes default/opcionais do mise).
- Libs:
  - `lib/gui_apps.sh` (selecao de apps GUI).
  - `lib/runtimes.sh` (selecao/instalacao de runtimes via mise).
  - `lib/report.sh` (relatorio final).
- `shared/mise/config.toml` com node/python/php latest por padrao.
- `.gitignore` ignora `.ssh/` e `.dotfiles-backup-*/`.
- `DRY_RUN=1` simula copias/sudo.

## Contexto definitivo (lista completa de mudancas solicitadas)

1) Boas-vindas + banner
   - Banner ASCII responsivo com mensagem curta de boas-vindas.
   - Links úteis (site e repositório) com explicação breve.

2) Selecao de shells (obrigatoria)
   - Tela: 1) zsh 2) fish 3) ambos.
   - Instalar e copiar configs somente para os selecionados.

3) Dependencias base (antes ou junto das fontes)
   - Informar que git/curl/wget/build-essential/etc serao instalados.
   - Opcao de pular (com aviso de possiveis erros).

4) Nerd Fonts (antes dos temas) - CRITICO
   - Tela informando necessidade das fontes.
   - NAO versionar fontes no repo (manter repo pequeno).
   - Download dinamico das releases oficiais do Nerd Fonts (ryanoasis/nerd-fonts).
   - Menu interativo de selecao de fontes.
   - Instalacao correta por OS (Linux: ~/.local/share/fonts, macOS: ~/Library/Fonts, Windows: %LOCALAPPDATA%\Microsoft\Windows\Fonts).
   - Aviso e opcao de pular (pode quebrar temas).

5) Selecao de temas (compatibilidade por shell/OS)
   - Oh My Zsh + p10k + plugins (zsh, Linux/macOS).
   - Oh My Posh (zsh/fish/pwsh em Linux/macOS/Windows).
   - Starship (zsh/fish, Linux/macOS).
   - Permitir escolher em quais shells e OS aplicar cada tema.
   - Tela de confirmacao com resumo de temas/shells/OS.
   - IMPORTANTE: Nenhum tema instalado automaticamente (remover Oh My Posh "critical" do Windows).

6) Previa de temas (best-effort)
   - Texto + descricao sempre.
   - Imagem inline se suportado (kitty icat / iTerm2 / img2sixel / ghostty).
   - Fallback: texto + link.

7) Plugins / presets por tema
   - Oh My Zsh: lista de plugins selecionaveis.
   - Oh My Posh: lista de temas.
   - Starship: presets (catppuccin-powerline, tokyo-night, gruvbox-rainbow, pastel-powerline, nerd-font-symbols, plain-text-symbols).

8) Categoria "CLI Tools" (selecao interativa) - CRITICO
   - Incluir: fzf, zoxide, eza, bat, ripgrep, fd, delta, lazygit, gh, jq, direnv, btop, tmux, starship.
   - Mover Atuin para esta categoria (remover pergunta separada).
   - Adicionar breve descricao de cada ferramenta.
   - Tela de selecao individual com opcao "todos" ou "nenhum".
   - NENHUMA ferramenta CLI instalada sem confirmacao explicita.

9) Categoria "IA Tools" (selecao interativa)
   - spec-kit, serena, codex, claude-code.
   - Mover spec-kit para ca (remover pergunta separada).
   - Instalar via fontes oficiais; fallback com instrucao manual.

10) Categoria "Terminais" (nova categoria) - CRITICO
   - Linux: Ghostty, Kitty, Alacritty, GNOME Terminal, etc.
   - macOS: iTerm2, Ghostty, Kitty, Alacritty (sugestao padrao: iTerm2 + Ghostty).
   - Windows: Windows Terminal, etc.
   - Remover instalacao automatica de Ghostty no macOS.

11) Apps por categoria (fontes oficiais 2025)
   - IDEs: VS Code, Zed, Xcode, PHPStorm, WebStorm, PyCharm, Cursor, etc.
   - Navegadores: Chrome, Brave, Zen, Arc, Firefox.
   - Comunicacao: Discord, WhatsApp, Teams, etc.
   - Produtividade: Slack, Notion, Obsidian, etc.
   - Bancos: PostgreSQL, Redis, MySQL, pgAdmin, MongoDB, DBeaver.
   - Midia/Utilidades: VLC, Spotify, Flameshot, Screenkey, ShareX, PowerToys, etc.
   - Mostrar claramente quando um app for exclusivo de um OS.

12) Git configuracoes (selecao interativa)
   - Multi-conta: Perguntar pastas pessoais e de trabalho + user/email/user de cada conta.
   - core.editor: Perguntar preferencia (input com defaults).
   - core.pager: Perguntar preferencia (input com defaults).
   - Configs avancados: MANTER (merge.conflictstyle, diff.colorMoved, delta settings - nao quebram).
   - Atualizar .gitconfig* com includeIf.

13) Runtimes via mise
   - Avisar: "Para gerenciar versoes de Node, Python, PHP, etc., sera usado o 'mise'."
   - Perguntar: "Deseja instalar runtimes? (s/n)"
   - Se "nao", pular mise + runtimes completamente.
   - Se "sim": Node/Python/PHP latest por padrao.
   - Opcionais: Go/Rust/Bun/Deno/Elixir/Java/Ruby.
   - IDs sempre do mise-tools.

14) Modularizacao completa
   - Extrair instaladores por OS para lib/os_linux.sh, lib/os_macos.sh, lib/os_windows.sh.
   - install.sh fica como orquestrador de telas e chamadas.

15) Brewfile dinamico (macOS) - CRITICO
   - NAO ter Brewfile fixo no repo.
   - Gerar Brewfile dinamicamente baseado na selecao de apps/CLI tools.
   - ZERO apps instalados sem confirmacao explicita.
   - Perguntar antes: "Instalar apps do Brewfile gerado? (s/n)"

16) VS Code configuracoes
   - Settings: Instalar settings padrao do script (usuario altera depois via UI).
   - Extensions: Instalar do extensions.txt (opcional).
   - Perguntar antes, durante as selecoes.
   - Usuario pode editar extensions.txt antes de rodar o script.

17) SSH keys
   - NAO versionar .ssh/ no repo publico (.gitignore ja cobre).
   - Se shared/.ssh/ existir, copiar e ajustar permissoes (700/600).
   - Avisar: "AVISO: Verifique se nao esta commitando chaves privadas!"
   - Permissoes 700/600: MANTER (SSH exige permissoes restritas).
   - Opcional: repo privado com `shared/.ssh` e `shared/git/.gitconfig-*` tem prioridade.

18) CRLF normalization
   - MANTER conversao CRLF -> LF em sistemas Unix.
   - Evita erros de sintaxe em shells.
   - Essencial para scripts executaveis (.sh, .zsh, .fish).

19) WSL2 ajustes
   - Investigar durante implementacao se precisa ajustes especificos.
   - Se nao houver diferencas praticas, tratar como Linux normal.

20) Resumo final compacto
   - Mostrar versoes dos tools instalados e runtimes.
   - Mostrar backup criado e erros apenas quando existirem.
   - Detalhes completos via VERBOSE_REPORT=1.

21) Anti-duplicidade
   - Continuar evitando instalar o mesmo app via multiplos gerenciadores.

## Observacoes adicionais
- Ordem confirmada: dependencias base antes ou junto da etapa de fontes.
- Preview: best-effort, com deteccao de suporte para kitty/iTerm2/sixel/ghostty.

## Proximos passos
- Versao 2.0 funcional implementada e consolidada.

## Observacoes
- Repositorio em uso com historico ativo.
