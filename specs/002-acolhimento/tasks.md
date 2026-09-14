# Tasks: Acolhimento de animal resgatado

> **Spec:** `./spec.md` · **Plan:** `./plan.md`
> **Agente de implementação:** `task-implementer` (`model: sonnet`, `effort: medium`)

## Ordem de execução

T001 → T002 → (T003 [P] ‖ T004 [P])

T003 e T004 são `[P]`: depois de T002 elas tocam arquivos disjuntos — T003 fica no resgate e
em `SanctuaryView.swift`, T004 fica só em `AuxiliarySheets.swift`.

---

### T001 — Ponte entre o catálogo do resgate e o do santuário

- **Agente:** `task-implementer`
- **Depende de:** nenhuma
- **Paralelizável:** não

**Objetivo:** dar a cada uma das 61 espécies resgatáveis um bioma principal e uma produção-base,
para que o santuário saiba onde ela mora e quanto rende.

**Arquivos:**
- `SantuarioPOC/Models/RescueSpeciesBridge.swift` — **criar**

**Leia antes:**
- `SantuarioPOC/Models/RescueModels.swift` — `RescueSpecies`, `Rarity` (`.s .a .b .c .d`),
  `RescueCatalog.all`.
- `SantuarioPOC/Models/SanctuaryModels.swift` — `SpeciesDefinition` (linha 130) e `Biome`
  (linha 3: `.aquatic .wetland .forest .grassland`). Veja `DemoSpecies.all` como exemplo de
  catálogo preenchido.

**O que criar:**

```swift
enum RescueSpeciesBridge {
    static let principalBiome: [String: Biome]   // 61 entradas, chave = RescueSpecies.id
    static let yieldByRarity: [Rarity: Double]   // 5 entradas
    static let all: [SpeciesDefinition]          // derivado de RescueCatalog.all
}
```

- `principalBiome`: uma entrada por espécie de `RescueCatalog.all`, escolhida pelo **habitat
  real do animal** (ex.: ariranha → `.aquatic`, lobo-guará → `.grassland`, onça-pintada →
  `.forest`, cervo-do-pantanal → `.wetland`).
- `yieldByRarity`: **use exatamente** `.s: 1.5, .a: 1.35, .b: 1.2, .c: 1.1, .d: 1.0`. Estes
  valores vêm do `plan.md` › Parâmetros provisórios. Não escolha outros.
- `all`: mapeia `RescueCatalog.all` para `SpeciesDefinition`, reaproveitando `id`,
  `displayName` e `symbol` **sem alteração**, e preenchendo `principalBiome` e `baseYield`
  pelas duas tabelas.

**Rótulo obrigatório (Artigo 4):** um comentário no topo do arquivo dizendo que bioma e
rendimento são **provisórios**, e apontando para `decisoes-em-aberto.md` › Santuário —
"matriz completa de espécies por bioma". Sem esse rótulo a task está incompleta.

**Não faça:**
- Não altere `RescueModels.swift` nem `SanctuaryModels.swift`.
- Não invente um tipo novo de espécie. A saída é `SpeciesDefinition`, que já existe.
- Não implemente graus de compatibilidade (`Compatível`, `Parcialmente compatível`,
  `Incompatível`). Só o bioma principal existe nesta feature.
- Não use `random` nem derive o bioma da família alimentar — dieta não é habitat.

**Critério de aceitação:**
- `RescueSpeciesBridge.all.count == RescueCatalog.all.count` (61), e nenhuma espécie fica sem
  bioma: se faltar entrada na tabela, isso precisa ser visível, não silencioso.
- Os quatro biomas aparecem na tabela — nenhum fica sem nenhuma espécie.
- Build limpa.

---

### T002 — O santuário passa a conhecer as espécies resgatáveis e a acolher

- **Agente:** `task-implementer`
- **Depende de:** T001
- **Paralelizável:** não

**Objetivo:** o catálogo do store passa a incluir as espécies do resgate, e a ação de acolher
vira uma ação de verdade em vez de um atalho de teste.

**Arquivos:**
- `SantuarioPOC/Store/SanctuaryStore.swift` — alterar
- `SantuarioPOC/Views/AuxiliarySheets.swift` — alterar **apenas a linha 243** (o chamador)

