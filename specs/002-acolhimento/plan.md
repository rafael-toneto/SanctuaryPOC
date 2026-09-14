# Plan: Acolhimento de animal resgatado

> **Spec:** `./spec.md`
> **Status:** aprovado

## Stack escolhida para esta feature

| Item | Escolha | Por quê |
| --- | --- | --- |
| Linguagem / plataforma | Swift 5.9 / iOS 17+ | É a POC existente. Esta feature liga duas metades que já vivem nela; não há nada a escolher |
| Renderer / UI | SwiftUI | Idem. Nenhuma tela nova é criada — só um botão e um filtro numa lista que já existe |
| Persistência | `UserDefaults` via `SanctuaryPersisting`, como já é | O animal acolhido entra em `SanctuaryState.animals`, que já é serializado e versionado (`schemaVersion: 2`) |
| Arquitetura | MVVM no resgate, store observável no santuário | Ambos os padrões já estão no repo depois do merge da `MapMVVM` |

Esta feature roda **inteiramente sobre a POC existente**. Nenhum arquivo de regra nova, nenhum
motor novo. O trabalho é ligação e dados.

## Reuso (seção obrigatória — Artigo 7, degrau 2)

| Já existe | Onde | Uso nesta feature |
| --- | --- | --- |
| `AnimalLocation.waiting` | `Models/SanctuaryModels.swift:180` | **É** o acolhimento. Nada novo é criado para representar "animal esperando terreno" |
| `store.placeAnimal(speciesID:into:)` | `Store/SanctuaryStore.swift:272` | Aloca o animal no terreno. Já valida bioma, espécie única, capacidade e disponibilidade. **Não é tocada** |
| `store.addAnimalForTesting(speciesID:)` | `Store/SanctuaryStore.swift:415` | Faz **exatamente** o que o resgate precisa: cria `AnimalInstance(.waiting)`, persiste e anuncia. Vira a ação real (ver Arquitetura) em vez de ganhar uma gêmea |
| `store.eligibleTerrains(for:)` | `Store/SanctuaryStore.swift:182` | Decide quais terrenos aceitam a espécie. Reusada como está |
| `store.waitingCount(for:)`, `waitingAnimalCount` | `Store/SanctuaryStore.swift:164`, `:~120` | Contadores do acolhimento. Reusados |
| `AnimalStorageView` ("Central de acolhimento") | `Views/AuxiliarySheets.swift:31` | É a tela de acolhimento que a spec manda reusar. Recebe um filtro, não um redesenho |
| Botão "Acolhimento" + badge | `Views/SanctuaryView.swift:170` | Já mostra a contagem. Passa a subir sozinho quando o resgate gravar |
| `SpeciesDefinition` | `Models/SanctuaryModels.swift:130` | O tipo que o santuário entende. A ponte **produz** isto a partir de `RescueSpecies`; nenhum tipo novo de espécie é criado |
| `ProductionEngine.productionRate` | `Models/SanctuaryModels.swift:354` | Já soma `baseYield` dos residentes. Passa a incluir os resgatados sem nenhuma alteração |
| `RescueCatalog.all` (61 espécies) | `Models/RescueModels.swift` | Fonte dos nomes, símbolos, raridade e família. **Não é alterado** |
| `SanctuaryActionError` + `Result` | `Store/SanctuaryStore.swift` | Padrão de retorno das ações. A ação de acolher segue ele |

**Nada novo será criado para:** representar o animal em espera, alocar em terreno, validar
bioma/capacidade/espécie única, contar quem aguarda, listar terrenos elegíveis, persistir,
calcular produção, ou desenhar a tela de acolhimento.

**O que genuinamente não existe e precisa ser criado:** o bioma principal e a produção-base
das 61 espécies resgatáveis. É o único buraco real — sem esses dois campos o santuário não
tem como saber onde a espécie mora nem quanto ela rende.

