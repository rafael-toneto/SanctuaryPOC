# Tasks: Minigame de resgate

> **Spec:** `./spec.md` · **Plan:** `./plan.md`
> **Agente de implementação:** `task-implementer` (`model: sonnet`, `effort: medium`)

## Ordem de execução

T001 → T002 → T003 → T004 → (T005 [P] ‖ T006 [P])   ✅ entregues

**Extensão 2 — clima, hub de cestas e perspectiva:**

T007 → T008 → T009 → T010 → T012 → T011

Nenhuma é `[P]`: T008–T012 tocam todas o mesmo `RescueView.swift`. Se a capability do
WeatherKit atrasar T007, puxe **T010 para a frente** — ela não depende de clima.

---

### T001 — Criar tipos e catálogo do resgate

- **Agente:** `task-implementer`
- **Depende de:** nenhuma
- **Paralelizável:** não

**Objetivo:** criar `RescueModels.swift` com os tipos de conteúdo e o catálogo das 61 espécies.

**Arquivos:**
- `SantuarioPOC/Models/RescueModels.swift` — criar

**O que criar, exatamente:**

```swift
enum Rarity: String, CaseIterable, Identifiable   // s, a, b, c, d
    var title: String        // "Lendário", "Épico", "Raro", "Incomum", "Frequente"
    var letter: String       // "S", "A", "B", "C", "D"

enum BasketFamily: String, CaseIterable, Identifiable  // carnivore, herbivore, invertebrate
    var title: String        // "Dieta Carnívora e Piscívora", "Dieta Herbívora", "Dieta de Invertebrados"
    var shortTitle: String   // "Carnívora", "Herbívora", "Invertebrados"
    var symbol: String       // emoji da família: 🥩 / 🍇 / 🐛
    func basketName(tier: Int) -> String   // ver tabela abaixo

struct RescueSpecies: Identifiable, Equatable
    let id: String           // kebab-case, ex.: "lobo-guara"
    let displayName: String
    let symbol: String       // emoji
    let rarity: Rarity
    let family: BasketFamily

enum RescueCatalog
    static let all: [RescueSpecies]   // 61 espécies
```

Nomes das cestas — **copie literalmente**, são canon (`tabelas-atuais.md`):

| Família | Nível 1 | Nível 2 | Nível 3 |
| --- | --- | --- | --- |
| carnivore | Cesta de Carnes Secas | Cesta de Carnes Frescas | Cesta de Carnes Nobres |
| herbivore | Cesta de Folhas e Frutos Secos | Cesta de Folhas e Frutas Frescas | Cesta de Folhas e Frutas Exóticas |
| invertebrate | Cesta de Invertebrados Miúdos | Cesta de Invertebrados Médios | Cesta de Invertebrados Suculentos |

As 61 espécies, com raridade e família, estão na tabela **Catálogo de espécies** em
`specs/001-minigame-de-resgate/spec.md`. Transcreva as três colunas — a coluna Observação é
justificativa, não vai para o código. Escolha um emoji plausível por espécie; onde não houver
emoji próprio (peixe-mão-vermelho, soldadinho-do-Araripe, bicho-pau, náutilo…), use o mais
próximo e deixe **um** comentário no topo do catálogo:
`// ponytail: emoji é placeholder; arte por espécie substitui isto`

**Reuse obrigatoriamente:**
- O formato de `SpeciesDefinition` / `DemoSpecies` em `SantuarioPOC/Models/SanctuaryModels.swift`
  como **referência de estilo** (struct simples + `enum` com `static let all` + `byID`).

**Não faça:**
- Não importe SwiftUI neste arquivo. Só `Foundation`.
- Não altere `SanctuaryModels.swift`, `SpeciesDefinition` nem `DemoSpecies`.
- Não adicione bioma, produção, XP ou preço a `RescueSpecies` — o resgate não usa nada disso.
- Não renomeie nenhuma cesta, nem "corrija" nome de espécie.

**Critério de aceitação:**
- O projeto compila.
- `RescueCatalog.all.count == 61`, e a contagem por família bate: 21 carnívora, 25 herbívora,
  15 invertebrados.
- Nenhum `id` repetido.

---

### T002 — Adicionar RescueBalance e RescueEngine

- **Agente:** `task-implementer`
- **Depende de:** T001
- **Paralelizável:** não

**Objetivo:** acrescentar ao mesmo arquivo os números provisórios e as funções puras que
resolvem uma tentativa.

**Arquivos:**
- `SantuarioPOC/Models/RescueModels.swift` — alterar

**O que criar, exatamente:**

