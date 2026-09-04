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

---

# Extensão 2 — clima, hub de cestas e perspectiva

> **Spec:** `./spec.md` › Extensão 2
> **Status:** aprovado, com T011 bloqueada no Figma

## Stack escolhida

| Item | Escolha | Por quê |
| --- | --- | --- |
| Fonte do clima | **WeatherKit** (`import WeatherKit`) | Nativo desde iOS 16, sem dependência, sem chave de API no repo, sem servidor. Degrau 4 do Artigo 7. Alternativa (OpenWeather + `URLSession` + chave) só ganharia se precisássemos de Android hoje — não precisamos. |
| Localização | **CoreLocation**, `requestWhenInUseAuthorization` + `requestLocation` | WeatherKit precisa de coordenada. Uma leitura por encontro, sem rastreamento contínuo, sem `startUpdatingLocation`. |
| Física do desvio | Aritmética de vetor na view, função pura no modelo | O desvio é um deslocamento do ponto de pouso, não simulação. Nenhuma engine. |
| Hub de cestas | `.sheet` + `.presentationDetents` | Nativo. O padrão Pokémon GO é uma sheet com lista — SwiftUI já entrega o detent, o arrasto e o dimming. |
| Perspectiva | SwiftUI, tokens vindos do Figma | Nada de SpriteKit/SceneKit por um chão em perspectiva. |
| Persistência | **Nenhuma** | O clima não é salvo, nem cacheado entre encontros. |

## Reuse

| Já existe | Uso nesta extensão |
| --- | --- |
| `RescueBalance` | **Estender.** `windDriftPerKmh`, `rainSkidMax`, `rainSkidDuration` entram aqui. Não nasce um segundo struct de configuração. |
| `RescueLabSheet` (T005) | **Estender.** A seção "Clima" entra no `Form` existente, não numa tela nova. |
| `targetSquash` (`RescueView`) | **Reusar.** Já desenha o alvo e julga a distância; agora achata também a componente vertical do desvio. Continua sendo **um** número. |
| `SanctuaryTheme`, `SoftActionButtonStyle`, `SanctuaryHaptics`, `NoticeBanner` | **Reusar.** Nenhuma cor, estilo ou háptico novo. |
| `StretchHaptics` (`Components.swift`) | **Não tocar.** O háptico da corda é ortogonal ao clima. |
| `RescueEngine` | **Não tocar.** Chance e fuga não sabem que existe clima — o clima só move o ponto de pouso, e o engine recebe o ponto já movido. |
| `SanctuaryStore` | **Não reusar.** O encontro continua ilha. |

## Arquitetura

```
WeatherModels.swift   (novo — Foundation + CoreLocation + WeatherKit, zero SwiftUI)
   SkyCondition · WeatherConditions
   WeatherProvider     → @MainActor ObservableObject; refresh() async, override()
   WeatherEngine       → landing(aimed:throwVector:conditions:balance:squash:) puro

RescueModels.swift    (alterado)
   RescueBalance      + windDriftPerKmh, rainSkidMax, rainSkidDuration

RescueView.swift      (alterado)
   @StateObject WeatherProvider   → .task { await refresh() }, nunca bloqueia a abertura
   gesto: pouso mirado → WeatherEngine.landing → RescueEngine.precision
   topBar: faixa de vento + céu (T009)
   rodapé: um botão → BasketSheet (T010)
   RescueLabSheet: seção Clima (T007)
```

**Fluxo de uma tentativa, atualizado** — os passos 1 e 2 do fluxo original passam a ser:

1. O vetor de puxada, espelhado e multiplicado por `throwSensitivity`, dá o **pouso mirado**.
1b. `WeatherEngine.landing` aplica vento e chuva e dá o **pouso real**.
2. A cesta anima até o pouso do vento em `throwDuration` e, com chuva, escorrega o trecho
   restante em `rainSkidDuration`. Do passo 3 em diante nada muda.

**Convenção de direção, num lugar só:** `windFromDegrees` é meteorológica — de onde o vento
vem. O empurrão é `windFromDegrees + 180°`, e a bússola é sobrada na arena com 0° no topo da
tela. Essa conversão mora **dentro** de `WeatherEngine.landing`; a seta do mostrador consome a
mesma função, não uma segunda fórmula. É a mesma armadilha que o risco do alvo elíptico já
tinha na extensão 1.

```
// ponytail: bússola achatada em cima da arena, 0° = topo. Se a perspectiva de T011
// mudar o eixo do chão, este é o único lugar a mexer.
```

**Degradação:** sem permissão, sem rede ou sem entitlement, `WeatherProvider` fica em
`.clearCalm` / `source = .fallback`. Isso é o dia de sol — o comportamento anterior à extensão.
Nada de alerta, nada de repedir permissão. A spec registra que isso vira incentivo perverso se
o clima entrar no jogo final.

## Arquivos tocados

