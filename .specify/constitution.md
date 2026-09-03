# Constitution

Regras invioláveis deste projeto. Valem para qualquer pessoa e qualquer modelo de IA
trabalhando no repo — Claude, Codex, Antigravity ou outro.

Quando um pedido do dono do repo conflitar com um artigo, o pedido vence e o artigo
deve ser atualizado no mesmo commit. Um agente nunca resolve o conflito em silêncio.

---

## Artigo 1 — Spec antes de código

Nenhuma implementação começa sem uma `spec.md` aprovada pelo dono do repo.

O fluxo é `/specify` → `/plan` → `/tasks` → `/implement`. Pular uma etapa não é permitido.

Única exceção: correção trivial de bug ou typo que não muda comportamento especificado.

## Artigo 2 — WHAT e HOW são documentos diferentes

`spec.md` descreve **o quê** e **por quê**. Não nomeia linguagem, framework, biblioteca,
engine, serviço nem arquivo. Uma spec deve continuar válida se o projeto trocar de stack.

`plan.md` descreve **como**. É o único documento onde a stack é escolhida, e o único lugar
onde a POC SwiftUI atual pode ser citada como base, referência ou código a reusar.

Consequência prática: uma spec que menciona `SwiftUI`, `SanctuaryStore` ou `.swift` está
errada e deve voltar para revisão.

## Artigo 3 — O canon vem da skill, não da concept art

A fonte de verdade do design é a skill `endangered-animal-rescue-game` e suas referências
(`sistemas-do-jogo.md`, `tabelas-atuais.md`, `direcao-visual.md`, `decisoes-em-aberto.md`).

Concept art orienta atmosfera e composição — nunca lógica. Especificamente **não existem no
jogo**, apesar de aparecerem nas imagens:

- a barra de `Confiança` e seus três segmentos;
- a obrigação de acumular acertos antes de resgatar;
- a seleção de frutos individuais no rodapé do encontro;
- folha, gota e moeda como três recursos econômicos separados.

Nomes das tabelas atuais (cestas, trilhas de upgrade por bioma, upgrades do jogador) não
podem ser trocados por um agente. Refinar nome é decisão do dono do repo.

## Artigo 4 — Decisão em aberto nunca vira invenção

`decisoes-em-aberto.md` lista o que ainda não foi decidido: fórmula de chance de resgate,
preços das cestas, capacidade-base definitiva, curvas de custo, valor por passo, matriz de
compatibilidade espécie×bioma, fontes de XP, catálogo de espécies e outros.

Ao esbarrar em um desses itens:

1. Se a decisão **muda materialmente** o resultado — pergunte ao dono do repo.
2. Se **não muda** — crie um parâmetro nomeado, rotule o valor como `provisório` e siga.

Em qualquer dos casos, registre na spec:

```
[NEEDS CLARIFICATION: fórmula exata da chance de resgate — usando placeholder
chanceFinal = clamp(base × cesta × precisão × upgrades, min, max)]
```

Escolher um número em silêncio e apresentá-lo como regra do jogo é a violação mais grave
desta constitution.

Separe sempre, e rotule explicitamente: `regra confirmada`, `valor provisório`, `proposta`,
`decisão em aberto`.

## Artigo 5 — Regras em dados, separadas da apresentação

Espécies, categorias de cesta, probabilidades, biomas, raridades, níveis de upgrade e curvas
de custo vivem em dados ou configuração — nunca embutidos na lógica nem na UI.

A lógica de regras deve ser exercitável sem renderer. A POC estabeleceu esse padrão com
`BalanceConfig` (todos os números provisórios num só lugar) e `ProductionEngine` (funções
puras); qualquer implementação nova segue o mesmo princípio, na stack que for.

## Artigo 6 — Implementação é do sub-agente

O agente principal **orquestra**: escreve `spec.md`, `plan.md` e `tasks.md`, revisa os diffs
e integra. Ele não escreve código de feature.

Código de feature é escrito por um modelo econômico com raciocínio **médio**, uma task por
vez. O orquestrador roda no modelo mais capaz com raciocínio **alto**.

| Ferramenta | Orquestrador | Implementador |
| --- | --- | --- |
| Claude Code | `opus` / `high` | `sonnet` / `medium` |
| Codex | `sol` / `high` | `luna` / `medium` |
| Antigravity | mais capaz da versão | econômico da versão |

- **Claude Code** — `.claude/agents/task-implementer.md` aplica por configuração.
- **Antigravity** — `.agents/agents/task-implementer/agent.md` aplica por configuração.
- **Codex** — não tem configuração de sub-agente. Lá o artigo é aplicado por sessão:
  `codex -m sol -c model_reasoning_effort=high` para spec/plan/tasks e revisão,
  `codex -m luna -c model_reasoning_effort=medium` para implementar, e as duas sessões
  ficam separadas.

## Artigo 7 — Simplicidade obrigatória

Pare no primeiro degrau que resolver:

1. isso precisa existir? Necessidade especulativa = não construa;
2. já existe no repo? Reuse;
3. a biblioteca padrão resolve? Use;
4. um recurso nativo da plataforma resolve? Use;
5. uma dependência já instalada resolve? Use;
6. cabe em uma linha? Uma linha;
7. só então: o mínimo que funciona.

Sem abstração especulativa: nada de interface com uma implementação, factory para um
produto, ou config para um valor que nunca muda. Deletar vence adicionar.

Atalho deliberado com teto conhecido leva comentário nomeando o teto e o caminho de upgrade:

```
// ponytail: busca linear no catálogo; indexar se passar de ~200 espécies
```

**Nunca simplifique fora:** validação de entrada em fronteira de confiança, tratamento de
erro que evita perda de dado, segurança, acessibilidade básica, ou qualquer coisa pedida
explicitamente.

---

## O que esta constitution deliberadamente NÃO exige

**Testes.** Nenhum artigo exige teste unitário ou de UI. Templates e tasks não pedem
cobertura. A verificação de uma task é um **critério de aceitação observável** — algo que se
confere rodando o app. Testes automatizados só entram quando o dono do repo pedir
explicitamente numa task.

A suíte existente em `SantuarioPOCTests/` é anterior a esta decisão. Não a remova; apenas
não exija novos testes por padrão.

**Assinatura de modelo em commits.** Ver `AGENTS.md` › Convenções de commit.
