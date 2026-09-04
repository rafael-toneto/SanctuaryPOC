# Plan: Minigame de resgate

> **Spec:** `./spec.md`
> **Status:** aprovado

## Stack escolhida para esta feature

| Item | Escolha | Por quê |
| --- | --- | --- |
| Linguagem / plataforma | Swift 5.9+, iOS 17+ | É a stack da POC existente. A feature vive dentro dela. |
| Renderer / UI | SwiftUI puro, sem dependência nova | O gesto de puxar-e-soltar é `DragGesture` + animação; SwiftUI resolve. Física de projétil real não é necessária — a trajetória é decorativa, quem decide o resultado é o ponto de pouso. |
| Persistência | **Nenhuma** | A spec exclui salvar o animal resgatado. Sem `UserDefaults`, sem estado no `SanctuaryState`. Fechar a tela apaga tudo. |
| Integração no projeto | Arquivos novos em `SantuarioPOC/` | O `.xcodeproj` usa `PBXFileSystemSynchronizedRootGroup` (`objectVersion = 77`): arquivo novo na pasta entra no target sozinho, sem editar `project.pbxproj`. |

O minigame **roda sobre a POC existente**, mas é uma ilha: alcançado a partir de
`SanctuaryView`, não lê nem escreve o estado do santuário. Quando a integração for
especificada, o ponto de costura é um único: o desfecho `resgatado`.

## Reuso (seção obrigatória — Artigo 7, degrau 2)

| Já existe | Onde | Uso nesta feature |
| --- | --- | --- |
| `SanctuaryTheme` | `Views/Components.swift` | **Reusar.** Paleta inteira. Nenhuma cor nova. |
| `SoftActionButtonStyle`, `FilledActionButtonStyle` | `Views/Components.swift` | **Reusar** no botão `Resgate` e nas ações da tela de encontro. |
| `SanctuaryBackdrop` | `Views/Components.swift` | **Reusar** como fundo do encontro. A concept art pede um ambiente pintado; ilustração de bioma é acabamento, e a spec põe arte final fora de escopo. |
| `SanctuaryHaptics` | `Views/Components.swift` | **Reusar** — `.success()` no resgate, `.selection()` na troca de cesta. |
| `NoticeBanner` + `SanctuaryNotice` | `Views/Components.swift`, `Store/SanctuaryStore.swift` | **Reusar o componente visual**, construindo um `SanctuaryNotice` local. Não reusar o `store.notice`: o banner do santuário é publicado pelo `SanctuaryStore`, e o encontro não tem store. |
| Padrão `bottomBar` com fallback de Dynamic Type | `Views/SanctuaryView.swift` | **Reusar.** O terceiro botão entra no mesmo `HStack`/`VStack` acessível já existente. |
| `SanctuaryStore` | `Store/SanctuaryStore.swift` | **Não reusar.** Nada do encontro é persistido nem afeta carteira, terrenos ou acolhimento. Injetar o store só para não usá-lo seria acoplamento sem função. |
| `BalanceConfig` | `Models/SanctuaryModels.swift` | **Não estender.** É `let` em toda propriedade e injetado no `init` do store — não dá para ajustar em tempo de execução, e a spec exige ajuste pelo laboratório. Entra um `RescueBalance` novo, seguindo o **mesmo princípio** do Artigo 5: todos os números provisórios num único lugar. |
| `SpeciesDefinition` / `DemoSpecies` | `Models/SanctuaryModels.swift` | **Não reusar.** Exige `principalBiome` e `baseYield` de cada espécie; preencher isso para 61 espécies significaria inventar a matriz espécie×bioma e a produção por espécie, ambas decisões em aberto (Artigo 4). O catálogo do resgate carrega só o que o resgate usa: nome, raridade, família de cesta, emoji. As 5 espécies do santuário continuam com seu catálogo próprio — sobreposição de nome sem sobreposição de dado. |
| `ProductionEngine` | `Models/SanctuaryModels.swift` | **Não reusar** (economia idle, assunto diferente), mas **copiar o formato**: `enum` de funções puras, sem estado, exercitável sem renderer. |
| `POCLabView` | `Views/AuxiliarySheets.swift` | **Não reusar a tela**, que é toda `store`. Reusar o **padrão**: `Form` em `NavigationStack`, aviso de "isto não é o jogo final" no topo. |

**Nada novo será criado para:** cores, tipografia, estilos de botão, hápticos, banner de aviso,
fundo, ou qualquer entrada no `project.pbxproj`.

## Arquitetura

