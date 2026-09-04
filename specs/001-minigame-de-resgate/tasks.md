# Tasks: Minigame de resgate

> **Spec:** `./spec.md` · **Plan:** `./plan.md`
> **Agente de implementação:** `task-implementer` (`model: sonnet`, `effort: medium`)

## Ordem de execução

T001 → T002 → T003 → T004 → (T005 [P] ‖ T006 [P])

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

## Depois de todas as tasks

- [ ] Orquestrador revisa os diffs contra `spec.md`
- [ ] Parâmetros provisórios do `plan.md` estão todos nomeados e rotulados
- [ ] Nenhum `[NEEDS CLARIFICATION]` foi resolvido por invenção
- [ ] Build limpo com o comando de `AGENTS.md` › Verificar a build
- [ ] Commit sem assinatura de modelo (ver `AGENTS.md` › Convenções de commit)
