# Workflow: plan

Cria `specs/NNN-slug/plan.md` a partir de uma spec **aprovada**.

**Executado por:** o agente principal (orquestrador). Não delegue.

## Pré-condição

`spec.md` está aprovada e não tem `[NEEDS CLARIFICATION]` bloqueante em aberto. Marcador que
virou parâmetro provisório documentado pode seguir; marcador que exige decisão do dono do
repo, não.

## Passos

1. Leia `.specify/constitution.md`, a `spec.md` da feature e `AGENTS.md`.
2. Inspecione o código existente **antes** de projetar qualquer coisa. No mínimo:
   - `SantuarioPOC/Models/SanctuaryModels.swift` — `Biome`, `Terrain`, `AnimalInstance`,
     `BalanceConfig`, `ProductionEngine`, `TerrainUpgradeTrack`;
   - `SantuarioPOC/Store/SanctuaryStore.swift` — padrão de ação retornando
     `Result<_, SanctuaryActionError>`;
   - as views relevantes em `SantuarioPOC/Views/`.
3. Copie `.specify/templates/plan-template.md` para `specs/NNN-slug/plan.md` e preencha.
4. A **seção de reuso é obrigatória** e vem antes de projetar código novo (Artigo 7,
   degrau 2). Não reusar algo óbvio exige justificativa escrita.
5. Liste todo parâmetro provisório introduzido, com a decisão em aberto correspondente.
6. Apresente ao dono do repo. Pare. Não siga para `/tasks` sem aprovação.

## Lembretes

- Este é o único documento onde a stack aparece. Se a POC vai ser a base, diga aqui.
- Valores ajustáveis vão para configuração, não para a lógica (Artigo 5).
- Não projete abstração para necessidade especulativa (Artigo 7).
