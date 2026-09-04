# Spec: Minigame de resgate

> **Status:** aprovada
> **Criada em:** 2026-09-03
> **Aprovada por:** Eduardo — 2026-09-03

## Contexto e problema

A POC atual valida só o ciclo de gestão do santuário: o jogador coleta produção de animais
que já estão acolhidos. Como eles chegam lá nunca foi construído.

Esta POC valida o outro extremo do loop: o **encontro e resgate**. O jogador vê um animal
ameaçado, escolhe uma cesta de alimento compatível com a dieta da espécie, lança com um gesto
de puxar-e-soltar, e a tentativa resolve direto em resgate ou não. É o momento que dá sentido
a tudo o que o santuário faz depois — e é a mecânica de maior risco do jogo, porque depende de
um gesto que precisa ser gostoso na mão antes de valer a pena construir mapa, spawn e
geolocalização em volta.

Ao final, sabemos: o gesto funciona? A relação dieta → cesta → nível → chance é legível para
quem joga? A raridade se sente diferente?

## Escopo

**Dentro:**
- Uma tela de encontro alcançável a partir do santuário, ao lado das ações existentes
  (`Acolhimento`, `Demo`).
- Ao abrir, um animal do catálogo é sorteado e aparece imediatamente. Sem mapa, sem spawn,
  sem proximidade.
- Catálogo de 61 espécies com raridade (`S`–`D`) e família alimentar principal.
- Seleção de cesta: três famílias alimentares, três níveis cada. Família incompatível com a
  dieta da espécie é **bloqueada**, com o motivo visível.
- Gesto de lançamento puxar-e-soltar, com área de acerto visível.
- Resolução probabilística por tentativa: `resgatado` ou `não resgatado`.
- Cesta consumida a cada tentativa. Estoque finito por encontro.
- Várias tentativas por encontro, até o animal fugir ou as cestas acabarem.
- Resultado comunicado por mensagem na tela, e a opção de encontrar outro animal.

**Fora:**
- **Persistir o animal resgatado.** O resgate termina em mensagem; nada vai para o santuário
  nem para o acolhimento. Decisão explícita do dono do repo para esta POC.
- **Mapa, passos, geolocalização e spawn.** POC de outro integrante do grupo.
- **Comprar cesta com moeda.** O encontro entrega um estoque fixo. A economia de cestas entra
  quando mapa e moeda estiverem integrados.
- **Upgrades do jogador.** `Instinto de Resgate`, `Especialista em Raridades` e `Mão Firme`
  existem no canon e afetam o resultado, mas nenhum é adquirível ainda. Entram na fórmula como
  fatores fixos em 1, prontos para ligar.
- **XP e nível do jogador.**

## Regras confirmadas usadas

| Regra | Origem |
| --- | --- |
| Tocar no animal abre o encontro; o jogador escolhe uma cesta e a lança para perto do animal | `sistemas-do-jogo.md` › Encontro e resgate |
| A tentativa resolve **direto** em `animal resgatado` ou `animal foge`. Não existe barra de Confiança nem acúmulo de acertos | `sistemas-do-jogo.md` › O que não existe |
| A alimentação da espécie determina quais categorias de cesta são apropriadas | `sistemas-do-jogo.md` › Encontro e resgate |
| Três famílias de cesta — carnívora/piscívora, herbívora, invertebrados — três níveis cada | `tabelas-atuais.md` › Cestas por alimentação |
| Nível melhor de cesta aumenta chance **e** custo; nunca é troca cosmética | `sistemas-do-jogo.md` › Relações que não devem ser quebradas |
| A precisão do gesto importa; `Mão Firme` aumenta o raio de acerto do minigame | `sistemas-do-jogo.md` › Encontro e resgate |
| `Instinto de Resgate` afeta resgates em geral; `Especialista em Raridades` é adicional e específico para raros | `sistemas-do-jogo.md` › Relações que não devem ser quebradas |
| Estrutura da chance: `clamp(base × cesta × precisão × upgrades × contexto, mín, máx)`, cada fator configurável e observável — estrutura de projeto, não fórmula aprovada | `sistemas-do-jogo.md` › Modelo de probabilidade |
| Os frutos individuais no rodapé do wireframe **não** substituem o sistema de cestas | `sistemas-do-jogo.md` › O que não existe |
| Verbo central é `resgatar`/`acolher`/`cuidar`; animal não é troféu | `sistemas-do-jogo.md` › Premissa |