| Arquivo | Novo/alterado | O que muda |
| --- | --- | --- |
| `SantuarioPOC/Models/WeatherModels.swift` | **novo** | `SkyCondition`, `WeatherConditions`, `WeatherProvider`, `WeatherEngine`. |
| `SantuarioPOC/Models/RescueModels.swift` | alterado | Três parâmetros novos em `RescueBalance`. |
| `SantuarioPOC/Views/RescueView.swift` | alterado | Clima no gesto, faixa de vento, hub de cestas, perspectiva. |
| `SantuarioPOC/SantuarioPOC.entitlements` | **novo** | `com.apple.developer.weatherkit`. Criado pelo Xcode ao ligar a capability. |
| `SantuarioPOC.xcodeproj/project.pbxproj` | alterado | `CODE_SIGN_ENTITLEMENTS` e `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`. |

**A extensão 1 prometia zero entradas no `project.pbxproj`. Esta quebra essa promessa** — é o
preço de uma capability e de uma permissão de sistema, e não há caminho que a evite. Fora
isso, continua sendo arquivo novo entrando sozinho no target pelo
`PBXFileSystemSynchronizedRootGroup`.

## Pré-requisito de conta (fora do código)

WeatherKit exige, uma vez só:

1. **App ID** `com.endangeredanimalrescue.SantuarioPOC` com WeatherKit marcado no portal da
   Apple. O bundle id já é explícito, não wildcard — serve.
2. **Capability** no target, pelo Xcode. Team `J63SH8A52R` já está configurado.
3. Propagação do App ID leva até ~30 min.

Limite gratuito: 500 mil chamadas/mês. Uma chamada por encontro não chega perto.

`xcodebuild ... CODE_SIGNING_ALLOWED=NO` **continua compilando** depois disso — o entitlement
simplesmente não é aplicado, e o app cai no caminho `.fallback`. O comando de verificação de
`AGENTS.md` segue válido; só o teste do clima real precisa de device assinado.

## Parâmetros provisórios introduzidos

| Parâmetro | Valor provisório | No laboratório |
| --- | --- | --- |
| `windDriftPerKmh` | 1,2 pt/km/h | sim, 0–4 |
| `rainSkidMax` | 26 pt | sim, 0–80 |
| `rainSkidDuration` | 0,22 s | não — ritmo, como `throwDuration` |
| chuva "no talo" | 7,5 mm/h | não — só o mapeamento do WeatherKit |

## Riscos

- **Calibração às cegas.** `windDriftPerKmh` sai de um chute, e o simulador não venta. Sinal:
  acertar com vento parece sorte, ou o vento parece decorativo. Mitigação: ajustável no
  laboratório, e o clima é forçável à mão sem sair de casa.
- **Vento forte pode inviabilizar o encontro.** 60 km/h × 1,2 = 72 pt de desvio contra 82 pt de
  raio. Sinal: dia de vendaval, nenhum resgate. Nenhum teto foi aplicado de propósito —
  está registrado como decisão em aberto na spec, não resolvido em silêncio.
- **Duas convenções de ângulo.** Meteorológica (de onde vem) versus a da tela (para onde
  empurra). Se a seta e o desvio divergirem, o jogo mente para o jogador. Mitigação: uma função
  só, consumida pelos dois.
- **Negar a localização é a estratégia ótima.** Sem clima, o jogo fica no modo mais fácil.
  Aceitável numa POC, inaceitável no jogo final — registrado na spec.
- **T011 depende de um arquivo que ainda não existe.** Se o Figma atrasar, T007–T010 entregam
  sozinhas e a perspectiva fica para depois. Por isso T011 é a última e não bloqueia nada.
- **Privacidade.** A permissão é `WhenInUse`, uma leitura por encontro, nada persistido e nada
  enviado a terceiros além da própria Apple. O texto de justificativa no Info.plist precisa
  dizer isso em uma frase honesta.

## Como verificar de ponta a ponta

```sh
xcodebuild -project "SantuarioPOC.xcodeproj" -scheme SantuarioPOC \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO build
```

No simulador (clima simulado, pelo laboratório):

1. Abrir o encontro → a faixa de clima aparece; o laboratório diz "clima simulado".
2. Vento em 0 → sem elipse fantasma, e o arremesso cai onde caía antes.
3. Vento 40 km/h vindo de 270° → a seta aponta para a direita e a cesta desvia para a direita.
   Mudar para 90° → inverte.
4. Repetir o mesmo arremesso três vezes com o mesmo clima → mesmo ponto de pouso.
5. `sky = .rain`, intensidade 1 → a cesta escorrega depois de tocar o chão, e o desfecho sai
   depois do escorregão.
6. Errar por vento → cesta consumida e fuga sorteada, igual a qualquer erro.
7. Rodapé: um botão só, nomeando a cesta selecionada. Abrir → nove cestas, seis bloqueadas com
   a razão escrita.
8. Escolher uma cesta → o painel fecha, o botão muda, o arremesso seguinte consome dela.
9. Zerar um nível → aquela linha fica bloqueada com "sem estoque".
10. Dynamic Type em tamanho de acessibilidade → faixa de clima, botão e painel legíveis.
11. VoiceOver na faixa de clima → uma frase só, com direção e velocidade.

Em device assinado:

12. Conceder a localização → o laboratório diz "clima real" e a velocidade bate com a da cidade.
13. Negar a localização → nada de alerta; o encontro roda como sol sem vento.
14. Modo avião → mesmo comportamento do item 13.