```swift
struct RescueBalance: Equatable {
    var baseChance: [Rarity: Double]        // s 0.05, a 0.10, b 0.18, c 0.30, d 0.45
    var tierMultiplier: [Int: Double]       // 1: 1.0, 2: 1.5, 3: 2.2
    var coreMultiplier: Double              // 1.8
    var ringMultiplier: Double              // 1.0
    var upgradeMultiplier: Double           // 1.0 — Instinto de Resgate / Especialista em Raridades ainda não existem
    var minChance: Double                   // 0.03
    var maxChance: Double                   // 0.90
    var fleeChance: [Rarity: Double]        // s 0.35, a 0.28, b 0.20, c 0.14, d 0.08
    var startingStock: [Int: Int]           // 1: 5, 2: 3, 3: 2
    var hitRadiusBase: Double               // 82 (pontos)
    var hitRadiusPerLevel: Double           // 0.08
    var coreRadiusRatio: Double             // 0.40
    var steadyHandLevel: Int                // 1 — nível de Mão Firme
    var throwSensitivity: Double            // 2.6
    var throwDuration: Double               // 0.42

    static let poc = RescueBalance(...)
    var hitRadius: Double { hitRadiusBase * (1 + Double(steadyHandLevel - 1) * hitRadiusPerLevel) }
    var coreRadius: Double { hitRadius * coreRadiusRatio }
}

enum ThrowPrecision { case core, ring, miss }
enum AttemptOutcome { case rescued, stayed, fled }

enum RescueEngine {
    static func isCompatible(_ family: BasketFamily, with species: RescueSpecies) -> Bool
    static func precision(distance: Double, balance: RescueBalance) -> ThrowPrecision
    static func rescueChance(species:tier:precision:balance:) -> Double
    static func resolve(species:tier:precision:balance:using generator: inout some RandomNumberGenerator) -> AttemptOutcome
}
```

Regras, sem margem para interpretação:

- `precision`: `distance <= coreRadius` → `.core`; `<= hitRadius` → `.ring`; senão `.miss`.
- `rescueChance` = `clamp(baseChance × tierMultiplier × multPrecisão × upgradeMultiplier, minChance, maxChance)`,
  onde multPrecisão é `coreMultiplier`, `ringMultiplier`, ou **0 para `.miss`**.
- `resolve`: se a chance sorteia sucesso → `.rescued`. Caso contrário sorteia `fleeChance` da
  raridade → `.fled` ou `.stayed`. Um `.miss` nunca resgata, mas **sempre** passa pelo sorteio
  de fuga.
- Todo número acima é **provisório**. Deixe um comentário de bloco em `RescueBalance` dizendo
  isso e apontando para `specs/001-minigame-de-resgate/spec.md`.

**Reuse obrigatoriamente:**
- O padrão de `BalanceConfig` e `ProductionEngine` em
  `SantuarioPOC/Models/SanctuaryModels.swift`: números num struct só, regras num `enum` de
  funções estáticas puras.

**Não faça:**
- Não use `Double.random(in:)` direto no engine — o gerador entra por parâmetro, para a regra
  ser exercitável sem tela.
- Não invente valor diferente dos listados acima.
- Não crie curva de custo, preço de cesta, XP nem qualquer coisa que a spec pôs fora de escopo.
- Não faça `RescueBalance` conformar a `Codable` — nada é persistido.

**Critério de aceitação:**
- O projeto compila.
- `rescueChance` de um `S` com cesta nível 1 no anel dá 0,05; o mesmo `S` com nível 3 no núcleo
  dá 0,198; um `D` com nível 3 no núcleo bate no teto de 0,90.
- `.miss` sempre resulta em chance 0.

---

### T003 — Montar a tela de encontro e a seleção de cestas

- **Agente:** `task-implementer`
- **Depende de:** T002
- **Paralelizável:** não

**Objetivo:** criar a tela do encontro com animal sorteado, alvo e rodapé de cestas — **ainda
sem o gesto de arremesso**.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — criar

**Estrutura:**

```swift
struct Encounter {
    let species: RescueSpecies
    var stock: [Int: Int]          // nível → cestas restantes, de balance.startingStock
    var selectedTier: Int          // começa em 1
    var outcome: AttemptOutcome?   // nil enquanto o encontro está aberto
    static func random(balance: RescueBalance) -> Encounter   // sorteio UNIFORME em RescueCatalog.all
}

struct RescueView: View {
    @State private var balance = RescueBalance.poc
    @State private var encounter = Encounter.random(balance: .poc)
    @State private var message: SanctuaryNotice?
}
```

Layout, de cima para baixo, num `ZStack` sobre `SanctuaryBackdrop()`:

1. **Topo:** botão de fechar (`chevron.left` ou `xmark`) à esquerda; nome da espécie em
   maiúsculas ao centro; à direita um selo com a letra e o título da raridade.
2. **Animal:** emoji grande (~110 pt) centralizado no terço superior.
3. **Alvo:** sob o animal, uma elipse — anel externo de raio `balance.hitRadius` e núcleo de
   `balance.coreRadius`, achatado verticalmente por um fator fixo `0.45` para dar perspectiva.
   Traço em `SanctuaryTheme.lime`, preenchimento translúcido.
4. **Estilingue:** na base, duas hastes em "V" (formas simples, sem asset) e, no meio delas, a
   cesta: um círculo com o emoji da família selecionada. Abaixo, o texto `PUXE E SOLTE`.
5. **Rodapé, duas linhas:**
   - famílias: os três `BasketFamily`. A compatível fica destacada e selecionada; as outras
     duas aparecem apagadas com um cadeado. Tocar numa incompatível **não** seleciona e
     publica em `message` um aviso `.warning` nomeando a dieta da espécie, ex.:
     `"O Lobo-guará aceita Dieta Herbívora."` Nenhuma cesta é consumida.
   - níveis: três slots com o nome da cesta (`family.basketName(tier:)`) e o estoque restante.
     O selecionado ganha contorno `SanctuaryTheme.lime`. Slot com estoque 0 fica desabilitado.