### Da concept art, o que foi mantido e o que foi descartado

A imagem de referência fornecida pelo dono do repo orienta **enquadramento e atmosfera**
(Artigo 3): vertical, animal ao fundo em ambiente do seu bioma, área de acerto no chão,
estilingue na base, rodapé com as cestas, instrução `PUXE E SOLTE`.

Descartado por não ser canon: a barra de **Confiança** e seus três segmentos; a leitura de que
o rodapé seleciona frutos individuais (o rodapé seleciona **cestas**); o contador de folha como
recurso da tela (não há gasto de moeda nesta POC).

## Catálogo de espécies

61 espécies, com raridade dada pelo dono do repo e **dieta principal** derivada de dieta real.
As cestas se referem à dieta principal — várias destas espécies são onívoras na natureza; a
coluna Observação marca onde houve simplificação de gameplay.

| Raridade | Espécie | Família de cesta | Observação |
| --- | --- | --- | --- |
| S | Jararaca-ilhoa | Carnívora/Piscívora | preda aves migratórias |
| S | Axolote | Invertebrados | vermes, crustáceos e larvas |
| S | Arara-azul | Herbívora | coquinhos de palmeira |
| S | Soldadinho-do-Araripe | Herbívora | onívoro: frutos + artrópodes |
| S | Tigre-de-Sumatra | Carnívora/Piscívora | |
| A | Peixe-mão-vermelho | Invertebrados | pequenos crustáceos e vermes |
| A | Tarântula-azul-de-Gooty | Invertebrados | insetos |
| A | Orangotango-de-Tapanuli | Herbívora | frugívoro; come insetos ocasionalmente |
| A | Rinoceronte-negro | Herbívora | ramoneador |
| A | Onça-pintada | Carnívora/Piscívora | |
| A | Jacaré-do-papo-amarelo | Carnívora/Piscívora | peixes; jovens comem invertebrados |
| A | Lobo-guará | Herbívora | onívoro: lobeira é ~metade da dieta |
| A | Indri | Herbívora | folívoro |
| B | Sapo-dourado-do-Panamá | Invertebrados | |
| B | Mico-leão-dourado | Herbívora | onívoro: frutos + insetos |
| B | Dragão-de-Komodo | Carnívora/Piscívora | |
| B | Gavial | Carnívora/Piscívora | piscívoro estrito |
| B | Elefante-da-floresta-africana | Herbívora | |
| B | Gorila-oriental | Herbívora | |
| B | Pangolim-chinês | Invertebrados | formigas e cupins |
| B | Rolinha-do-planalto | Herbívora | granívora |
| B | Urso-polar | Carnívora/Piscívora | |
| B | Cavalo-marinho-do-Cabo | Invertebrados | zooplâncton e pequenos crustáceos |
| B | Águia-filipina | Carnívora/Piscívora | |
| B | Leopardo-das-neves | Carnívora/Piscívora | |
| C | Camelo-bactriano-selvagem | Herbívora | |
| C | Preguiça-pigmeia-de-três-dedos | Herbívora | folhas de mangue |
| C | Bicho-pau-da-ilha-Lord-Howe | Herbívora | é invertebrado, mas **come** plantas |
| C | Muriqui-do-norte | Herbívora | folhas e frutos |
| C | Panda-vermelho | Herbívora | bambu |
| C | Salamandra-gigante-chinesa | Carnívora/Piscívora | peixes e crustáceos |
| C | Canguru-arborícola-de-Matschie | Herbívora | |
| C | Boto-cor-de-rosa | Carnívora/Piscívora | |
| C | Peixe-boi | Herbívora | plantas aquáticas |
| C | Ave-secretária | Carnívora/Piscívora | onívora: cobras, roedores e insetos |
| C | Peixe-serra-de-dentes-grandes | Carnívora/Piscívora | |
| C | Esturjão-beluga | Carnívora/Piscívora | |
| C | Rã-roxa-indiana | Invertebrados | cupins |
| C | Ariranha | Carnívora/Piscívora | |
| C | Tubarão-martelo-gigante | Carnívora/Piscívora | raias e peixes |
| C | Ocapi | Herbívora | |
| D | Pinguim-imperador | Carnívora/Piscívora | peixes e lulas |
| D | Lontra-marinha | Invertebrados | ouriços, caranguejos, moluscos |
| D | Tamanduá-bandeira | Invertebrados | formigas e cupins |
| D | Caranguejo-dos-coqueiros | Herbívora | frutos e cocos; é invertebrado, mas **come** vegetal |
| D | Addax | Herbívora | |
| D | Diabo-da-Tasmânia | Carnívora/Piscívora | carcaças |
| D | Kakapo | Herbívora | |
| D | Iguana-marinha | Herbívora | algas |
| D | Anta-malaia | Herbívora | |
| D | Náutilo-de-câmara | Invertebrados | necrófago de crustáceos |
| D | Harpia | Carnívora/Piscívora | |
| D | Quokka | Herbívora | |
| D | Manta-oceânica-gigante | Invertebrados | zooplâncton |
| D | Bico-de-sapato | Carnívora/Piscívora | peixes pulmonados |
| D | Lince-ibérico | Carnívora/Piscívora | coelhos |
| D | Urso-malaio | Invertebrados | onívoro: cupins e mel + frutos |
| D | Tatu-canastra | Invertebrados | formigas e cupins |
| D | Baleia-azul | Invertebrados | krill |
| D | Tartaruga-de-couro | Invertebrados | águas-vivas |
| D | Dugongo | Herbívora | capim marinho |

