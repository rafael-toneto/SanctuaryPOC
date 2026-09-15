# Spec: Acolhimento de animal resgatado

> **Status:** aprovada
> **Criada em:** 2026-09-14
> **Aprovada por:** Eduardo Garcia Fensterseifer, 2026-09-14

## Contexto e problema

Hoje o resgate termina no vazio. O jogador escolhe a cesta, arremessa, lê
"<espécie> foi resgatado" — e o animal deixa de existir no instante seguinte. Nada é
guardado, nada aparece no santuário, e um novo encontro começa como se o anterior não
tivesse acontecido. O minigame é um brinquedo isolado.

Do outro lado, o santuário já sabe guardar animais que ainda não têm terreno e já sabe
alocá-los quando o jogador escolhe onde vão morar. Essa metade funciona e é usada — só não
recebe nada de ninguém, porque a única forma de criar um animal é um atalho de teste.

Esta feature liga as duas pontas: **o animal resgatado passa a chegar no santuário e a
esperar por um terreno.** É o passo 7 do loop principal do jogo, o único elo faltando entre
"resgatar" e "gerar moeda".

O que muda para quem joga: resgatar passa a ter consequência. O jogador sai do encontro
sabendo que há um animal aguardando acolhimento, vai ao santuário, escolhe o terreno, e a
partir dali aquele animal produz. O ciclo fecha pela primeira vez.

## Escopo

**Dentro:**

- Um resgate bem-sucedido cria um animal daquela espécie no santuário, em estado de espera,
  e esse registro sobrevive a fechar e reabrir o jogo.
- O jogador é avisado, ao fim do encontro, de que o animal foi para o acolhimento.
- O jogador consegue, a partir do santuário, alocar um animal em espera a um terreno que o
  aceite — reusando o fluxo de alocação que já existe.
- Toda espécie que pode ser resgatada passa a ter um **bioma principal** e uma
  **produção-base**, para que o santuário saiba quais terrenos a aceitam e quanto ela rende.
- Um caminho para o jogador ir do fim do encontro até o santuário sem sair e voltar pelo menu.

**Fora:**

- **Nenhuma regra de resgate muda.** Chance, fuga, consumo de cesta, clima, moita e
  arremesso ficam exatamente como estão. Esta feature começa depois do resultado `resgatado`.
- Reprodução, mover indivíduos entre terrenos, e graus de compatibilidade além do bioma
  principal — são decisões em aberto e não entram aqui.
- XP por resgate, custo de acolher, e limite de quantos animais cabem esperando.
- Ilustração por espécie. O animal continua representado como já é hoje.
- Qualquer mudança no mapa do santuário ou na tela de terreno além do necessário para alocar.

## Regras confirmadas usadas

| Regra | Origem |
| --- | --- |
| Um animal resgatado é levado ao santuário e precisa de capacidade em um terreno adequado | `sistemas-do-jogo.md` › Loop principal, passo 7 |
| Animais acolhidos produzem moeda passivamente | `sistemas-do-jogo.md` › Loop principal, passo 8 |
| No fluxo do jogo, `Resgate` leva a `Acolher no santuário`, que leva a `Gerar moeda idle` | `sistemas-do-jogo.md` › Loop principal, diagrama |
| Os verbos centrais da fantasia são `resgatar`, `acolher` e `cuidar`; animais não são troféus nem propriedade | `sistemas-do-jogo.md` › Premissa e objetivo de experiência |
| Cada terreno recebe exatamente um entre quatro biomas: Aquático, Úmido, Floresta ou Campo | `sistemas-do-jogo.md` › Santuário e terrenos |
| Um terreno aceita uma única espécie por vez, mas comporta múltiplos indivíduos dela | `sistemas-do-jogo.md` › Santuário e terrenos |
| O upgrade de capacidade aumenta o número máximo de indivíduos da mesma espécie naquele terreno | `sistemas-do-jogo.md` › Santuário e terrenos |
| Uma espécie se representa por dieta, raridade, **biomas** e parâmetros de produção/resgate | `tabelas-atuais.md` › Hierarquia sugerida para dados |

## Decisões em aberto que afetam esta feature

- [ ] `[NEEDS CLARIFICATION: matriz completa de espécies por bioma, e efeitos de cada grau de
      compatibilidade (Principal, Compatível, Parcialmente compatível, Incompatível)]`
      → **Tratamento:** decidido com o dono do repo em 2026-09-14 — cada espécie resgatável
      recebe **um** bioma principal num parâmetro nomeado `biomaPrincipalPorEspecie`, com
      todos os valores rotulados **provisórios** e reunidos num único lugar ajustável. Só o
      grau `Principal` existe nesta feature; os outros três graus não são implementados.
      `sistemas-do-jogo.md` › Santuário e terrenos é explícito: a matriz não está no pacote e
      **não deve ser inventada como regra final**. O rótulo provisório é o que permite seguir.

- [ ] `[NEEDS CLARIFICATION: parâmetros de produção por espécie — quanto cada espécie rende]`
      → **Tratamento:** parâmetro `producaoBasePorEspecie`, valor provisório derivado da
      raridade da espécie (mais raro rende mais), rotulado provisório. A curva exata não é
      uma regra confirmada.