**Reuse obrigatoriamente:**
- `SanctuaryTheme`, `SanctuaryBackdrop`, `NoticeBanner`, `SanctuaryHaptics`,
  `SoftActionButtonStyle`, `FilledActionButtonStyle` — todos em `SantuarioPOC/Views/Components.swift`.
- `SanctuaryNotice` em `SantuarioPOC/Store/SanctuaryStore.swift` para o texto das mensagens.

**Não faça:**
- **Nenhuma barra de Confiança, nenhum segmento, nenhuma seleção de frutos individuais.**
  A concept art tem os três; o jogo não (Artigo 3).
- Não mostre saldo de moeda nem contador de recurso — não há gasto nesta POC.
- Não crie cor, fonte ou estilo de botão novo.
- Não toque em `SanctuaryStore`, `SanctuaryView` nem em qualquer arquivo do santuário.
- Não implemente o gesto de arremesso ainda. Isso é a T004.

**Critério de aceitação:**
- Um preview do SwiftUI mostra a tela completa com um animal sorteado.
- Tocar numa família incompatível mostra a mensagem com a dieta e não muda a seleção.
- Trocar o nível de cesta muda o slot destacado. (A cesta do estilingue mostra o emoji da
  **família**; não há arte por nível no catálogo.)

---

### T004 — Implementar o arremesso e a resolução da tentativa

- **Agente:** `task-implementer`
- **Depende de:** T003
- **Paralelizável:** não

**Objetivo:** ligar o gesto de puxar-e-soltar ao `RescueEngine` e apresentar os desfechos.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — alterar

**Comportamento:**

1. `DragGesture` sobre a cesta do estilingue. Enquanto arrasta, a cesta acompanha o dedo. O
   ponto de pouso é `pouso = centroDoEstilingue - translation * balance.throwSensitivity`.
   (A trajetória pontilhada existiu na primeira versão e foi retirada a pedido do dono do
   repo — o arremesso não mostra prévia do pouso.)
2. Ao soltar: anima a cesta até o ponto de pouso em `balance.throwDuration`, e então resolve.
3. Distância até o alvo, com o mesmo achatamento `0.45` usado no desenho — desenho e
   julgamento saem da mesma conta, nunca de duas:
   `distancia = hypot(dx, dy / 0.45)`, onde `dx`/`dy` vão do pouso ao centro do alvo.
4. `RescueEngine.precision(distance:balance:)` → `RescueEngine.resolve(...)` com
   `var generator = SystemRandomNumberGenerator()`.
5. **Sempre** decremente `stock[selectedTier]` em 1, inclusive quando o pouso foi `.miss`.
6. Desfechos:
   - `.rescued` → mensagem `.success` ("O Lobo-guará foi resgatado."), háptico de sucesso,
     encontro encerrado.
   - `.stayed` → mensagem `.warning` ("A cesta não convenceu. O animal continua ali."), o
     jogador pode arremessar de novo.
   - `.fled` → mensagem `.warning` ("O Lobo-guará fugiu."), encontro encerrado.
   - estoque de todos os níveis em 0 → encontro encerrado com "As cestas acabaram."
7. Encontro encerrado: um cartão sobre a tela com o desfecho e um botão
   **"Encontrar outro animal"**, que faz `encounter = .random(balance: balance)`. Nada é salvo
   em lugar nenhum.

**Reuse obrigatoriamente:**
- `RescueEngine` e `RescueBalance` de `SantuarioPOC/Models/RescueModels.swift` — toda a regra
  mora lá. A view calcula distância e apresenta; não decide.
- `SanctuaryHaptics` e `NoticeBanner` de `SantuarioPOC/Views/Components.swift`.

**Não faça:**
- Não duplique a fórmula de chance na view.
- Não adicione física de projétil, gravidade ou colisão — a trajetória é decoração; o ponto de
  pouso decide.
- Não salve nada: nem `UserDefaults`, nem `SanctuaryStore`, nem arquivo.
- Não faça o animal se mover, atacar nem desviar. Fora de escopo.
- Não ajuste os números de `RescueBalance` para "ficar melhor" — quem ajusta é o laboratório.

**Critério de aceitação:**
- Puxar e soltar lança a cesta; o estoque do nível usado cai exatamente 1 por arremesso.
- Errar o alvo de propósito nunca resgata, e ainda assim pode causar fuga.
- Depois de `.stayed`, dá para arremessar de novo no mesmo encontro.
- Resgate, fuga e cestas esgotadas produzem três mensagens distintas.
- "Encontrar outro animal" traz outra espécie, com estoque cheio.

---

### T005 [P] — Laboratório do resgate

- **Agente:** `task-implementer`
- **Depende de:** T004
- **Paralelizável:** `[P]` (só toca `RescueView.swift`)

**Objetivo:** permitir ajustar os parâmetros provisórios em tempo de execução, sem recompilar.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — alterar

**Comportamento:**
- Um botão de frasco (`flask.fill`) no topo da tela de encontro abre um `sheet`.
- O sheet edita o `@State private var balance` da `RescueView`. O efeito vale do próximo
  arremesso em diante.