## Arquitetura

```
RescueViewModel.resolveThrow()  ── case .rescued ──▶  store.acolher(speciesID:)
                                                              │
                                              AnimalInstance(.waiting) + save()
                                                              │
                                                              ▼
                                      SanctuaryView › botão "Acolhimento" (badge +1)
                                                              │
                                                              ▼
                                      AnimalStorageView ── store.placeAnimal ──▶ terreno
```

**A ponte entre os dois catálogos.** `RescueSpeciesBridge` lê `RescueCatalog.all` e devolve
`[SpeciesDefinition]`, preenchendo os dois campos que faltam:

- `principalBiome` — tabela provisória, uma entrada por espécie, derivada do habitat real do
  animal. Rotulada provisória porque a matriz canônica não existe.
- `baseYield` — derivado da raridade por uma tabela de 5 entradas, não 61. Mais raro rende
  mais. Provisório.

`id`, `displayName` e `symbol` vêm de `RescueSpecies` sem alteração — é o mesmo animal, não
uma cópia.

**O catálogo do store passa a ser a união** `DemoSpecies.all + RescueSpeciesBridge.all`.
União, não substituição: saves existentes referenciam ids `"…-demo"` e trocar o catálogo
apagaria esses animais (ver Risco 1). `speciesCatalog` já é injetável no `init`
(`Store/SanctuaryStore.swift:80`), então a mudança é no valor padrão.

**A ação de acolher.** `addAnimalForTesting(speciesID:)` já é a implementação correta. Ela é
promovida a `acolher(speciesID:) -> Result<Void, SanctuaryActionError>`, com o texto do
anúncio ajustado, e o laboratório passa a chamar a mesma função. Uma implementação, dois
chamadores — em vez de duas funções que fazem a mesma coisa e divergem.

**Onde ficam os valores ajustáveis** (Artigo 5): num único arquivo novo,
`Models/RescueSpeciesBridge.swift`, com as duas tabelas no topo e o comentário de rótulo
provisório apontando para `decisoes-em-aberto.md` › Santuário. Nenhum bioma e nenhum
rendimento aparece embutido em lógica ou em view.

## Arquivos tocados

| Arquivo | Novo/alterado | O que muda |
| --- | --- | --- |
| `SantuarioPOC/Models/RescueSpeciesBridge.swift` | **novo** | Tabela provisória de bioma por espécie, tabela de rendimento por raridade, e a conversão `RescueSpecies → SpeciesDefinition` |
| `SantuarioPOC/Store/SanctuaryStore.swift` | alterado | `speciesCatalog` padrão vira a união; `addAnimalForTesting` vira `acolher(speciesID:)` |
| `SantuarioPOC/Views/Rescue/RescueViewModel.swift` | alterado | Recebe o store; `case .rescued` chama `acolher` |
| `SantuarioPOC/Views/Rescue/RescueView.swift` | alterado | `init(store:)`; o cartão de fim de encontro ganha "Ir ao santuário" |
| `SantuarioPOC/Views/SanctuaryView.swift` | alterado | `RescueView(store: store)` na linha 71 |
| `SantuarioPOC/Views/AuxiliarySheets.swift` | alterado | Lista só espécies com animais; texto desatualizado corrigido |
| — | — | O único chamador de `addAnimalForTesting` é `AuxiliarySheets.swift:243`, já na linha acima |

`RescueModels.swift`, `WeatherModels.swift` e todo o motor de resgate **não são tocados**.

## Parâmetros provisórios introduzidos