Contagem por família: 21 carnívora/piscívora, 25 herbívora, 15 invertebrados.

## Modelo de chance

Segue a estrutura do canon e imita a lógica de captura de Pokémon: cada espécie tem uma
dificuldade-base ligada à raridade, e a bola — aqui, a cesta — multiplica essa base, junto com a
qualidade do arremesso.

```
chanceFinal = clamp(baseRaridade × multCesta × multPrecisao × multUpgrades, chanceMin, chanceMax)
```

- `baseRaridade` — vem da raridade da espécie. Análogo ao *catch rate* de Pokémon.
- `multCesta` — nível 1, 2 ou 3 da família compatível. Análogo à Poké/Great/Ultra Ball.
- `multPrecisao` — onde a cesta caiu. Fora da área de acerto, a tentativa falha sem sorteio;
  no anel, valor neutro; no núcleo, bônus. Análogo ao Nice/Great/Excellent.
- `multUpgrades` — `Instinto de Resgate` e, para raridades `S`/`A`, `Especialista em Raridades`.
  Fixo em 1 nesta POC.

Área de acerto: começa relativamente pequena e cresce conforme `Mão Firme` sobe. Como não há
upgrades adquiríveis nesta POC, ela fica no raio de nível 1, e o crescimento por nível existe
como parâmetro para conferência no laboratório.

Falha não implica fuga automática. Após uma tentativa malsucedida, sorteia-se a fuga: se o
animal foge, o encontro acaba; senão, o jogador tenta de novo com o estoque que restar.

### Valores provisórios

Todos rotulados **provisório** (Artigo 4). Existem para o minigame rodar e ser sentido, não são
balanceamento aprovado. Devem ficar num único ponto de ajuste e serem editáveis no laboratório.

| Parâmetro | Valor provisório |
| --- | --- |
| `baseRaridade` S / A / B / C / D | 0,05 / 0,10 / 0,18 / 0,30 / 0,45 |
| `multCesta` nível 1 / 2 / 3 | 1,0 / 1,5 / 2,2 |
| `multPrecisao` núcleo / anel / fora | 1,8 / 1,0 / falha automática |
| `chanceMin` / `chanceMax` | 0,03 / 0,90 |
| `chanceFuga` após falha, S / A / B / C / D | 0,35 / 0,28 / 0,20 / 0,14 / 0,08 |
| Estoque por encontro, por nível de cesta | 5 / 3 / 2 |
| Sorteio da espécie | **uniforme** entre as 61, sem peso de raridade — decisão do dono do repo para esta POC, para que todo bicho apareça em teste |
| Preço da cesta nível 1 / 2 / 3 | 25 / 60 / 150 (referência; não se gasta nesta POC) |

## Decisões em aberto que afetam esta feature

- [x] `[RESOLVIDA]` A cesta é consumida em toda tentativa? → **Sim**, sempre. Dono do repo.
- [x] `[RESOLVIDA]` Falha sempre causa fuga? → **Não**, pode haver várias tentativas.
- [x] `[RESOLVIDA]` Cesta de família incompatível? → **Bloqueada**.
- [x] `[RESOLVIDA]` Dieta das 8 espécies onívoras → **confirmadas como estão na tabela**.
- [x] `[RESOLVIDA]` Estoque de cestas por encontro → **5 / 3 / 2**, finito.
- [x] `[RESOLVIDA]` Sorteio da espécie → **uniforme**, sem peso de raridade nesta POC.
- [ ] `[NEEDS CLARIFICATION: valores exatos de baseRaridade, multCesta, multPrecisao, chanceFuga
      e estoque]`
      → **Tratamento:** parâmetros provisórios na tabela acima, ajustáveis no laboratório.
      Confirmar depois de sentir o minigame na mão.