- **Primeiros controles, nesta ordem** — são os que só se acertam com o aparelho na mão:
  `throwSensitivity` (1,0–5,0) e `hitRadiusBase` (40–160).
- Depois: `steadyHandLevel` (1–10, mostrando o raio resultante), `baseChance` por raridade
  (0–1), `tierMultiplier` por nível, `coreMultiplier`, `fleeChance` por raridade.
- Um botão "Restaurar valores provisórios" volta tudo para `RescueBalance.poc`.
- Um botão "Sortear outro animal".

**Reuse obrigatoriamente:**
- O padrão de `POCLabView` em `SantuarioPOC/Views/AuxiliarySheets.swift`: `Form` dentro de
  `NavigationStack`, aviso no topo de que os controles não representam o jogo final, botão
  "OK" que fecha. **Não** reuse a view em si — ela é toda `SanctuaryStore`.

**Não faça:**
- Não persista os ajustes. Fechar o app volta a `RescueBalance.poc`.
- Não coloque esses controles no `POCLabView` do santuário — são coisas separadas.
- Não exponha `throwDuration` nem `coreRadiusRatio`; ficam fixos por ora.

**Critério de aceitação:**
- Subir `baseChance` de `S` para 0,9 faz o próximo lendário ser resgatado quase sempre.
- Subir `steadyHandLevel` para 10 aumenta visivelmente o anel do alvo na tela.
- "Restaurar valores provisórios" devolve o comportamento inicial.

---

### T006 [P] — Botão Resgate no santuário

- **Agente:** `task-implementer`
- **Depende de:** T003
- **Paralelizável:** `[P]` (só toca `SanctuaryView.swift`)

**Objetivo:** abrir o minigame a partir da barra inferior do santuário.

**Arquivos:**
- `SantuarioPOC/Views/SanctuaryView.swift` — alterar

**Comportamento:**
- Um terceiro botão na `bottomBar`, **à direita de `Demo`**: `Label("Resgate", systemImage: "figure.walk")`
  — ou outro símbolo do SF Symbols que caiba melhor.
- Abre `RescueView` em `.fullScreenCover`, controlado por um `@State private var showsRescue = false`.
- A `RescueView` fecha por `@Environment(\.dismiss)` no seu próprio botão de voltar.

**Reuse obrigatoriamente:**
- `SoftActionButtonStyle`, já usado pelos outros dois botões da barra.
- O ramo `dynamicTypeSize.isAccessibilitySize` que já existe em `bottomBar` — o botão novo
  precisa entrar **nos dois ramos**, `HStack` e `VStack`.

**Não faça:**
- Não use o enum `SanctuarySheet` — o encontro é tela cheia, não sheet.
- Não passe `store` para a `RescueView`. Ela não usa.
- Não mexa em nenhuma outra parte de `SanctuaryView.swift`.

**Critério de aceitação:**
- Três botões na barra: `Acolhimento`, `Demo`, `Resgate`.
- `Resgate` abre o encontro em tela cheia; voltar retorna ao santuário intacto.
- Com Dynamic Type em tamanho de acessibilidade, os três continuam alcançáveis.

---

## Depois de todas as tasks (extensão 1)

- [ ] Orquestrador revisa os diffs contra `spec.md`
- [ ] Parâmetros provisórios do `plan.md` estão todos nomeados e rotulados
- [ ] Nenhum `[NEEDS CLARIFICATION]` foi resolvido por invenção
- [ ] Build limpo com o comando de `AGENTS.md` › Verificar a build
- [ ] Commit sem assinatura de modelo (ver `AGENTS.md` › Convenções de commit)

---
---

# Extensão 2 — clima, hub de cestas e perspectiva

> **Spec:** `./spec.md` › Extensão 2 · **Plan:** `./plan.md` › Extensão 2

### T007 — Clima: modelo, provedor e controle no laboratório

- **Agente:** `task-implementer`
- **Depende de:** T005 (o laboratório precisa existir)
- **Paralelizável:** não

**Objetivo:** ter uma condição de clima disponível na tela de encontro, vinda do WeatherKit
quando ele responder e do laboratório quando não responder. **Esta task não muda o arremesso**
— ela só entrega o dado e o controle manual.

**Arquivos:**
- `SantuarioPOC/Models/WeatherModels.swift` — criar
- `SantuarioPOC/Views/RescueView.swift` — alterar (carregar o clima, controles no laboratório)
- `SantuarioPOC/SantuarioPOC.entitlements` — criar
- `SantuarioPOC.xcodeproj/project.pbxproj` — alterar (`CODE_SIGN_ENTITLEMENTS`,
  `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`)

**O que criar, exatamente:**