- [ ] `[NEEDS CLARIFICATION: destino de um animal resgatado quando não houver capacidade
      válida]`
      → **Tratamento:** nesta feature o animal **permanece aguardando acolhimento por tempo
      indeterminado**, que é o comportamento que o santuário já pratica. Não há descarte, não
      há recusa do resgate e não há limite de fila. `decisoes-em-aberto.md` › Santuário marca
      o destino definitivo como aberto; o que esta spec fixa é apenas o comportamento
      provisório, e ele foi escolhido por ser o único que não perde o animal do jogador.

- [ ] `[NEEDS CLARIFICATION: capacidade-base definitiva — a direção atual é 2 ou 3]`
      → **Tratamento:** não é decidido aqui. Esta feature usa a capacidade que o santuário já
      aplica, seja qual for o valor provisório vigente.

- [ ] `[NEEDS CLARIFICATION: se o bioma do terreno é escolhido, convertido ou fixo após a
      compra]`
      → **Tratamento:** não é decidido aqui. O acolhimento lê o bioma que o terreno tiver no
      momento e não o altera.

## Comportamento esperado

### Cenário: resgate bem-sucedido, terreno disponível

- **Dado** que o jogador tem um terreno de Campo vazio e com vaga
- **E** o encontro é com uma espécie cujo bioma principal é Campo
- **Quando** o arremesso resolve em `resgatado`
- **Então** o fim do encontro informa que o animal foi encaminhado ao acolhimento
- **E** o santuário passa a mostrar um animal a mais aguardando
- **E** o jogador consegue alocá-lo naquele terreno de Campo
- **E** a partir da alocação aquele animal passa a produzir como qualquer residente

### Cenário: resgate bem-sucedido, nenhum terreno compatível

- **Dado** que o jogador não tem nenhum terreno do bioma principal da espécie
- **Quando** o arremesso resolve em `resgatado`
- **Então** o animal ainda assim é acolhido e fica aguardando
- **E** o jogador vê que existe um animal esperando e que nenhum terreno atual o aceita
- **E** nada é perdido: quando o jogador comprar ou definir um terreno daquele bioma, o
  animal passa a poder ser alocado

### Cenário: resgate bem-sucedido, terreno do bioma certo mas lotado

- **Dado** que o único terreno do bioma principal da espécie está na capacidade máxima
- **Quando** o arremesso resolve em `resgatado`
- **Então** o animal fica aguardando
- **E** o jogador vê que precisa de capacidade, não de outro bioma
- **E** subir o upgrade de capacidade daquele terreno passa a permitir a alocação

### Cenário: fuga

- **Dado** um encontro em andamento
- **Quando** o arremesso resolve em `fugiu`
- **Então** nada é criado no santuário e nada muda no acolhimento

### Cenário: o jogo é fechado entre o resgate e a alocação

- **Dado** que o jogador resgatou um animal e não o alocou
- **Quando** o jogador fecha o jogo e abre de novo
- **Então** o animal continua aguardando acolhimento, com a mesma espécie

### Cenário: segundo indivíduo da mesma espécie

- **Dado** que o jogador já tem um indivíduo de uma espécie alocado num terreno com vaga
- **Quando** resgata outro indivíduo da mesma espécie
- **Então** o novo animal pode ser alocado no mesmo terreno, respeitando a capacidade

## Critérios de aceitação

- [ ] Resgatar um animal e voltar ao santuário mostra o contador de animais aguardando
      acolhimento **uma unidade maior** do que antes do encontro.
- [ ] O animal que aparece aguardando é da **mesma espécie** que foi resgatada — nome e
      símbolo conferem com os que o encontro mostrou.
- [ ] Fechar o app e reabrir mantém o animal aguardando.
- [ ] Um animal aguardando pode ser alocado a um terreno do seu bioma principal que tenha
      vaga, e depois disso ele conta como residente e contribui para a produção do terreno.
- [ ] Um animal cujo bioma principal o jogador não possui continua aguardando, e a interface
      deixa claro que falta um terreno compatível — não some nem gera erro.
- [ ] Um resultado `fugiu` não altera o acolhimento em nada.
- [ ] Todas as espécies resgatáveis têm bioma principal e produção-base definidos: nenhuma
      resgatável cai num estado em que o santuário não sabe o que fazer com ela.
- [ ] Os valores de bioma principal e de produção-base estão reunidos num único lugar
      ajustável e **rotulados como provisórios**, não espalhados pela lógica.
- [ ] Os critérios de aceitação das specs anteriores do resgate continuam passando: moita,
      arremesso, clima e hub de cestas seguem idênticos.
- [ ] Com leitor de tela ligado, o aviso de acolhimento ao fim do encontro é anunciado, e a
      alocação de um animal aguardando é alcançável.

## Fora de escopo declarado

- **Graus de compatibilidade além do principal.** `Compatível`, `Parcialmente compatível` e
  `Incompatível` dependem da matriz que não está no pacote. Ficam para uma spec futura, junto
  com o bônus de `Integridade`, que é a trilha de upgrade que os usa.
- **Reprodução.** É uma das oito trilhas e continua desabilitada.
- **Mover um indivíduo já alocado para outro terreno.** Listado como decisão em aberto.
- **XP e nível do jogador.** O passo 10 do loop principal não entra aqui.
- **Limite da fila de acolhimento e o que fazer se ela crescer demais.** Enquanto o destino
  definitivo do animal sem capacidade estiver em aberto, um limite seria invenção.
- **Tela dedicada de acolhimento.** Decidido com o dono do repo em 2026-09-14: o fluxo de
  alocação que já existe no santuário é reusado, não substituído.
