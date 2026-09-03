# AGENTS.md

Instruções para qualquer agente de IA trabalhando neste repo. Este arquivo é a **fonte única**:
Codex, Antigravity e Gemini CLI o leem nativamente; Claude Code o importa via `CLAUDE.md`.

Não crie `GEMINI.md` nem duplique estas regras em outro arquivo. Uma cópia a sincronizar é
uma cópia que vai divergir.

---

## O projeto

Jogo mobile de exploração geolocalizada sobre animais ameaçados de extinção. O jogador
caminha no mundo real, encontra um animal, lança uma cesta de alimento adequada à dieta da
espécie, e o resgate resolve direto em **resgatado** ou **fugiu**. Animais resgatados vão
para um santuário de terrenos compráveis, onde geram a moeda principal passivamente.

**Fonte de verdade do design:** a skill `endangered-animal-rescue-game`
(`SKILL.md` + `references/sistemas-do-jogo.md`, `tabelas-atuais.md`, `direcao-visual.md`,
`decisoes-em-aberto.md`).

> ⚠️ Hoje a skill vive apenas em `~/Downloads/endangered-animal-rescue-game/` na máquina do
> dono do repo. Se você não tem acesso a ela, **pare e peça** — não deduza as regras do
> código nem das imagens.

## Estado atual do repo

`SantuarioPOC` é uma **POC descartável** em SwiftUI/iOS 17+ (~4.100 linhas) que valida só o
ciclo de gestão do santuário. Ela é referência validada, não a arquitetura final do jogo.

**O que a POC cobre:** mapa 2D do santuário arrastável, 4 biomas, uma espécie por terreno com
N indivíduos até a capacidade, produção passiva online, acúmulo offline (teto 4 h, 35 % de
eficiência), coleta por terreno e geral, compra/expansão de lote, escolha de bioma,
persistência JSON em `UserDefaults`, e um laboratório para acelerar o relógio.

**O que a POC não cobre:** login, mapa de exploração, geolocalização, passos, spawns,
encontro, resgate, cestas, inventário, XP, upgrades do jogador, backend, reprodução.

**Das 8 trilhas de upgrade de terreno, 3 estão desabilitadas** — coleta dobrada, reprodução e
bônus de bioma Principal — porque dependem de decisões ainda em aberto. Isso é intencional.

Mapa do código:

| Camada | Onde | Papel |
| --- | --- | --- |
| Regras puras | `SantuarioPOC/Models/SanctuaryModels.swift` | `Biome`, `Terrain`, `AnimalInstance`, `BalanceConfig`, `ProductionEngine` |
| Estado | `SantuarioPOC/Store/SanctuaryStore.swift` | `@MainActor ObservableObject`; ações retornam `Result<_, SanctuaryActionError>` |
| UI | `SantuarioPOC/Views/` | SwiftUI puro (`SanctuaryMapView.swift` sozinho tem ~960 linhas) |

Todos os números provisórios estão isolados em `BalanceConfig.poc`. Mantenha assim.

## Fluxo de trabalho: SDD

Toda feature passa por quatro etapas, nesta ordem. Ver `.specify/constitution.md` para as
regras invioláveis.

| Etapa | Comando | Produz | Quem executa |
| --- | --- | --- | --- |
| 1 | `/specify <feature>` | `specs/NNN-slug/spec.md` — o quê e por quê, sem tecnologia | orquestrador |
| 2 | `/plan` | `specs/NNN-slug/plan.md` — como, com a stack | orquestrador |
| 3 | `/tasks` | `specs/NNN-slug/tasks.md` — tasks `T001…` | orquestrador |
| 4 | `/implement` | código | **sub-agente** |

Cada etapa para e espera aprovação do dono do repo antes da próxima.

O corpo de cada comando vive uma vez em `.specify/workflows/`. Os arquivos em
`.claude/commands/`, `.codex/prompts/` e `.agents/workflows/` são só ponteiros.

**Convenção de pastas:** `specs/NNN-slug/`, com `NNN` sequencial a partir de `001` e slug em
kebab-case, em português. Ex.: `specs/001-encontro-e-resgate/`.

## Regra dos modelos

Dois papéis, dois modelos:

- **Orquestrador** — modelo mais capaz, raciocínio **alto**. Escreve spec/plan/tasks, revisa
  diffs, integra. **Não escreve código de feature.**