```swift
// WeatherModels.swift — Foundation + CoreLocation + WeatherKit. Nada de SwiftUI.

enum SkyCondition: String, CaseIterable, Identifiable  // clear, cloudy, rain
    var title: String     // "Sol", "Nublado", "Chuva"
    var symbol: String    // SF Symbol: sun.max.fill / cloud.fill / cloud.rain.fill

struct WeatherConditions: Equatable {
    var sky: SkyCondition
    var windSpeedKmh: Double      // 0…60 é a faixa útil
    var windFromDegrees: Double   // 0 = vento VINDO do norte (convenção meteorológica)
    var rainIntensity: Double     // 0…1; 0 quando sky != .rain

    static let clearCalm = WeatherConditions(sky: .clear, windSpeedKmh: 0,
                                             windFromDegrees: 0, rainIntensity: 0)
}

@MainActor final class WeatherProvider: ObservableObject {
    @Published var conditions: WeatherConditions = .clearCalm
    @Published var source: Source = .fallback   // .live, .fallback, .manual
    enum Source { case live, fallback, manual }

    func refresh() async          // localização → WeatherKit → conditions; erro = mantém e marca .fallback
    func override(_ c: WeatherConditions)  // laboratório; marca .manual e não é sobrescrito por refresh
}
```

**Mapeamento do WeatherKit** (`CurrentWeather`):
- `wind.speed` convertido para km/h; `wind.direction` em graus vai direto para `windFromDegrees`.
- `precipitationIntensity` (mm/h) → `rainIntensity = min(mm/h ÷ 7.5, 1)` — **valor provisório**.
- `condition` → `.rain` para qualquer variante de chuva/chuvisco/tempestade; `.cloudy` acima de
  50 % de `cloudCover`; senão `.clear`. Não modele neve, granizo nem neblina.

**Localização:** `CLLocationManager` com `requestWhenInUseAuthorization()` e
`requestLocation()`. Permissão negada, indisponível ou timeout → **não é erro visível**:
mantém `.clearCalm`, marca `source = .fallback`, e o laboratório segue mandando. Nada de alerta.

**Capability (fazer uma vez, no Xcode — a task não compila sem isto):**
1. Em developer.apple.com → Identifiers → `com.endangeredanimalrescue.SantuarioPOC` → marcar
   **WeatherKit** e salvar.
2. No Xcode, target `SantuarioPOC` → Signing & Capabilities → **+ Capability → WeatherKit**.
   Isso cria o `.entitlements` e liga `com.apple.developer.weatherkit`.
3. Propagar o App ID pode levar ~30 min do lado da Apple.

**Laboratório (`RescueLabSheet`), seção nova "Clima", no topo:**
- `Picker` de `SkyCondition`, `Slider` de `windSpeedKmh` (0–60), `Slider` de `windFromDegrees`
  (0–359), `Slider` de `rainIntensity` (0–1, só quando `sky == .rain`).
- Um `Toggle` "Usar clima real" que, ao ligar, chama `refresh()`; ao desligar, volta para
  `.manual`.
- Uma linha de texto mostrando `source`: "clima real", "clima simulado" ou "ajustado à mão".

**Reuse obrigatoriamente:**
- O padrão de `Form`/`NavigationStack` do `RescueLabSheet` que T005 já criou — a seção Clima
  entra nele, não numa tela nova.
- `RescueBalance` para os números provisórios do clima. **Não** crie um segundo struct de
  configuração.

**Não faça:**
- Não mexa no arremesso, na precisão, na chance nem em `RescueEngine`. Isso é T008.
- Não desenhe indicador de vento na tela de encontro. Isso é T009.
- Não persista nada. Não faça cache do clima entre encontros.
- Não bloqueie a abertura do encontro esperando a resposta do WeatherKit — a tela abre com
  `.clearCalm` e atualiza quando (e se) a resposta chegar.
- Não trate `CODE_SIGNING_ALLOWED=NO` como erro: naquele build o entitlement não é aplicado e o
  WeatherKit falha — é exatamente o caminho `.fallback`.

**Critério de aceitação:**
- O projeto compila com o comando de `AGENTS.md`, que não assina.
- No simulador sem assinatura: o encontro abre normal, o laboratório mostra "clima simulado", e
  mexer nos sliders muda o valor exibido.
- Em device assinado, com permissão concedida: o laboratório mostra "clima real" e uma
  velocidade de vento plausível para a sua cidade.
- Negar a permissão de localização não trava nem alerta nada — só mantém "clima simulado".

---

### T008 — Vento desvia o pouso, chuva faz a cesta escorregar

- **Agente:** `task-implementer`
- **Depende de:** T007
- **Paralelizável:** não

**Objetivo:** o clima passa a mudar **onde a cesta cai** — e só isso. A área de acerto, a
fórmula de chance e a fuga continuam idênticas.

**Arquivos:**
- `SantuarioPOC/Models/WeatherModels.swift` — alterar (a função pura)
- `SantuarioPOC/Models/RescueModels.swift` — alterar (parâmetros novos em `RescueBalance`)
- `SantuarioPOC/Views/RescueView.swift` — alterar (aplicar no gesto e animar o escorregão)

**A regra, num lugar só:**

```swift
extension WeatherEngine {
    /// Pouso mirado → pouso real. Vento empurra; chuva escorrega na direção do voo.
    static func landing(aimed: CGPoint, throwVector: CGVector,
                        conditions: WeatherConditions, balance: RescueBalance,
                        squash: Double) -> CGPoint
}
```

- **Vento:** módulo = `windSpeedKmh × balance.windDriftPerKmh`. Direção = para onde o vento
  sopra, ou seja `windFromDegrees + 180°`. Bússola sobre a arena: 0° = topo da tela.
