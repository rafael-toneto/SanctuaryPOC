# Workflow: implement

Executa as tasks de `specs/NNN-slug/tasks.md`.

**Executado por:** o agente principal **orquestra**; o código é escrito por sub-agente.

## Regra central (Artigo 6)

O orquestrador **não escreve código de feature**. Ele despacha cada task para um
implementador em modelo econômico com raciocínio médio, uma task por vez, e depois revisa.

- **Claude Code** — despache via Agent tool com `subagent_type: "task-implementer"`
  (`sonnet` / `medium`). Tasks marcadas `[P]` podem ir na mesma mensagem.
- **Antigravity** — use o agente `task-implementer` de `.agents/agents/task-implementer/`.
- **Codex** — sem sub-agente. Abra uma sessão separada da de spec com
  `codex -m luna -c model_reasoning_effort=medium` e rode uma task por vez. A revisão volta
  para a sessão orquestradora (`codex -m sol -c model_reasoning_effort=high`).

## Passos

1. Confirme que `tasks.md` está aprovado.
2. Para cada task, na ordem de execução declarada, despache ao sub-agente passando:
   - o caminho de `.specify/constitution.md`, `spec.md` e `plan.md`;
   - **o texto integral da task** — nunca "leia o tasks.md e escolha".
3. Ao voltar, revise o diff contra a task e contra a spec. Procure especificamente:
   - código novo que duplica algo já existente (Artigo 7, degrau 2);
   - valor inventado que deveria ser parâmetro provisório (Artigo 4);
   - escopo além do que a task pedia;
   - teste automatizado que ninguém pediu.
4. Se o diff estiver errado, devolva ao sub-agente com o problema específico. Não conserte
   você mesmo — isso quebra o Artigo 6 e esconde que a task estava mal escrita.
5. Ao fim de todas as tasks, rode a verificação de ponta a ponta descrita no `plan.md`.

## Commit

Um commit por task, ou um commit por feature se as tasks forem pequenas. Mensagem descreve
só a mudança. **Sem `Co-Authored-By`, sem rodapé "Generated with", sem link de sessão**
(ver `AGENTS.md` › Convenções de commit).
