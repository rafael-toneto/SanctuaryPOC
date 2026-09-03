# Workflow: specify

Cria `specs/NNN-slug/spec.md` a partir de uma descrição de feature.

**Executado por:** o agente principal (orquestrador). Não delegue.

## Passos

1. Leia `.specify/constitution.md` inteira.
2. Leia o canon relevante da skill `endangered-animal-rescue-game`:
   - sempre `sistemas-do-jogo.md` e `decisoes-em-aberto.md`;
   - `tabelas-atuais.md` se a feature toca cestas, biomas, terrenos ou upgrades;
   - `direcao-visual.md` se a feature tem tela.
3. Determine o próximo número: olhe `specs/` e use o maior `NNN` + 1, começando em `001`.
   Slug em kebab-case, curto, em português. Ex.: `specs/001-encontro-e-resgate/`.
4. Copie `.specify/templates/spec-template.md` para `specs/NNN-slug/spec.md` e preencha.
5. Passe a spec pelos quatro filtros abaixo antes de entregar.
6. Apresente ao dono do repo o resumo e **a lista de `[NEEDS CLARIFICATION]`**. Pare aí.
   Não siga para `/plan` sem aprovação.

## Filtros obrigatórios antes de entregar

- **Sem tecnologia** (Artigo 2). Procure por nome de linguagem, framework, arquivo ou
  símbolo de código. Se achar, mova para o futuro `plan.md` e reescreva a frase.
- **Sem invenção** (Artigo 4). Todo número, porcentagem, custo ou fórmula que não venha de
  uma regra confirmada precisa estar marcado `[NEEDS CLARIFICATION]` ou rotulado
  `provisório` com nome de parâmetro.
- **Sem concept art como regra** (Artigo 3). Nada de barra de Confiança, segmentos, frutos
  individuais ou três moedas.
- **Sem exigência de teste.** Critérios de aceitação são observáveis rodando o app.

## Quando perguntar em vez de parametrizar

Pergunte ao dono do repo quando a decisão em aberto **muda materialmente** o resultado —
ex.: se a cesta é consumida em toda tentativa, se a falha sempre causa fuga, se o bioma é
escolhido ou fixo na compra do terreno. Caso contrário, parametrize e siga.
