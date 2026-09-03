# Plan: <nome da feature>

> **Spec:** `./spec.md`
> **Status:** rascunho | aprovado

<!--
Este é o único documento onde a stack é escolhida (Artigo 2) e o único onde a POC atual
pode ser citada como base ou código a reusar.
-->

## Stack escolhida para esta feature

| Item | Escolha | Por quê |
| --- | --- | --- |
| Linguagem / plataforma | <...> | <...> |
| Renderer / UI | <...> | <...> |
| Persistência | <...> | <...> |

<Se esta feature roda sobre a POC existente, diga aqui. Se é código novo em outro lugar,
diga aqui. A spec não sabe disso.>

## Reuso (seção obrigatória — Artigo 7, degrau 2)

<Antes de escrever qualquer coisa nova, liste o que já existe e será aproveitado. Se algo
óbvio NÃO for reusado, justifique — essa justificativa é o ponto da seção.>

| Já existe | Onde | Uso nesta feature |
| --- | --- | --- |
| `SanctuaryStore` | `SantuarioPOC/Store/SanctuaryStore.swift` | <reusar / não reusar porque...> |
| `BalanceConfig` | `SantuarioPOC/Models/SanctuaryModels.swift` | <...> |
| `ProductionEngine` | `SantuarioPOC/Models/SanctuaryModels.swift` | <...> |
| `AnimalInstance`, `Terrain`, `Biome` | `SantuarioPOC/Models/SanctuaryModels.swift` | <...> |
| <outro padrão do repo> | <...> | <...> |

**Nada novo será criado para:** <liste, se aplicável>

## Arquitetura

<Fluxo de dados e onde cada responsabilidade mora. Diagrama se ajudar.>

**Onde ficam os valores ajustáveis** (Artigo 5): <ex.: estendendo `BalanceConfig` com os
campos X, Y, Z — todos rotulados provisórios>

## Arquivos tocados

| Arquivo | Novo/alterado | O que muda |
| --- | --- | --- |
| <...> | <...> | <...> |

## Parâmetros provisórios introduzidos

<Todo valor que veio de uma decisão em aberto. Nome, valor de partida, e o que ele
representa. Isso vira a lista de coisas a revisitar quando o dono do repo decidir.>

| Parâmetro | Valor provisório | Decisão em aberto correspondente |
| --- | --- | --- |
| <...> | <...> | <...> |

## Riscos

- <o que pode dar errado, e o sinal de alerta>

## Como verificar de ponta a ponta

<Passos concretos para rodar e conferir que a feature funciona. Comandos, telas, ações.
Critério de aceitação observável, não suíte de teste.>

1. <...>
