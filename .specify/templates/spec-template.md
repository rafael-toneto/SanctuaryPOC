# Spec: <nome da feature>

> **Status:** rascunho | em revisão | aprovada
> **Criada em:** <AAAA-MM-DD>
> **Aprovada por:** <nome ou "pendente">

<!--
REGRAS DESTE DOCUMENTO (Artigo 2 da constitution):
- Descreve O QUÊ e POR QUÊ. Nunca COMO.
- Proibido nomear linguagem, framework, engine, biblioteca, serviço ou arquivo.
- Se você escreveu "SwiftUI", "SanctuaryStore", "UserDefaults" ou ".swift", está errado.
  Isso pertence ao plan.md.
- Proibido inventar número que decisoes-em-aberto.md deixou aberto (Artigo 4).
-->

## Contexto e problema

<Por que esta feature existe. Qual o problema do jogador ou do projeto. O que muda para
quem joga quando ela existir.>

## Escopo

**Dentro:**
- <...>

**Fora:**
- <o que explicitamente NÃO entra, e por quê — evita expansão silenciosa>

## Regras confirmadas usadas

<Cite as regras da skill `endangered-animal-rescue-game` das quais esta feature depende.
Cite, não parafraseie: parafrasear é como regra vira invenção.>

| Regra | Origem |
| --- | --- |
| <ex.: cada tentativa resolve direto em resgate ou fuga; não há barra de Confiança> | `sistemas-do-jogo.md` › Encontro e resgate |
| <ex.: três famílias de cesta, três níveis cada> | `tabelas-atuais.md` › Cestas por alimentação |

## Decisões em aberto que afetam esta feature

<Consulte `decisoes-em-aberto.md`. Liste tudo que esta feature toca e ainda não foi decidido.
Para cada uma: pergunta ao dono do repo, ou parâmetro provisório nomeado.>

- [ ] `[NEEDS CLARIFICATION: <pergunta específica>]`
      → **Tratamento:** <"perguntar antes de implementar" OU "parâmetro `nomeDoParametro`,
      valor provisório X, rotulado provisório">

## Comportamento esperado

<Descreva o comportamento em prosa ou por cenários. Foco no que o jogador vê e faz.>

### Cenário: <nome>
- **Dado** <estado inicial>
- **Quando** <ação do jogador>
- **Então** <resultado observável>

## Critérios de aceitação

<Cada critério deve ser conferível rodando o app e olhando. NÃO são asserções de teste
automatizado — este projeto não exige testes (ver constitution › o que não exige).>

- [ ] <ex.: escolher uma cesta de família incompatível com a dieta da espécie é impedido,
      com feedback visível de por quê>
- [ ] <...>

## Fora de escopo declarado

<Coisas que alguém razoavelmente esperaria aqui e que ficam para outra spec. Nomeie a spec
futura se souber.>