Três camadas, espelhando o que a POC já faz:

```
RescueModels.swift  (regras puras, zero SwiftUI)
   BasketFamily · BasketTier · Rarity · RescueSpecies · RescueCatalog
   RescueBalance   → todos os números provisórios
   RescueEngine    → funções puras, RNG injetável

RescueView.swift    (tela)
   Encounter        → struct em @State: espécie sorteada, estoque, família
                      selecionada, nível selecionado, desfecho
   gesto            → DragGesture no estilingue → ponto de pouso → RescueEngine
   RescueLabSheet   → edita o RescueBalance em tempo de execução

SanctuaryView.swift (alterado)
   botão "Resgate" na bottomBar → fullScreenCover(RescueView)
```

**Fluxo de uma tentativa:**

1. O jogador arrasta o estilingue. O vetor de puxada, espelhado e multiplicado por
   `throwSensitivity`, dá o **ponto de pouso** na tela.
2. A cesta anima até esse ponto (`throwDuration`). A animação é decorativa; o resultado já
   está determinado pelo ponto.
3. `RescueEngine.precision(landing:target:balance:)` classifica: dentro do núcleo, dentro do
   anel, ou fora.
4. `RescueEngine.rescueChance(species:tier:precision:balance:)` aplica
   `clamp(baseRaridade × multCesta × multPrecisao × multUpgrades, mín, máx)`.
   `multUpgrades` é uma constante 1 nesta POC, com a assinatura já pronta para receber
   `Instinto de Resgate` e `Especialista em Raridades`.
5. Fora da área → falha sem sortear resgate; a cesta é consumida do mesmo jeito.
6. Falha → `RescueEngine.flees(rarity:balance:)`. Fugiu, o encontro acaba.
7. Estoque zerado em todas as cestas compatíveis → encontro acaba por falta de cesta.

**Bloqueio por dieta:** o rodapé mostra as três famílias. Tocar numa incompatível não
seleciona — mostra a mensagem nomeando a dieta da espécie e não consome nada. O impedimento
mora no `RescueEngine` (`isCompatible`), não na view.

**Alvo:** um anel elíptico no chão sob o animal, com núcleo concêntrico. Raio do anel =
`hitRadiusBase × (1 + nível de Mão Firme × hitRadiusPerLevel)`; núcleo = `coreRadiusRatio` do
anel. Como não há upgrades adquiríveis, o nível fica em 1 e só o laboratório o move — é assim
que o critério "começa pequena e cresce com upgrades" fica conferível hoje.

**Onde ficam os valores ajustáveis** (Artigo 5): todos em `RescueBalance`, um `struct` com
propriedades `var` e um `static let poc` de partida. A view guarda uma instância em `@State`;
o laboratório do resgate edita essa instância e o efeito aparece na tentativa seguinte.
Nenhum número solto na view nem no engine.

**RNG:** `RescueEngine` recebe `inout some RandomNumberGenerator`, com
`SystemRandomNumberGenerator` como padrão na chamada da view. Isso mantém a regra exercitável
sem renderer (Artigo 5) e permite semear o sorteio se algum dia for preciso conferir uma
distribuição.

**Arte do animal:** emoji grande, como `DemoSpecies` já faz com `symbol`. Ilustração por
espécie é acabamento, e a spec o coloca fora de escopo.

## Arquivos tocados

| Arquivo | Novo/alterado | O que muda |
| --- | --- | --- |
| `SantuarioPOC/Models/RescueModels.swift` | **novo** | `Rarity`, `BasketFamily`, `BasketTier`, `RescueSpecies`, `RescueCatalog` (61 espécies), `RescueBalance`, `RescueEngine`. Sem SwiftUI. |
| `SantuarioPOC/Views/RescueView.swift` | **novo** | Tela de encontro: fundo, animal, alvo, estilingue com gesto, rodapé de cestas, mensagens de desfecho, botão de próximo animal, e o `RescueLabSheet`. |
| `SantuarioPOC/Views/SanctuaryView.swift` | alterado | Um botão `Resgate` na `bottomBar`, ao lado de `Acolhimento` e `Demo`, e o `fullScreenCover` que abre o encontro. |

Três arquivos. Nenhum outro.

## Parâmetros provisórios introduzidos

Todos vivem em `RescueBalance` e todos são editáveis no laboratório do resgate.