- [ ] `[NEEDS CLARIFICATION: raio da área de acerto no nível 1 de Mão Firme e quanto cresce por
      nível]`
      → **Tratamento:** parâmetros `raioBaseAcerto` e `crescimentoPorNivelMaoFirme`, provisórios.
- [ ] `[NEEDS CLARIFICATION: uma cesta de família compatível mas de nível insuficiente tem
      alguma penalidade além da chance menor?]`
      → **Tratamento:** não, apenas chance menor. Rotulado provisório.
- [ ] `[NEEDS CLARIFICATION: o que acontece com o animal resgatado quando esta POC for
      integrada]`
      → **Tratamento:** fora de escopo aqui. Vira spec própria.

## Comportamento esperado

### Cenário: encontro comum, resgate no primeiro arremesso
- **Dado** que o jogador está no santuário
- **Quando** aciona a ação de resgate
- **Então** abre a tela de encontro com um animal sorteado, seu nome e sua raridade visíveis,
  e as cestas disponíveis no rodapé
- **Quando** seleciona uma cesta da família compatível e puxa-e-solta acertando o núcleo da área
- **Então** o estoque daquela cesta cai em 1 e a tela informa que o animal foi resgatado, com o
  encontro encerrado e a opção de procurar outro animal

### Cenário: família incompatível
- **Dado** um animal de dieta herbívora no encontro
- **Quando** o jogador tenta escolher a família carnívora/piscívora
- **Então** a seleção é impedida e a tela diz por quê, nomeando a dieta da espécie
- **E** nenhuma cesta é consumida

### Cenário: arremesso fora da área
- **Quando** a cesta cai fora da área de acerto
- **Então** a tentativa falha sem sorteio de resgate, a cesta é consumida, e ainda assim é
  sorteada a fuga

### Cenário: fuga
- **Dado** um animal de raridade `S`
- **Quando** uma tentativa falha e o sorteio de fuga é positivo
- **Então** a tela informa que o animal fugiu e o encontro se encerra, oferecendo outro animal

### Cenário: cestas esgotadas
- **Dado** que o estoque de todas as cestas compatíveis chegou a zero
- **Quando** o jogador olha o rodapé
- **Então** não há arremesso possível e o encontro se encerra informando o motivo

### Cenário: nada é salvo
- **Dado** que o jogador resgatou um animal
- **Quando** volta ao santuário
- **Então** o santuário está exatamente como estava: nenhum animal novo no acolhimento

## Critérios de aceitação

- [ ] Existe uma ação de resgate na barra inferior do santuário, ao lado de `Acolhimento` e
      `Demo`, e ela abre a tela de encontro.
- [ ] Reabrir a tela sorteia outro animal, com chance igual para qualquer uma das 61 espécies.
- [ ] O nome da espécie e sua raridade são legíveis na tela.
- [ ] O rodapé mostra os três níveis da família compatível com o nome correto da tabela de
      cestas, e o estoque restante de cada um.
- [ ] Escolher uma família incompatível é impedido, com mensagem que nomeia a dieta da espécie.
- [ ] O gesto de puxar-e-soltar lança a cesta e a área de acerto é visível antes do arremesso.
- [ ] Cada arremesso reduz o estoque da cesta escolhida em exatamente 1, inclusive quando erra.
- [ ] Subir o nível da cesta aumenta a taxa de resgate observada em séries repetidas contra o
      mesmo animal — conferível repetindo tentativas e comparando.
- [ ] Um animal `S` resiste visivelmente mais que um `D` na mesma cesta.
- [ ] Após uma falha sem fuga, o jogador consegue tentar de novo no mesmo encontro.
- [ ] Resgate, fuga e cestas esgotadas produzem, cada um, uma mensagem distinta e clara.
- [ ] Voltar ao santuário depois de um resgate não altera nada nele.
- [ ] Os parâmetros de chance são ajustáveis pelo laboratório sem recompilar, e o efeito do
      ajuste aparece no encontro seguinte.