- **Chuva:** módulo = `rainIntensity × balance.rainSkidMax`, na direção do vetor de arremesso.
  Sem chuva, zero.
- **Perspectiva:** os dois desvios são calculados no **espaço do chão** e achatados só no fim —
  a componente vertical do resultado é multiplicada por `squash`, o mesmo `targetSquash` que
  desenha e julga o alvo. Uma conta só, como já vale para a distância.
  Consequência para a chuva: o vetor de arremesso chega em coordenadas de tela, então
  desachate (`dy / squash`) **antes** de normalizar. Normalizar na tela e achatar depois aplica
  o achatamento duas vezes, e a cesta escorrega fora da linha em que voou.
- Sol e nublado não entram na conta. `SkyCondition` não tem multiplicador.

**Na view:**
- O gesto calcula o pouso mirado como hoje, passa por `WeatherEngine.landing`, e é o resultado
  disso que vai para `RescueEngine.precision`.
- A animação: a cesta voa até o pouso já desviado pelo vento em `throwDuration`, e **depois**
  escorrega o trecho da chuva em `balance.rainSkidDuration` com `.easeOut`. Duas animações
  encadeadas, não uma.

**Parâmetros provisórios novos em `RescueBalance`, expostos no laboratório logo abaixo de
`throwSensitivity`:**

| Parâmetro | Valor provisório | Faixa no laboratório |
| --- | --- | --- |
| `windDriftPerKmh` | 1,2 pt por km/h | 0–4 |
| `rainSkidMax` | 26 pt com chuva no talo | 0–80 |
| `rainSkidDuration` | 0,22 s | fixo, não expor |

Com `hitRadiusBase` em 82 pt, 20 km/h dá ~24 pt de desvio: sentido, mas compensável. É esse o
alvo de tato.

**Não faça:**
- Não mexa em `RescueEngine`. A chance de resgate e a de fuga não sabem que existe clima.
- Não limite o arremesso nem "corrija" o desvio para dentro da tela.
- Não faça o desvio depender da raridade, do nível de cesta ou de upgrade.
- Não desenhe nada. Indicadores são T009.

**Critério de aceitação:**
- Com vento em 0 no laboratório, o arremesso cai exatamente onde caía antes desta task.
- Vento em 40 km/h vindo do oeste (270°) empurra a cesta visivelmente **para a direita**;
  mudar para 90° inverte o lado.
- O mesmo arremesso repetido com o mesmo clima cai sempre no mesmo ponto — o desvio é
  determinístico, não sorteado.
- Com `sky = .rain` e `rainIntensity = 1`, a cesta toca o chão e escorrega mais um pouco na
  direção em que voava, antes do desfecho aparecer.
- Errar por causa do vento consome a cesta e sorteia fuga igual a qualquer outro erro.

---

### T009 — Mostrador de vento e de chuva

- **Agente:** `task-implementer`
- **Depende de:** T008
- **Paralelizável:** não

**Objetivo:** o jogador consegue mirar compensando o vento porque **vê** o vento antes de puxar.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — alterar

**Comportamento:**
- Uma faixa de clima na `topBar`, à esquerda do botão de laboratório:
  - Seta (`arrow.up`) rotacionada para **onde o vento sopra** — a mesma direção que empurra a
    cesta em T008, não a de origem. Se as duas discordarem, o mostrador está mentindo.
  - Número com a velocidade: `"12 km/h"`.
  - O símbolo de `SkyCondition` ao lado.
  - Intensidade da cor da seta acompanha a velocidade: cinza parado, `SanctuaryTheme.lime` em
    vento fraco, laranja/vermelho da paleta em vento forte. Só se a paleta já tiver essas cores
    — se não tiver, varie a opacidade. **Nenhuma cor nova.**
- Sobre o alvo, quando houver vento: uma segunda elipse fantasma (traço pontilhado, opacidade
  baixa) no ponto para onde um arremesso "reto" cairia — a prévia do desvio.
- Com chuva, uma linha pontilhada curta saindo do alvo na direção do último arremesso não
  significa nada e **não deve existir**: o escorregão só é visível na animação.

**Acessibilidade:**
- A faixa inteira é um só elemento com `accessibilityLabel` do tipo
  `"Vento de 12 quilômetros por hora, soprando para a direita. Chuva."` Não deixe a seta e o
  número como dois elementos separados.
- Nada de informação só por cor: a velocidade em número já carrega o que a cor reforça.

**Reuse obrigatoriamente:**
- `SanctuaryTheme` inteiro. Nenhuma cor, fonte ou estilo novo.
- O `targetSquash` já existente para achatar a elipse fantasma igual à do alvo.

**Não faça:**
- Não anime a seta com pulso, tremor ou partícula. Nem chuva caindo na tela — atmosfera é T011.
- Não mostre a origem do vento em texto ("vento norte"); o jogador precisa da direção do
  empurrão, não da rosa dos ventos.
- Não recalcule o desvio aqui. A elipse fantasma chama a **mesma** `WeatherEngine.landing`.

**Critério de aceitação:**
- Girar `windFromDegrees` no laboratório gira a seta, e a cesta arremessada cai do lado para
  onde a seta aponta.
- Vento em 0 esconde a elipse fantasma e a seta fica neutra.
- Com VoiceOver, a faixa é lida numa frase só, com direção e velocidade.

