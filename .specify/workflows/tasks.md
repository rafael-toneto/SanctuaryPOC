# Workflow: tasks

Quebra um `plan.md` aprovado em `specs/NNN-slug/tasks.md`.

**Executado por:** o agente principal (orquestrador). Não delegue.

## Passos

1. Leia `.specify/constitution.md`, `spec.md` e `plan.md` da feature.
2. Copie `.specify/templates/tasks-template.md` para `specs/NNN-slug/tasks.md`.
3. Quebre o plan em tasks numeradas `T001`, `T002`, …

## Regra de granularidade

Uma task deve caber no contexto de um sonnet **sem que ele precise ler o repo inteiro**.
Se executar a task exige entender mais de ~3 arquivos, quebre em duas.

Cada task carrega tudo que o implementador precisa saber:

- objetivo em uma linha;
- caminhos exatos dos arquivos;
- o que reusar, citado por nome e caminho — o sub-agente não vai adivinhar;
- **o que não fazer** — limites explícitos evitam expansão de escopo;
- critério de aceitação observável.

## Paralelismo

Marque `[P]` só quando a task não compartilha arquivo com outra `[P]` e não depende dela.
Duas tasks `[P]` que editam o mesmo arquivo vão conflitar.

## Proibições

- Nenhuma task pede teste unitário ou de UI, salvo pedido explícito do dono do repo.
- Nenhuma task pede ao implementador que decida um valor em aberto. Se o valor ainda não
  existe, ou o plan já o definiu como provisório, ou a task não está pronta.
- Nenhuma task manda "refatorar o que achar melhor". Escopo vago vira diff grande.
