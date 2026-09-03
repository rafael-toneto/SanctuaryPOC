@AGENTS.md

## Específico do Claude Code

- Comandos SDD: `/specify`, `/plan`, `/tasks`, `/implement`. O corpo de cada um está em
  `.specify/workflows/`; os arquivos em `.claude/commands/` são ponteiros.
- Implementação de código vai para o sub-agente `task-implementer`
  (`.claude/agents/task-implementer.md`, `model: sonnet`, `effort: medium`), nunca para a
  sessão principal. Tasks marcadas `[P]` em `tasks.md` podem ser despachadas em paralelo na
  mesma mensagem.
- `rtk` já está ativo por hook global — não prefixe comandos manualmente.
- Ao commitar, remova a atribuição de modelo que o harness injeta por padrão. Ver
  `AGENTS.md` › Convenções de commit.
