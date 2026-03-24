# Plano de Auditoria — config dotfiles
> Criado: 2026-03-17 | Concluído: 2026-03-24

## Contexto

Auditoria completa do projeto dotfiles cobrindo: layout/UI, fluxo de instalação,
plataformas, código morto, configs e arquitetura. Implementar todos os problemas
encontrados, do crítico ao menor.

## Referências

- Arquivo principal: `install.sh` (~2800 linhas)
- Libs: `lib/` (21 módulos)
- Dados: `data/apps.sh`, `data/runtimes.sh`
- Testes: `tests/` (BATS)

---

## FASE 1 — Código Morto ✅

Arquivos: `install.sh`

| # | Item | Status | Nota |
|---|------|--------|------|
| 1.1 | `FAIL_FAST` | ❌ Não é dead code | Usado em `record_failure()` — controla saída em erro crítico |
| 1.2 | `_join_items()` | ❌ Não é dead code | Ainda usada na linha 1291 para formatar ações |
| 1.3 | `_truncate_text()` | ✅ Removida | Só era chamada por `_truncate_items` (dead code transitivo) |
| 1.4 | `_truncate_items()` | ✅ Removida | Nunca chamada — dead code real |
| 1.5 | `SCRIPT_VERSION` | ❌ Não é dead code | Usada nas linhas 110, 118 para display de versão |
| 1.6 | Comentários antigos | ✅ Já limpo | Nenhum TODO/FIXME/legado encontrado |

---

## FASE 2 — Bugs de Correctness ✅

| # | Item | Status | Como foi corrigido |
|---|------|--------|-------------------|
| 2.1 | Guard TARGET_OS em dpkg/rpm | ✅ | `if [[ "${TARGET_OS:-}" == "linux" \|\| "wsl2" ]]` adicionado |
| 2.2 | Retorno backup_if_exists | ✅ | `backup_if_exists "$dest" \|\| return 1` em copy_file/copy_dir |
| 2.3 | Reset LINUX_PKG_UPDATED (gum) | ✅ | Reset removido de install_gum_fallback |
| 2.4 | Reset LINUX_PKG_UPDATED (wezterm) | ✅ | Reset removido de install_wezterm_linux |
| 2.5 | record_failure() return 1 | ✅ | `return 1` adicionado na linha 252 |
| 2.6 | VSCode extensions guard | ✅ | Verifica `COPY_VSCODE_SETTINGS` + `has_cmd code` antes de instalar |

---

## FASE 3 — Layout e UI ✅

| # | Item | Status | Como foi corrigido |
|---|------|--------|-------------------|
| 3.1 | ui_box: `${#title}` → `_visible_len` | ✅ | components.sh:22 |
| 3.2 | ui_section: `${#title}` → `_visible_len` | ✅ | components.sh:52 |
| 3.3 | `_rpt_section_header`: `${#}` → `_visible_len` | ✅ | report.sh:56 |
| 3.4 | `_rpt_dual_header/_rpt_dual_divider` | ✅ | report.sh:64-65, 73-74 |
| 3.5 | Consolidar `_visual_width` → `_visible_len` | ✅ | `_visual_width` removida de banner.sh |
| 3.6 | `_visible_len` emoji support | ✅ | Fallback com contagem de emoji em utils.sh |
| 3.7 | ui_box largura mínima | ✅ | components.sh:18: `[[ $width -lt 42 ]] && width=42` |
| 3.8 | `_wrap_text` usa `_visible_len` | ✅ | utils.sh:52-53 |
| 3.9 | banner.sh `sed -E` | ✅ | Única chamada sed já usa `-E` (linha 42) |
| 3.10 | banner.sh truncamento ANSI-safe | ✅ | `_strip_ansi` + recalculo com `_visible_len` (linhas 169-176) |

**Extra**: `_strip_ansi` corrigido para tratar literal `\033`/`\e` além de byte ESC `\x1b` (utils.sh:11)

---

## FASE 4 — Sincronização de Catálogos ✅

| # | Item | Status |
|---|------|--------|
| 4.1 | btop em CLI_TOOLS | ✅ data/apps.sh:14 |
| 4.2 | mise em CLI_TOOLS | ✅ data/apps.sh:24 |

---

## FASE 5 — Lógica de Config por App ✅

Implementação via `ask_configs_to_copy()` (install.sh):
- Reseta todos COPY_* para 0
- Mostra apenas configs de tools selecionadas + verifica existência no repo
- Usuário escolhe via multi-select (fzf/gum/bash fallback)
- RESUMO FINAL mostra ✓/✗ e permite toggle via opção 0
- `apply_shared_configs()` respeita flags antes de copiar

| # | Item | Status | Nota |
|---|------|--------|------|
| 5.1 | Mapear apps → configs | ✅ | `ask_configs_to_copy` verifica seleções + existência de arquivos |
| 5.2 | Função de preferência | ✅ | Multi-select em `ask_configs_to_copy` |
| 5.3 | Integrar em CLI tools | ✅ | Chamada em linha 2939 + opção 0 do RESUMO FINAL |
| 5.4 | Integrar em IDEs | ✅ | Verifica `SELECTED_IDES` na mesma função |
| 5.5 | Integrar em terminais | ✅ | Verifica `SELECTED_TERMINALS` na mesma função |
| 5.6 | Respeitar preferência | ✅ | `apply_shared_configs` checa cada COPY_* flag |
| 5.7 | backup_if_exists sync | ✅ | `|| return 1` já implementado (= 2.2) |

**Extra**: Todos COPY_* defaults alterados para 0 (opt-in explícito)

---

## FASE 6 — Validação ✅

| # | Item | Status |
|---|------|--------|
| 6.1 | `bash -n` em todos os arquivos | ✅ Sem erros |
| 6.2 | `bats tests/` — 18/18 passando | ✅ |
| 6.3 | DRY_RUN smoke test | ⏳ (requer terminal interativo) |
| 6.4 | Commit descritivo | ✅ |
| 6.5 | Push repo privado | ⏳ (aguardando usuário) |
| 6.6 | Sync + push repo público | ⏳ (aguardando usuário) |
