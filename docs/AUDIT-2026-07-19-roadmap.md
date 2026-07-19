# Auditoria 2026-07-19 — checkpoint e roadmap

**Por que este arquivo existe:** sessão longa de Claude Code, contexto prestes a ser compactado
automaticamente. Este arquivo é a fonte de verdade do que já foi feito e do que falta — sobrevive
à compactação porque está commitado no repo, não só na conversa. Se uma sessão nova (ou a mesma
pós-compactação) precisar retomar, ler este arquivo primeiro.

## Contexto

Usuário tem 4 máquinas: Windows (dev, esta máquina), Windows (VM que roda os servidores do
BrutusForge), Linux (trabalho), macOS Hackintosh (dual-boot nesta mesma máquina). Já existia um
sistema de dotfiles sério e maduro (`github.com/lucassr-dev/dotfiles`, público, ~3200 linhas
`install.sh` + 22 módulos `lib/`, instalador interativo multi-OS). Sessão de hoje: (1) construiu
um template de config global do Claude Code (CLAUDE.md/RTK.md/skill impeccable/settings.fragment/
merge script) inicialmente como repo standalone (`claude-code-template`), (2) depois integrou isso
DENTRO do dotfiles real (`shared/claude/` + `_apply_claude_config()` em `install.sh`, mesmo padrão
já usado pra `aider`), (3) descobriu que o CI do dotfiles estava vermelho/travado há ~3 meses e fez
uma auditoria completa (6 agentes paralelos) achando bugs reais, (4) aplicou as correções mais
críticas, CI ficou verde pela primeira vez em 3 meses.

## Já feito e commitado (não precisa refazer)

Tudo isso já está em `main` do `github.com/lucassr-dev/dotfiles`, pushado:

1. **Integração Claude Code completa**: `shared/claude/{CLAUDE.md,RTK.md,settings.fragment.json,merge-settings.mjs,skills/impeccable/,README.md}` + `_apply_claude_config()`/export correspondente em `install.sh`, wired no fluxo de Ferramentas IA (`COPY_CLAUDE_CONFIG`).
2. **Fix do CI travado (causa raiz)**: `install_prerequisites()` em `install.sh` rodava `brew update`/`winget install` de verdade em macOS/Windows mesmo com `DRY_RUN=1` (só Linux respeitava via `run_with_sudo`). Corrigido com guard de `DRY_RUN` — testado localmente, dry-run real passou de travado/30min+ para 1s/exit-0.
3. **2 loops `while true`+`read` sem tratamento de EOF** corrigidos (`lib/ui.sh:474` `ui_select_single_bash`, `install.sh` ~518 SSH rename prompt) — travavam sob stdin fechado não-interativo.
4. **Segurança**: instalação do Claude Code no Windows usava `irm | iex` direto, bypassando `REMOTE_SCRIPT_ALLOWLIST`/`REMOTE_SCRIPT_STRICT`/checksum/`DRY_RUN` (único dos 14 installers remotos do repo que fazia isso) — corrigido pra rotear pela mesma validação dos outros 13.
5. **`scripts/sync_public.sh`**: lista de exclusão do rsync era mantida a mão, separada do `.gitignore` real — já causou 2 vazamentos históricos (CLAUDE.md/CONTEXT.md commitados no público antes de virarem gitignored). Corrigido: agora deriva de `--exclude-from=.gitignore`.
6. **WezTerm** "official" mentia sucesso em macOS/Windows (instalador só serve Linux, sem guard de `TARGET_OS`) — corrigido.
7. **RedisInsight** winget ID desatualizado (`RedisLabs.RedisInsight` → `RedisInsight.RedisInsight`, rebrand) — corrigido em `lib/install_priority.sh` + `lib/app_installers.sh`.
8. **2 bugs na própria integração Claude Code de ontem**: export de skill hardcoded pra "impeccable" em vez de data-driven (corrigido, agora itera `shared/claude/skills/*/`); faltava guard de `SKILL.md` antes de tratar uma pasta como skill válida (corrigido).
9. **CI workflow** (`.github/workflows/validate.yml`): `timeout-minutes` em todos os jobs (rede de segurança contra hangs futuros) + removido `|| true` que mascarava falhas reais do dry-run (validado que não havia saída não-zero legítima escondida).
10. **Instalador "Claude Code" (Ferramentas IA) estendido**: agora também instala `graphify`, `notebooklm-py`, `obsidian-skills` (via `uv`/`npx`, testado isolado em dry-run) — fecha a paridade que faltava pro repo standalone `claude-code-template` poder ser removido com segurança.
11. **CI verde confirmado**: 2 runs seguidas `success` em ~40-48s cada, após meses de `failure`/`cancelled`.