**O que mudar, exatamente:**

1. **Catálogo padrão** (`SanctuaryStore.swift:80`): o valor padrão de `speciesCatalog` passa de
   `DemoSpecies.all` para `DemoSpecies.all + RescueSpeciesBridge.all`.
   **União, não substituição.** Saves existentes referenciam ids `"…-demo"`; trocar o catálogo
   faria o filtro da linha 543 apagar esses animais ao carregar.

2. **Promover a ação** (`SanctuaryStore.swift:415`): `addAnimalForTesting(speciesID:)` vira

   ```swift
   @discardableResult
   func acolher(speciesID: String) -> Result<Void, SanctuaryActionError>
   ```

   Mesmo corpo: cria `AnimalInstance(id: UUID(), speciesID:, location: .waiting)`, `save()`,
   anuncia. Ajuste o texto do anúncio para não dizer "adicionado à Central" — use algo como
   `"\(species.displayName) chegou ao acolhimento"`. O `guard let species` que já existe vira o
   caminho de erro: devolva `fail(...)` com o caso de `SanctuaryActionError` que couber, em vez
   de `return` mudo.

3. **Atualizar o chamador** em `AuxiliarySheets.swift:243` para `store.acolher(speciesID:)`.
   Não mexa em mais nada desse arquivo — o resto dele é a T004.

**Reuse obrigatoriamente:**
- O padrão `Result<Void, SanctuaryActionError>` + `fail(...)` das outras ações do store.
- `placeAnimal`, `eligibleTerrains`, `waitingCount`, `capacity` — **não toque em nenhuma**.

**Não faça:**
- Não altere o filtro de saneamento da linha 543. Ele está certo; é o catálogo que precisa
  conter as espécies.
- Não mexa em `SanctuaryState`, `schemaVersion`, nem na migração de saves.
- Não remova `DemoSpecies`. Ele mantém os saves antigos vivos.
- Não crie uma segunda função que também acolhe. Uma implementação, os chamadores que houver.

**Critério de aceitação:**
- `store.species(withID: "lobo-guara")` (id do resgate, sem `-demo`) devolve uma espécie.
- O laboratório da Central continua conseguindo adicionar animal, agora pela `acolher`.
- Um animal de espécie do resgate sobrevive a `save` + recarregar o estado.
- Build limpa.

---

### T003 [P] — Resgatar passa a gravar no acolhimento

- **Agente:** `task-implementer`
- **Depende de:** T002
- **Paralelizável:** sim, com T004

**Objetivo:** um resgate bem-sucedido cria o animal no santuário, e o jogador consegue ir
direto para lá ver.

**Arquivos:**
- `SantuarioPOC/Views/Rescue/RescueViewModel.swift` — alterar
- `SantuarioPOC/Views/Rescue/RescueView.swift` — alterar
- `SantuarioPOC/Views/SanctuaryView.swift` — alterar **apenas a linha 71**

**O que mudar:**

1. `RescueViewModel` passa a receber o `SanctuaryStore` no `init` e guardá-lo. Siga o padrão de
   `SanctuaryMapViewModel` (`Views/SanctuaryMap/SanctuaryMapViewModel.swift`), que já recebe o
   store por `init`.
2. `RescueView` ganha `init(store:)` e constrói o view model com ele — o mesmo desenho que
   `SanctuaryMapView` já usa (`@StateObject` montado no `init`).
3. `SanctuaryView.swift:71`: `RescueView()` vira `RescueView(store: store)`.
4. Em `resolveThrow`, **no `case .rescued` e só nele**, chame `store.acolher(speciesID:)` com o
   `id` da espécie resgatada. O texto da mensagem de sucesso passa a dizer que o animal foi
   para o acolhimento.
5. O cartão de fim de encontro (`endedCard`) ganha um segundo botão, "Ir ao santuário", que
   fecha o encontro (`dismiss`). O botão "Encontrar outro animal" continua existindo e
   funcionando como hoje.

**Reuse obrigatoriamente:**
- `RescueSpecies.id` é a chave. É o mesmo id que T001 usou na ponte — não invente conversão,
  não acrescente sufixo, não faça lookup por nome.
- `FilledActionButtonStyle` / `SoftActionButtonStyle` já usados no `endedCard`.