- [ ] Não existe barra de Confiança, segmentos, nem seleção de frutos individuais em lugar nenhum
      da tela.

## Fora de escopo declarado

- **Acolher o animal resgatado no santuário** — spec futura, quando resgate e gestão forem
  ligados.
- **Mapa de exploração, passos e spawn** — POC de outro integrante.
- **Comprar cestas com a moeda principal** — depende da economia integrada.
- **Upgrades do jogador e XP** — spec futura; a fórmula já tem o ponto de entrada.
- **Arte final, animação de fuga e som** — a POC valida a mecânica, não o acabamento.
- **Matriz espécie × bioma** — só importa quando o animal for acolhido.

---

# Extensão 2 — clima, hub de cestas e perspectiva

> Adição à spec aprovada. O minigame de resgate já entregue continua valendo inteiro; o que
> segue é o que muda.

## Contexto

O arremesso hoje é determinístico: mesma puxada, mesmo pouso, sempre. Isso torna o encontro
previsível depois de dez tentativas. O clima do lugar onde o jogador está de fato caminhando
entra como a variável que renova a mira a cada sessão — e amarra o jogo ao mundo real, que é o
que o resto da experiência já faz com a geolocalização.

Junto vão duas dívidas de interface: o rodapé de cestas em duas fileiras não escala para as
nove cestas, e a tela não tem perspectiva — o alvo é uma elipse que não parece chão.

## Escopo desta extensão

**Entra:**
- Uma condição de clima real, do lugar onde o jogador está, visível na tela de encontro.
- Vento que desvia o ponto de pouso da cesta, proporcional à sua velocidade e direção.
- Chuva que faz a cesta escorregar ao tocar o chão molhado, na direção em que voava.
- Mostrador de vento que permite ao jogador compensar a mira.
- Um hub único de cestas, aberto por um botão, no lugar das duas fileiras do rodapé.
- Perspectiva e acabamento visual do encontro.

**Não entra:**
- Clima afetando a chance de resgate, a chance de fuga ou o tamanho da área de acerto.
- Previsão do tempo, ciclo dia/noite, estações, ou clima histórico.
- Clima no santuário. Esta extensão vive só no encontro.
- Evento climático raro, tempestade especial, ou espécie que só aparece com certo clima.
- Comprar cestas pelo hub — o hub escolhe, não compra.

## Regras confirmadas usadas

Nenhuma. **Clima não existe no canon do jogo** (`sistemas-do-jogo.md` não o menciona). Esta
extensão é uma **proposta** do dono do repo, validada como POC antes de virar regra.

## Modelo de clima

Três condições, e só uma delas tem regra:

| Condição | Efeito no arremesso |
| --- | --- |
| **Sol** | Nenhum. É a condição ideal — o comportamento atual do jogo. |
| **Nublado** | Nenhum. Muda só a atmosfera. |
| **Chuva** | A cesta escorrega ao tocar o chão, na direção em que voava, proporcional à intensidade da chuva. |
| **Vento** | Empurra a cesta durante o voo, proporcional à velocidade, na direção para onde sopra. O vento é independente das outras três: pode ventar com sol. |

O desvio é **determinístico**: o mesmo arremesso, com o mesmo clima, cai sempre no mesmo ponto.
O clima é uma condição a ler e compensar, não um sorteio. Errar por vento é erro do jogador, e
custa a cesta e o sorteio de fuga como qualquer outro erro.

O jogador **vê o vento antes de puxar**: direção e velocidade. Sem o mostrador, o desvio seria
punição arbitrária; com ele, é a habilidade principal do minigame.

### Valores provisórios

| Parâmetro | Valor provisório | Rótulo |
| --- | --- | --- |
| Desvio do vento | 1,2 pt de desvio por km/h de vento | `valor provisório` |
| Escorregão da chuva | até 26 pt com chuva no talo | `valor provisório` |
| Duração do escorregão | 0,22 s | `valor provisório` |
| Chuva "no talo" | 7,5 mm/h de precipitação | `valor provisório` |
| Faixa útil de vento | 0 a 60 km/h | `valor provisório` |

Referência de tato: a área de acerto tem 82 pt de raio. Vento de 20 km/h desvia ~24 pt —
sentido, mas compensável. É esse o alvo, e ele só se confirma com o aparelho na mão.

## Decisões em aberto que esta extensão abre

