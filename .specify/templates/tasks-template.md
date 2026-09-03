# Tasks: <nome da feature>

> **Spec:** `./spec.md` · **Plan:** `./plan.md`
> **Agente de implementação:** `task-implementer` (`model: sonnet`, `effort: medium`)

<!--
GRANULARIDADE: uma task cabe no contexto de um sonnet sem que ele precise ler o repo
inteiro. Se a task exige entender mais de ~3 arquivos, quebre.

`[P]` = pode rodar em paralelo com outras `[P]` (não compartilha arquivo nem depende delas).

NÃO peça teste automatizado (constitution › o que não exige), salvo se o dono do repo
pedir explicitamente numa task.
-->

## Ordem de execução

<Ex.: T001 → T002 → (T003 [P] ‖ T004 [P]) → T005>

---

### T001 — <título curto e imperativo>

- **Agente:** `task-implementer`
- **Depende de:** <nenhuma | T00X>
- **Paralelizável:** não | `[P]`

**Objetivo:** <uma linha>

**Arquivos:**
- `<caminho>` — <criar | alterar>

**Reuse obrigatoriamente:**
- `<símbolo existente>` em `<caminho>` — não reimplemente

**Não faça:**
- <limites explícitos: não mexa em X, não invente valor de Y, não refatore Z>

**Critério de aceitação:**
- <o que dá para conferir rodando o app ou olhando o diff>

---

### T002 — <...>

<repita o bloco>

---

## Depois de todas as tasks

- [ ] Orquestrador revisa os diffs contra `spec.md`
- [ ] Parâmetros provisórios do `plan.md` estão todos nomeados e rotulados
- [ ] Nenhum `[NEEDS CLARIFICATION]` foi resolvido por invenção
- [ ] Commit sem assinatura de modelo (ver `AGENTS.md` › Convenções de commit)