- **Implementador** — modelo econômico, raciocínio **médio**. Uma task por vez.

Equivalências por ferramenta:

| Ferramenta | Orquestrador | Implementador | Como é aplicado |
| --- | --- | --- | --- |
| Claude Code | `opus`, effort `high` | `sonnet`, effort `medium` | `.claude/agents/task-implementer.md` — por configuração |
| Codex | `sol`, reasoning `high` | `luna`, reasoning `medium` | Por invocação — ver abaixo |
| Antigravity | modelo mais capaz da versão | modelo econômico da versão | `.agents/agents/task-implementer/agent.md` — por configuração |

### Codex

Codex não tem configuração de sub-agente. A separação é feita por **sessão**: mantenha a
sessão de spec separada da sessão de código, e escolha o modelo na invocação.

```sh
codex -m sol  -c model_reasoning_effort=high    # spec, plan, tasks, revisão
codex -m luna -c model_reasoning_effort=medium  # implementar uma task
```

O mesmo par pode ser fixado em `~/.codex/config.toml` como perfis, se preferir não repetir
as flags.

Não finja paridade: no Codex a regra depende de você escolher o modelo certo ao abrir a
sessão, não da ferramenta impor.

## Convenções de commit

**Commits não levam assinatura de modelo.** Nada de `Co-Authored-By: <modelo>`, nada de
rodapé "🤖 Generated with", nada de link de sessão. A mensagem descreve só a mudança.

Isso vale mesmo quando a sua ferramenta injeta essa atribuição por padrão. Remova antes de
commitar.

Mensagens em português, imperativo, minúsculas. Ex.: `adiciona sheet de escolha de bioma`.

## Testes não são requisito

Nenhuma spec, plan ou task exige teste unitário ou de UI. A verificação de uma task é um
**critério de aceitação observável** — algo conferível rodando o app.

Escreva teste apenas quando uma task pedir explicitamente. A suíte em `SantuarioPOCTests/`
é anterior a essa decisão: não a remova, só não exija novos.

## rtk

`rtk` é um proxy de CLI que corta 60–90 % dos tokens em operações de desenvolvimento.

- **Claude Code** — já está ligado por hook global. Não faça nada.
- **Codex / Antigravity / outros** — prefixe os comandos manualmente: `rtk git status`,
  `rtk git diff`, `rtk grep ...`. Verifique com `rtk --version` e `rtk gain`.

## Como escrever código aqui

Pare no primeiro degrau que resolver o problema:

1. isso precisa existir? Necessidade especulativa = não construa;
2. já existe no repo? Reuse — reimplementar o que está dois arquivos ao lado é o erro
   mais comum;
3. a biblioteca padrão resolve? Use;
4. um recurso nativo da plataforma resolve? Use;
5. uma dependência já instalada resolve? Nunca adicione uma nova para o que cabe em poucas
   linhas;
6. cabe em uma linha? Uma linha;
7. só então: o mínimo que funciona.

Sem interface com uma implementação. Sem factory para um produto. Sem config para valor que
nunca muda. Sem scaffolding "para depois". Deletar vence adicionar. Chato vence esperto.

Mas: **nunca seja preguiçoso em entender o problema.** Leia o fluxo inteiro antes de escolher
o degrau. Um diff pequeno no lugar errado não é economia, é um segundo bug.

Atalho deliberado com teto conhecido leva comentário nomeando o teto e o upgrade:

```swift
// ponytail: busca linear no catálogo; indexar se passar de ~200 espécies
```

Nunca simplifique fora: validação em fronteira de confiança, tratamento de erro que evita
perda de dado, segurança, acessibilidade básica, ou qualquer coisa pedida explicitamente.

## Verificar a build

```sh
xcodebuild -project "SantuarioPOC.xcodeproj" -scheme SantuarioPOC \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO build
```

Trocar `build` por `test` roda a suíte existente.

> O `README.md` ainda traz esse comando com um prefixo `DEVELOPER_DIR=".../Xcode 26.app/..."`.
> Isso está desatualizado: o Xcode desta máquina está em `/Applications/Xcode.app` e o
> `xcode-select` já aponta para lá. Se o comando do README falhar com
> `missing DEVELOPER_DIR path`, use a forma acima.