| Parâmetro | Valor provisório | Decisão em aberto correspondente |
| --- | --- | --- |
| `RescueSpeciesBridge.principalBiome` | Uma entrada por espécie (61), derivada do habitat real do animal | `decisoes-em-aberto.md` › Santuário — "matriz completa de espécies por bioma e efeitos de cada grau de compatibilidade" |
| `RescueSpeciesBridge.yieldByRarity` | `s: 1.5`, `a: 1.35`, `b: 1.2`, `c: 1.1`, `d: 1.0` — mesma faixa dos 1.0–1.3 já usados por `DemoSpecies` | `decisoes-em-aberto.md` › Economia idle — parâmetros de produção por espécie |
| Fila de acolhimento sem limite | Sem teto, sem descarte | `decisoes-em-aberto.md` › Santuário — "destino de um animal resgatado quando não houver capacidade válida" |

Só o grau `Principal` é implementado. `Compatível`, `Parcialmente compatível` e `Incompatível`
não existem neste código — a spec os declara fora de escopo.

## Riscos

- **Risco 1 — o animal some ao reabrir o app, em silêncio.**
  `Store/SanctuaryStore.swift:543` filtra `state.animals` descartando todo animal cuja espécie
  não esteja em `speciesByID`. Se a ponte não entrar no `speciesCatalog`, cada animal resgatado
  é gravado, sobrevive à sessão, e **desaparece no próximo carregamento** sem erro nem aviso.
  É o modo de falha mais provável desta feature e o mais difícil de perceber.
  **Sinal de alerta:** o badge de Acolhimento mostra o número certo até fechar o app, e zera ao
  reabrir. Verificação obrigatória no passo 4 de ponta a ponta.

- **Risco 2 — espécie duplicada nas listas.** `lobo-guara` (ponte) e `lobo-guara-demo`
  (`DemoSpecies`) são o mesmo animal com ids diferentes. A união faz Lobo-guará aparecer duas
  vezes. É o preço de não apagar saves antigos. Aceito para a POC; some quando `DemoSpecies`
  for aposentado.

- **Risco 3 — a Central vira uma parede de linhas vazias.**
  `speciesSummaries` (`Store/SanctuaryStore.swift:131`) mapeia **todo** o catálogo, e
  `AnimalStorageView` renderiza uma linha por entrada. Com 5 espécies funciona; com 66 a seção
  "Aguardando terreno" fica com 60+ linhas zeradas. Por isso a lista passa a filtrar.

- **Risco 4 — texto que vira mentira.** `AuxiliarySheets.swift:15` diz que a Central existe
  "sem implementar mapa ou resgate". Depois desta feature a frase está errada na tela.

- **Risco 5 — bioma sem terreno.** Se a tabela mandar espécies para os quatro biomas e o
  jogador só tiver um, a maioria dos resgates fica parada aguardando. É o comportamento que a
  spec escolheu, mas se na prática travar o loop, o ajuste é na tabela provisória — não na regra.

## Como verificar de ponta a ponta

1. Build limpa:
   ```sh
   xcodebuild -project "SantuarioPOC.xcodeproj" -scheme SantuarioPOC \
     -destination "platform=iOS Simulator,name=iPhone 17" \
     CODE_SIGNING_ALLOWED=NO build
   ```
2. Abrir o santuário e anotar o número no badge "Acolhimento".
3. Entrar no Resgate e resgatar um animal — se a chance atrapalhar, usar o laboratório do
   resgate para subir a chance. Ler o nome da espécie no encontro.
4. Voltar ao santuário: o badge subiu **exatamente 1**, e a Central mostra **aquela** espécie.
5. **Matar o app pelo multitarefa e reabrir.** O animal continua lá. (Risco 1.)
6. Abrir a Central, escolher o animal, alocar num terreno do bioma principal dele. O terreno
   passa a mostrar 1 acolhido e a produção do terreno sobe.
7. Resgatar uma espécie de um bioma que o jogador não possui: o animal fica aguardando e a
   Central deixa claro que falta terreno compatível. Nada some, nada quebra.
8. Provocar uma fuga: o badge de Acolhimento **não** muda.
9. Conferir que moita, vento, chuva e hub de cestas continuam idênticos — nenhuma regra de
   resgate foi tocada.