---

### T010 — Hub de cestas em sheet, no lugar do rodapé de duas linhas

- **Agente:** `task-implementer`
- **Depende de:** T004 (não depende de clima — pode ser puxada para a frente)
- **Paralelizável:** não (toca `RescueView.swift`, como T008 e T009)

**Objetivo:** trocar as duas fileiras do rodapé por **um botão** que abre uma sheet com todas as
cestas, no formato do Pokémon GO.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — alterar
- `SantuarioPOC/Models/RescueModels.swift` — alterar (`imageName` em `BasketFamily`)

**Arte das cestas — assets temporários, já no catálogo:**

| Família | Imageset |
| --- | --- |
| carnivore | `cesta-carnes` |
| herbivore | `cesta-frutas` |
| invertebrate | `cesta-invertebrados` |

Entram no lugar do emoji de `BasketFamily.symbol`, tanto no hub quanto na cesta do estilingue.
São **provisórios** — arte final por cesta é acabamento e segue fora de escopo.

**Comportamento:**
- O rodapé passa a ter **um** botão largo, mostrando a cesta selecionada: imagem da família,
  nome canônico da cesta (`family.basketName(tier:)`) e o estoque restante. Toque abre a sheet.
- A sheet lista as **9 cestas**, agrupadas pelas três famílias, cada linha com a imagem da
  família, nome canônico, e o estoque à direita.
  - Família compatível: selecionável. Toque escolhe, dá `SanctuaryHaptics.selection()`, fecha a
    sheet e atualiza o botão.
  - Família incompatível: linha esmaecida, não selecionável, com a razão visível na própria
    linha — `"\(species.displayName) não come isto"`. **Não** use a mensagem no banner para
    isso; na sheet a razão fica junto do item.
  - Estoque zerado: linha esmaecida, não selecionável, marcada `"sem estoque"`.
- `.presentationDetents([.medium, .large])` e `.presentationDragIndicator(.visible)`.
- A cesta selecionada tem marca visível na lista (`checkmark` ou borda da paleta).

**Reuse obrigatoriamente:**
- `RescueEngine.isCompatible` — o bloqueio de dieta continua na regra, não na view.
- `SoftActionButtonStyle` / `FilledActionButtonStyle` no botão do rodapé.
- `SanctuaryTheme` e os hápticos existentes.

**Não faça:**
- Não crie um arquivo novo de view. A sheet mora em `RescueView.swift`, como o laboratório.
- Não mude `RescueBalance`, `RescueEngine`, o estoque, nem o consumo por arremesso.
- Não deixe a sheet aberta depois de escolher, e não permita escolher com o arremesso em voo.
- Não introduza "cesta favorita", "última usada" nem qualquer memória entre encontros.
- Não some com os nomes canônicos das cestas: eles são canon (Artigo 3).

**Critério de aceitação:**
- O rodapé tem exatamente um botão, e ele nomeia a cesta atualmente selecionada.
- A sheet mostra as 9 cestas; as 6 de famílias incompatíveis estão visivelmente bloqueadas com
  a razão escrita.
- Escolher uma cesta fecha a sheet e o botão passa a mostrá-la; o arremesso seguinte consome
  dela.
- Zerar um nível pela sheet deixa a linha bloqueada com "sem estoque".
- Com Dynamic Type em tamanho de acessibilidade, o botão e as linhas da sheet continuam legíveis
  e alcançáveis.

---

### T012 — Moita: revelar o animal raspando antes do arremesso

- **Agente:** `task-implementer`
- **Depende de:** T010
- **Paralelizável:** não
- **Nota de numeração:** entrou depois de T011 ser escrita, por isso o número é maior. A ordem
  de execução manda: **T012 vem antes de T011.**

**Objetivo:** o encontro passa a ter duas fases. O animal começa parcialmente escondido atrás
de uma moita; o jogador raspa a moita com o dedo até ela perder as folhas, o animal aparece, e
só então o estilingue funciona.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — alterar

**Comportamento:**
- Estado novo em `RescueView`: as folhas ainda presentes e um booleano derivado
  `animalRevealed`. `startNewEncounter()` repõe a moita cheia.
- Fase 1 — moita: um bloco de folhas cobre o emoji do animal e **parte** do alvo, deixando um
  pedaço do animal à mostra (é "parcialmente atrás", não invisível).
- O gesto é um arraste contínuo (`DragGesture(minimumDistance: 0)`) sobre a área da moita: cada
  `onChanged` remove as folhas dentro de um raio pequeno do dedo. Folha removida cai e some.
- Quando restar menos que o limiar de folhas, o resto cai junto e a fase 2 começa. Não exija
  raspar 100 % — ninguém termina uma raspadinha inteira.
- Fase 2 — o que já existe hoje, sem nenhuma mudança de regra.
- Háptico: `SanctuaryHaptics.selection()` a cada lote de folhas removido, não a cada folha —
  senão vira zumbido. `StretchHaptics` continua exclusivo do estilingue.

**Como desenhar as folhas (o degrau mais baixo que resolve):**
- Views SwiftUI comuns, ~20–30 folhas, `Ellipse` ou `Capsule` em tons já existentes de
  `SanctuaryTheme` (`forest`, `lime`), com rotação por índice. Nada de `Canvas`, nada de
  partícula, nada de imagem nova.