Repo `claude-code-template` (GitHub, privado): tornou-se redundante após o item 10. Usuário pediu
pra excluir o remoto — se este arquivo estiver sendo lido e o repo ainda existir, completar essa
exclusão (`gh repo delete lucassr-dev/claude-code-template --yes`) é a única pendência desse tópico.

## Pendente — 6 itens da auditoria que o usuário pediu pra atacar (2026-07-19, mensagem mais recente)

Ordem sugerida (mais barato/isolado → mais arriscado/amplo). Marcar aqui conforme for concluindo.

- [x] **1. SSH keys wired up** (commit `d24b873`) — `ask_ssh_keys()` novo (ETAPA 1, só pergunta se
  detectar fonte + terminal interativo), `_resolve_ssh_source()` extraído, wiring em toggle/contagem/
  resumo. Bônus: corrigido bug de segurança lateral (`set_ssh_permissions` não rodava se
  `manage_ssh_keys` "falhasse" no último item do loop — chaves anteriores ficavam 644
  permanentemente) + `chmod 600` imediato por-chave. Testado: dry-run completo, exit 0.
- [ ] **2. Checkpoint/resume não é resume real** — `checkpoint_save`/`checkpoint_load`
  (`lib/checkpoint.sh`) não gravam `SCRIPT_VERSION` nem progresso por-step; resume pula a ETAPA 1
  (perguntas) mas reroda os 13 steps do zero, sem avisar se o checkpoint é de uma versão antiga do
  script. Fix: gravar versão no checkpoint, comparar no load e avisar/invalidar se divergir; avaliar
  se dá pra trackear step-level progress de forma simples sem reescrever tudo.
- [ ] **3. MongoDB no catálogo** — `APP_SOURCES[mongodb]` aponta pra `mongosh` (client) em vez do
  servidor real, sombreando o installer dedicado `install_mongodb_linux()`. Faltam:
  `brew tap mongodb/brew` (macOS) e adicionar o repo oficial `repo.mongodb.org` antes de
  `apt-get install` (Linux moderno removeu `mongodb-org` dos repos padrão pós-SSPL).
- [ ] **4. Cobertura de testes ~15%** — módulos críticos sem nenhum teste BATS: `checkpoint.sh`,
  `fileops.sh`, `selections.sh`, `ui.sh`, `git_config.sh`, `themes.sh`, `install.sh` inteiro (só
  exercitado end-to-end pelo dry-run do CI, fora do BATS). Não dá pra resolver 100% num commit —
  focar pelo menos em `checkpoint.sh` (a lógica de versão do item 2 acima) e `fileops.sh`
  (copy_file/copy_dir, comportamento de backup).
- [ ] **5. Dead code** — `lib/state.sh`: `state_save`/`state_load`/`state_clear`/
  `_state_file_is_secure` nunca chamados em produção (só em `tests/test_state.bats`), duplicam o
  que `checkpoint.sh` já faz (com proteção de arquivo melhor). Decisão a confirmar ao executar:
  remover essas 4 funções + os testes correspondentes + corrigir `docs/ARCHITECTURE.md` (cita
  `state_save`/`state_load` como API oficial, o que não é mais verdade). `lib/ui.sh`: 8 de 9
  componentes (`ui_box`, `ui_badge`, `ui_status`, `ui_progress`, `ui_divider`, `ui_kv`,
  `ui_warning`, `ui_list`) sem nenhum chamador real — mas `docs/ARCHITECTURE.md` cita `ui_box`/
  `ui_progress` como exemplos do módulo. Tratar como possível "biblioteca de componentes para uso
  futuro" em vez de lixo — avaliar item a item antes de remover (risco de destruir infra reusável
  documentada).
- [ ] **6. Emoji conta largura errada** (`_visible_len` em `lib/utils.sh`, via `wc -L`) — subconta
  1 coluna por emoji largo, afetando padding de ~17 chamadas de `show_section_header` (banner.sh)
  que usam emoji no título. Cosmético, baixa prioridade. Fix: detectar emoji via regex/range de
  codepoint e compensar a contagem em vez de confiar cegamente em `wc -L`.

## Como retomar se o contexto for perdido

1. `cd c:\Users\lucas\Downloads\ARK-CLUSTER\dotfiles && git log --oneline -15` — ver o que já foi
   commitado desde `44a83a3` (README curto do shared/claude) em diante.
2. Ler este arquivo inteiro antes de assumir que algo ainda está pendente — a lista de checkbox
   acima é a fonte de verdade, atualizar conforme for concluindo cada item.
3. Rodar `DRY_RUN=1 bash install.sh < /dev/null` localmente antes de qualquer push, igual foi feito
   hoje — pegou o bug real antes do CI.
4. `gh run list --repo lucassr-dev/dotfiles --limit 5` pra confirmar que o CI segue verde depois de
   cada mudança.