| Parâmetro | Valor provisório | Decisão em aberto correspondente |
| --- | --- | --- |
| `baseChance[.s/.a/.b/.c/.d]` | 0,05 / 0,10 / 0,18 / 0,30 / 0,45 | fórmula e influência da raridade |
| `tierMultiplier[1/2/3]` | 1,0 / 1,5 / 2,2 | influência numérica da cesta |
| `precisionMultiplier[núcleo/anel]` | 1,8 / 1,0 | influência numérica da precisão |
| `upgradeMultiplier` | 1,0 (fixo) | valores de `Instinto de Resgate` e `Especialista em Raridades` |
| `minChance` / `maxChance` | 0,03 / 0,90 | limites da fórmula |
| `fleeChance[.s/.a/.b/.c/.d]` | 0,35 / 0,28 / 0,20 / 0,14 / 0,08 | se a falha causa fuga, e com que peso |
| `startingStock[1/2/3]` | 5 / 3 / 2 | número de tentativas por encontro |
| `hitRadiusBase` | 82 pt | tamanho da área de acerto no nível 1 |
| `hitRadiusPerLevel` | +8 % por nível de Mão Firme | crescimento da área por upgrade |
| `coreRadiusRatio` | 0,40 do anel | forma da área de acerto |
| `steadyHandLevel` | 1 | upgrades do jogador não são adquiríveis ainda |
| `throwSensitivity` | 2,6 × o vetor de puxada | **não vem de decisão em aberto** — é calibração de tato. Só se acerta com o aparelho na mão; por isso é a primeira coisa exposta no laboratório. |
| `throwDuration` | 0,42 s | idem — ritmo do arremesso |

Preço de cesta **não** entra em `RescueBalance`: não há compra nesta POC. A tabela de preços
provisórios fica registrada só na spec, para quando a economia integrar.

## Riscos

- **A sensibilidade do arremesso é o risco principal.** `throwSensitivity` e `hitRadiusBase`
  saem de um chute e só se validam no aparelho. Sinal de alerta: acertar o núcleo parece
  sorte, ou errar parece impossível. Mitigação: os dois são os primeiros controles do
  laboratório, ajustáveis sem recompilar.
- **Fuga cedo demais em raridade alta.** Com `S` em 0,05 de chance e 0,35 de fuga, o encontro
  pode acabar antes do jogador entender o que fez. Sinal: uma sequência de `S` terminando na
  primeira ou segunda tentativa. Mitigação: ambos ajustáveis; a decisão de balanceamento
  continua aberta na spec.
- **O anel elíptico no chão versus o toque na tela.** Se o alvo for desenhado em perspectiva
  e a comparação de distância for circular, o jogador vê uma coisa e o jogo julga outra.
  Mitigação: a mesma transformação desenha e julga — o engine recebe a distância já
  normalizada pela view, e a view não tem uma segunda fórmula.
- **61 emojis.** Nem toda espécie tem emoji próprio (peixe-mão-vermelho, soldadinho-do-Araripe).
  Aceitar aproximação e marcar com `// ponytail:` que arte por espécie substitui isso.

## Como verificar de ponta a ponta

```sh
xcodebuild -project "SantuarioPOC.xcodeproj" -scheme SantuarioPOC \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO build
```

Depois, no simulador:

1. Na barra inferior do santuário, confirmar três botões: `Acolhimento`, `Demo`, `Resgate`.
2. Tocar em `Resgate` → abre o encontro já com um animal, nome e raridade visíveis.
3. Fechar e reabrir cinco vezes → espécies diferentes, sem viés de raridade perceptível.
4. Tocar numa família incompatível → nada é selecionado, aparece a mensagem com a dieta da
   espécie, e o estoque não muda.
5. Puxar e soltar o estilingue → a cesta voa, o estoque daquele nível cai exatamente 1.
6. Errar a área de propósito → falha imediata, cesta consumida, e ainda assim a chance de fuga
   é sorteada.
7. Falhar sem fugir → dá para arremessar de novo no mesmo encontro.
8. Esgotar todas as cestas → o encontro termina informando que acabaram.
9. No laboratório do resgate, subir `baseChance` de `S` para 0,9 → o próximo `S` é resgatado
   quase sempre. Devolver ao valor de partida.
10. No laboratório, subir `steadyHandLevel` para 10 → o anel do alvo cresce visivelmente.
11. Resgatar um animal, voltar ao santuário → carteira, terrenos e `Acolhimento` inalterados.
12. Varrer a tela procurando barra de Confiança, segmentos ou seleção de frutos individuais:
    não existem.
13. Com Dynamic Type em tamanho de acessibilidade, os três botões da barra continuam
    alcançáveis.