- Posição de cada folha vem de uma **fórmula** com o índice (espiral por ângulo áureo, ou
  grade com deslocamento por `sin`), não de `random`. Layout aleatório re-sorteia a cada
  redesenho e as folhas piscam de lugar.
- Queda da folha: `.transition(.offset(y:).combined(with: .opacity))` com `withAnimation`.

**A trava é uma só:**
- `canThrow` ganha `&& animalRevealed`. É o único ponto que já governa o gesto do estilingue,
  a prévia e o consumo de estoque — não espalhe `if` por outras views.
- O hub de cestas, o laboratório e o botão de fechar continuam funcionando durante a fase 1.

**Acessibilidade (não é opcional):**
- Raspar não existe para VoiceOver. A moita é **um** elemento acessível, rotulada
  `"Moita escondendo o \(species.displayName). Toque duas vezes para afastar."`, com ação que
  revela tudo de uma vez. Sem isso a tela fica intransponível com VoiceOver ligado.
- Com Reduzir Movimento, a queda das folhas vira fade — sem deslocamento.

**Não faça:**
- Não toque em `RescueModels.swift`. Contagem de folhas e limiar de revelação são apresentação,
  não regra: ficam como `private let` na view, fora de `RescueBalance`.
- Não mexa em `WeatherEngine`, `targetSquash`, `throwSensitivity` nem na resolução do arremesso.
- Não adicione dependência, SpriteKit, SceneKit nem `TimelineView`.
- Não gaste cesta, nem deixe o clima empurrar nada, durante a fase 1.
- Nenhuma cor nova fora de `SanctuaryTheme`.

**Critério de aceitação:**
- Ao abrir o encontro, o animal aparece parcialmente coberto e puxar o estilingue não arremessa.
- Arrastar o dedo sobre a moita tira folhas na trilha do dedo, e não em bloco.
- Passado o limiar, o resto cai, o animal fica inteiro e o arremesso volta a funcionar.
- "Encontrar outro animal" traz a moita cheia de novo.
- Com VoiceOver, a moita é um elemento só e a ação dupla revela o animal.
- Todos os critérios de T004, T008, T009 e T010 continuam passando.

---

### T011 — Perspectiva e acabamento visual do encontro

- **Agente:** `task-implementer`
- **Depende de:** T009, T010, T012, **e do arquivo do Figma** (o dono do repo está montando)
- **Paralelizável:** não
- **Status:** 🚧 **bloqueada** — não comece sem o link do Figma

**Objetivo:** encaixar animal, estilingue e ambiente numa perspectiva que faça o alvo no chão
parecer chão, seguindo o beta que vier do Figma.

**Arquivos:**
- `SantuarioPOC/Views/RescueView.swift` — alterar
- possivelmente `SantuarioPOC/Views/Components.swift` — alterar, **só** se o Figma pedir um
  componente reaproveitável de verdade

**Antes de começar:**
1. Carregue a skill `figma-design-to-code` (obrigatória antes de `get_design_context`) e a
   `figma-swiftui`.
2. Extraia tokens do Figma e **confronte com `SanctuaryTheme`**: cor que já existe na paleta
   reusa o token existente. Cor genuinamente nova entra em `SanctuaryTheme`, nomeada — nunca
   um hex solto na view.

**Restrições inegociáveis:**
- `targetSquash` continua sendo **um** número, usado para desenhar o alvo, para julgar a
  distância (T004) e para achatar o desvio do clima (T008). Se a perspectiva nova pedir outro
  achatamento, mude o valor — nunca duplique a constante.
- `RescueModels.swift` não é tocado. Nenhuma regra muda de comportamento nesta task.
- O gesto de puxar-e-soltar, os hápticos de esticar a corda (`StretchHaptics`) e o consumo de
  estoque ficam exatamente como estão.
- O que a concept art traz e o jogo não tem continua não existindo: barra de Confiança,
  segmentos, seleção de frutos individuais (Artigo 3).

**Não faça:**
- Não adicione SpriteKit, SceneKit, Lottie, Rive nem qualquer dependência. É SwiftUI.
- Não troque emoji por arte final: ilustração por espécie segue fora de escopo.
- Não recrie o hub de cestas de T010 nem a moita de T012 do zero porque o Figma desenhou
  diferente — ajuste o visual, preserve o comportamento aceito.

**Critério de aceitação:**
- A tela se parece com o beta do Figma nas proporções e no enquadramento.
- Todos os critérios de aceitação de T004, T008, T009 e T010 continuam passando sem alteração.
- Nenhum hex literal novo fora de `SanctuaryTheme`.
- Com Dynamic Type em tamanho de acessibilidade, nada é cortado nem fica inalcançável.

---

## Depois da extensão 2

- [ ] Orquestrador revisa os diffs contra `spec.md` › Extensão 2
- [ ] `[NEEDS CLARIFICATION]` do clima continuam registrados, não resolvidos por invenção
- [ ] `windDriftPerKmh` e `rainSkidMax` calibrados **no aparelho**, não no simulador
- [ ] Build limpo com o comando de `AGENTS.md` › Verificar a build
- [ ] Commit sem assinatura de modelo