**Não faça:**
- Não chame `acolher` em `.fled` nem em `.stayed`. Fuga não cria animal.
- Não chame `placeAnimal` aqui. O resgate **não** escolhe terreno — quem aloca é o jogador,
  na Central. Isso é escopo declarado da spec.
- Não mude nenhuma regra de resgate: chance, fuga, consumo de cesta, clima, moita e arremesso
  ficam idênticos. Você está acrescentando uma linha no sucesso, não reescrevendo a resolução.
- Não toque em `RescueModels.swift` nem em `WeatherModels.swift`.

**Acessibilidade:**
- O aviso de acolhimento no fim do encontro precisa ser anunciado por leitor de tela, como a
  mensagem de sucesso já é hoje.
- "Ir ao santuário" tem rótulo próprio e é alcançável com Dynamic Type grande.

**Critério de aceitação:**
- Resgatar um animal e voltar ao santuário: o badge "Acolhimento" subiu exatamente 1, e a
  espécie na Central é a mesma que o encontro mostrou.
- Uma fuga não altera o badge.
- Fechar e reabrir o app mantém o animal aguardando.
- Moita, vento, chuva e hub de cestas continuam idênticos.

---

### T004 [P] — A Central de acolhimento aguenta 66 espécies

- **Agente:** `task-implementer`
- **Depende de:** T002
- **Paralelizável:** sim, com T003

**Objetivo:** a lista de acolhimento continua legível depois que o catálogo cresceu de 5 para
66 espécies.

**Arquivos:**
- `SantuarioPOC/Views/AuxiliarySheets.swift` — alterar

**O que mudar:**

1. A seção "Aguardando terreno" (linha ~22) hoje faz `ForEach(store.speciesSummaries)`, que
   mapeia **todo** o catálogo — uma linha por espécie, inclusive as zeradas. Passe a listar só
   as espécies que têm animal: `waitingCount > 0 || accommodatedCount > 0`.
2. Quando nenhuma espécie tiver animal, mostre um estado vazio curto no lugar da lista — algo
   como "Nenhum animal aguardando. Resgate um animal para acolhê-lo aqui." Sem isso a seção
   fica em branco e parece quebrada.
3. O texto explicativo da linha 15 diz que a Central existe "sem implementar mapa ou resgate".
   Depois desta feature isso é falso na tela. Reescreva para descrever o que a Central é
   agora: onde os animais resgatados esperam por um terreno compatível. Mantenha a ressalva de
   que o destino quando falta capacidade ainda não é o fluxo final — essa parte continua
   verdadeira (`decisoes-em-aberto.md` › Santuário).

**Não faça:**
- Não redesenhe a Central. A spec manda reusar a tela, não substituí-la.
- Não mexa no `confirmationDialog` de escolha de terreno nem em `speciesRow` — o fluxo de
  alocação está aceito e funcionando.
- Não altere `store.speciesSummaries` no store. O filtro é de apresentação e fica na view.
- Não mexa na linha 243 (chamador de `acolher`) — isso é T002.
- Não adicione busca, ordenação, agrupamento por bioma nem seções novas. Necessidade
  especulativa (Artigo 7, degrau 1).

**Critério de aceitação:**
- Com nenhum animal, a Central mostra o estado vazio, não 66 linhas zeradas.
- Com dois animais de espécies diferentes aguardando, aparecem exatamente duas linhas.
- Alocar um animal mantém a linha enquanto ele estiver acolhido naquele terreno.
- O texto do topo não afirma mais que o resgate não existe.
- Com Dynamic Type grande, as linhas continuam legíveis.

---

## Depois da feature

- [ ] Orquestrador revisa os diffs contra `spec.md` e `plan.md`
- [ ] Verificação de ponta a ponta do `plan.md` › Como verificar, **inclusive o passo 5**
      (matar o app e reabrir — é o Risco 1)
- [ ] `[NEEDS CLARIFICATION]` continuam registrados, não resolvidos por invenção
- [ ] Tabela de bioma por espécie revisada **no aparelho**: se o loop travar por falta de
      terreno compatível, o ajuste é na tabela provisória
- [ ] Build limpa com o comando de `AGENTS.md` › Verificar a build
- [ ] Commit sem assinatura de modelo
