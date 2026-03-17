# Plano de Auditoria — config dotfiles
> Criado: 2026-03-17 | Status: em execução

## Contexto

Auditoria completa do projeto dotfiles cobrindo: layout/UI, fluxo de instalação,
plataformas, código morto, configs e arquitetura. Implementar todos os problemas
encontrados, do crítico ao menor.

## Referências

- Relatório completo: ver contexto da sessão 2026-03-17
- Arquivo principal: `install.sh` (~2900 linhas)
- Libs: `lib/` (21 módulos)
- Dados: `data/apps.sh`, `data/runtimes.sh`
- Testes: `tests/` (BATS)

---

## FASE 1 — Código Morto ✅ / ⏳ / ❌

Arquivos: `install.sh`

| # | Item | Arquivo:Linha | Status |
|---|------|---------------|--------|
| 1.1 | Remover variável `FAIL_FAST` | install.sh:26 | ⏳ |
| 1.2 | Remover função `_join_items()` | install.sh:995 | ⏳ |
| 1.3 | Remover função `_truncate_text()` | install.sh:1006 | ⏳ |
| 1.4 | Remover função `_truncate_items()` | install.sh:1025 | ⏳ |
| 1.5 | Remover `SCRIPT_VERSION` não usada | install.sh:28 | ⏳ |
| 1.6 | Limpar comentários antigos de refatoração | install.sh:2753-2765 | ⏳ |

---

## FASE 2 — Bugs de Correctness ⏳

| # | Item | Arquivo:Linha | Detalhe | Status |
|---|------|---------------|---------|--------|
| 2.1 | Guard TARGET_OS em dpkg/rpm | install.sh:309-310 | is_app_installed() usa dpkg/rpm sem verificar se é Linux | ⏳ |
| 2.2 | Verificar retorno backup_if_exists | fileops.sh:74 | copy_file() ignora retorno — perda de dado se backup falha | ⏳ |
| 2.3 | Remover reset LINUX_PKG_UPDATED em install_gum_fallback | os_linux.sh:226 | Força apt-get update repetido sem necessidade | ⏳ |
| 2.4 | Remover reset LINUX_PKG_UPDATED em install_wezterm_linux | os_linux.sh:453 | Mesma causa | ⏳ |
| 2.5 | record_failure() deve retornar 1 | install.sh:236-251 | Chamadores não sabem que falhou | ⏳ |
| 2.6 | VSCode extensions: verificar se code está instalado | install.sh:~3075 | Tenta instalar extensions mesmo se VSCode não foi instalado | ⏳ |

---

## FASE 3 — Layout e UI ⏳

| # | Item | Arquivo:Linha | Detalhe | Status |
|---|------|---------------|---------|--------|
| 3.1 | ui_box: ${#title} → _visible_len | components.sh:20 | ANSI codes inflam ${#} → padding errado | ⏳ |
| 3.2 | ui_section: ${#title} → _visible_len | components.sh:49 | Mesmo problema | ⏳ |
| 3.3 | _rpt_section_header: ${#title} → _visible_len | report.sh:55 | Mesmo problema | ⏳ |
| 3.4 | _rpt_dual_header/_rpt_dual_divider: ${#} → _visible_len | report.sh:63,73 | Mesmo problema | ⏳ |
| 3.5 | Consolidar _visual_width → _visible_len em banner.sh | banner.sh:155-163 | Duplicação com suporte diferente a emojis | ⏳ |
| 3.6 | _visible_len: adicionar suporte a emojis | utils.sh | Unificar lógica emoji no único lugar | ⏳ |
| 3.7 | ui_box: adicionar largura mínima (40) | components.sh | Sem guard → explode em terminais estreitos | ⏳ |
| 3.8 | _wrap_text: usar _visible_len ao invés de ${#word} | utils.sh:20-42 | ANSI codes quebram word wrap | ⏳ |
| 3.9 | banner.sh: padronizar sed -E em todas chamadas | banner.sh:42 | Sem -E pode não funcionar em POSIX sed | ⏳ |
| 3.10 | banner.sh: truncamento ANSI-safe | banner.sh:179-182 | ${title_text:0:n} corta no meio de escape codes | ⏳ |

---

## FASE 4 — Sincronização de Catálogos ⏳

| # | Item | Arquivo | Detalhe | Status |
|---|------|---------|---------|--------|
| 4.1 | Adicionar btop a CLI_TOOLS | data/apps.sh | Existe em APP_SOURCES mas não aparece no menu | ⏳ |
| 4.2 | Adicionar mise a CLI_TOOLS | data/apps.sh | Existe em APP_SOURCES mas não aparece no menu | ⏳ |

---

## FASE 5 — Lógica de Config por App ⏳

Design: quando o usuário seleciona um app/ferramenta que tem config disponível
no repositório, perguntar: "Config disponível para [app] — copiar do repo (C)
ou instalação limpa (I)?"

Implementação:
| # | Item | Arquivo | Status |
|---|------|---------|--------|
| 5.1 | Mapear apps → configs disponíveis no repo | install.sh ou lib/selections.sh | ⏳ |
| 5.2 | Implementar função ask_config_preference(app) | lib/selections.sh ou fileops.sh | ⏳ |
| 5.3 | Integrar chamada na seleção de CLI tools | lib/selections.sh | ⏳ |
| 5.4 | Integrar chamada na seleção de IDEs | lib/selections.sh | ⏳ |
| 5.5 | Integrar chamada na seleção de terminais | lib/selections.sh | ⏳ |
| 5.6 | Respeitar preferência ao copiar configs | lib/fileops.sh / install.sh | ⏳ |
| 5.7 | Corrigir backup_if_exists em modo sync | fileops.sh | ⏳ |

---

## FASE 6 — Validação e Publicação ⏳

| # | Item | Status |
|---|------|--------|
| 6.1 | bash -n em todos arquivos modificados | ⏳ |
| 6.2 | bats tests/ — todos devem passar | ⏳ |
| 6.3 | DRY_RUN=1 bash install.sh (smoke test) | ⏳ |
| 6.4 | Commit descritivo | ⏳ |
| 6.5 | Push repo privado | ⏳ |
| 6.6 | Sync + push repo público | ⏳ |

---

## Notas de implementação

- Sempre rodar `bash -n` após cada fase
- Não alterar a API pública das funções (nomes, parâmetros) — só comportamento interno
- record_failure() retornar 1: verificar chamadores para não quebrar lógica existente
- _visible_len já existe em utils.sh — apenas referenciar, não duplicar
- Para _wrap_text com ANSI: usar _strip_ansi para medir, mas preservar original para output
- Para truncamento ANSI-safe no banner: extrair texto visível, truncar, reaplicar cor