```
[NEEDS CLARIFICATION: clima não existe no canon — esta extensão é proposta, não regra.
Se for adotada, `sistemas-do-jogo.md` precisa ganhar a seção correspondente]

[NEEDS CLARIFICATION: quanto o vento deve desviar — usando placeholder
desvio = velocidade_kmh × 1,2 pt, direção = para onde o vento sopra]

[NEEDS CLARIFICATION: quanto a chuva deve fazer escorregar — usando placeholder
escorregão = intensidade × 26 pt na direção do voo]

[NEEDS CLARIFICATION: se o clima deve ter teto de dificuldade — vento de 60 km/h com a área
de acerto atual pode tornar o resgate praticamente impossível. Nenhum teto foi aplicado]

[NEEDS CLARIFICATION: o que acontece com quem joga sem permissão de localização ou sem rede —
a POC cai em "sol, sem vento", o que é a condição mais fácil. Se o clima entrar no jogo final,
isso é um incentivo a negar a permissão]

[NEEDS CLARIFICATION: se upgrades do jogador devem reduzir o efeito do clima — nenhuma trilha
de upgrade atual fala em clima]
```

## Comportamento esperado

### Cenário: dia de sol
- **Dado** que o clima do lugar do jogador é sol sem vento
- **Quando** o jogador arremessa
- **Então** a cesta cai exatamente onde caía antes desta extensão, e o mostrador de vento
  aparece neutro

### Cenário: vento forte
- **Dado** que venta 40 km/h de oeste para leste
- **Quando** o jogador mira no centro do alvo e solta
- **Então** a cesta é empurrada para leste e cai fora do alvo, a cesta é consumida e a fuga é
  sorteada como em qualquer erro
- **E quando** o jogador mira compensando, na direção contrária ao empurrão
- **Então** ele acerta

### Cenário: chuva
- **Dado** que está chovendo forte
- **Quando** a cesta toca o chão dentro do alvo, perto da borda de fora
- **Então** ela escorrega mais um trecho na direção em que voava, podendo sair do alvo — e é a
  posição depois do escorregão que decide o resultado

### Cenário: sem clima disponível
- **Dado** que o jogador negou a permissão de localização, ou está sem rede
- **Quando** abre o encontro
- **Então** o jogo se comporta como num dia de sol sem vento, sem alerta, sem tela de erro e
  sem pedir a permissão de novo

### Cenário: escolher uma cesta
- **Dado** que o jogador está num encontro
- **Quando** toca no botão de cestas do rodapé
- **Então** sobe um painel com as nove cestas agrupadas por dieta, cada uma com nome e estoque
- **E** as cestas de dieta incompatível aparecem bloqueadas, com a razão escrita na própria
  linha
- **E quando** escolhe uma compatível
- **Então** o painel fecha e o botão do rodapé passa a mostrar a cesta escolhida

## Critérios de aceitação

- [ ] O encontro mostra a condição do céu e a velocidade e direção do vento antes do arremesso.
- [ ] A direção mostrada é a do empurrão, e a cesta de fato desvia para esse lado.
- [ ] Vento zero devolve o comportamento anterior, sem desvio nenhum.
- [ ] O mesmo arremesso repetido com o mesmo clima cai sempre no mesmo ponto.
- [ ] Com chuva, a cesta escorrega visivelmente ao tocar o chão, e o resultado sai depois disso.
- [ ] Sol e nublado não mudam número nenhum.
- [ ] Sem localização ou sem rede, o encontro funciona como sol sem vento, calado.
- [ ] Todos os parâmetros de clima são ajustáveis pelo laboratório sem recompilar, inclusive
      forçar uma condição.
- [ ] O rodapé tem um único botão de cestas, e ele nomeia a cesta selecionada.
- [ ] O painel de cestas mostra as nove, com as incompatíveis bloqueadas e justificadas.
- [ ] Escolher no painel fecha o painel e o arremesso seguinte consome da cesta escolhida.
- [ ] O alvo lê como sombra no chão, e não como elipse flutuando.
- [ ] Nenhum critério de aceitação da spec original deixou de valer.

## Fora de escopo declarado (extensão 2)

- **Clima no santuário** — o santuário é uma tela de gestão, não tem arremesso.
- **Partículas de chuva, neve, neblina, raio** — atmosfera além do necessário para ler a
  condição fica para a arte final.
- **Previsão e planejamento** — o jogador não escolhe quando sair para jogar em função do clima.
- **Clima como conteúdo** — nada de espécie exclusiva de chuva, nem bônus por clima raro.

