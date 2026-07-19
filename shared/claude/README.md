# Claude Code — config compartilhada

CLAUDE.md, RTK.md, skill `impeccable`, `settings.fragment.json` + `merge-settings.mjs`.

Aplicado por `_apply_claude_config()` em `install.sh` (caso especial, não usa a tabela genérica
`SHARED_COPY_OPS` — settings.json precisa de merge, não cópia por cima, pra não perder secrets/
estado por-máquina).

Origem/detalhe completo (incluindo achados de pesquisa 2026 sobre práticas modernas do Claude
Code — `--safe-mode`, `.mcp.json` com env-var expansion, memória por-subagent): repo irmão
`github.com/lucassr-dev/claude-code-template`.

## Atualizar

Se mudar plugins/hooks/CLAUDE.md global na máquina principal, rode `bash install.sh export` (ou
copie os arquivos a mão) pra trazer as mudanças de volta pra este diretório antes de propagar pras
outras máquinas.
