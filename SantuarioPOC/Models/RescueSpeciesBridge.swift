import Foundation

// Bioma principal e rendimento-base são valores PROVISÓRIOS — a matriz canônica de
// compatibilidade espécie×bioma ainda não existe. Ver
// `decisoes-em-aberto.md` › Santuário — "matriz completa de espécies por bioma e efeitos
// de cada grau de compatibilidade". O bioma abaixo foi escolhido pelo habitat real do
// animal (nunca pela família de dieta), e o rendimento vem só da raridade.
enum RescueSpeciesBridge {

    /// Uma entrada por espécie de `RescueCatalog.all`, escolhida pelo habitat real do
    /// animal — não pela dieta/família de cesta.
    static let principalBiome: [String: Biome] = [
        // S
        "jararaca-ilhoa": .forest,
        "axolote": .aquatic,
        "arara-azul": .forest,
        "soldadinho-do-araripe": .forest,
        "tigre-de-sumatra": .forest,

        // A
        "peixe-mao-vermelho": .aquatic,
        "tarantula-azul-de-gooty": .forest,
        "orangotango-de-tapanuli": .forest,
        "rinoceronte-negro": .grassland,
        "onca-pintada": .forest,
        "jacare-do-papo-amarelo": .wetland,
        "lobo-guara": .grassland,
        "indri": .forest,

        // B
        "sapo-dourado-do-panama": .wetland,
        "mico-leao-dourado": .forest,
        "dragao-de-komodo": .grassland,
        "gavial": .aquatic,
        "elefante-da-floresta-africana": .forest,
        "gorila-oriental": .forest,
        "pangolim-chines": .forest,
        "rolinha-do-planalto": .grassland,
        "urso-polar": .aquatic,
        "cavalo-marinho-do-cabo": .aquatic,
        "aguia-filipina": .forest,
        "leopardo-das-neves": .grassland,

        // C
        "camelo-bactriano-selvagem": .grassland,
        "preguica-pigmeia-de-tres-dedos": .wetland,
        "bicho-pau-da-ilha-lord-howe": .forest,
        "muriqui-do-norte": .forest,
        "panda-vermelho": .forest,
        "salamandra-gigante-chinesa": .aquatic,
        "canguru-arboricola-de-matschie": .forest,
        "boto-cor-de-rosa": .aquatic,
        "peixe-boi": .aquatic,
        "ave-secretaria": .grassland,
        "peixe-serra-de-dentes-grandes": .aquatic,
        "esturjao-beluga": .aquatic,
        "ra-roxa-indiana": .wetland,
        "ariranha": .aquatic,
        "tubarao-martelo-gigante": .aquatic,
        "ocapi": .forest,

        // D
        "pinguim-imperador": .aquatic,
        "lontra-marinha": .aquatic,
        "tamandua-bandeira": .grassland,
        "caranguejo-dos-coqueiros": .forest,
        "addax": .grassland,
        "diabo-da-tasmania": .forest,
        "kakapo": .forest,
        "iguana-marinha": .aquatic,
        "anta-malaia": .forest,
        "nautilo-de-camara": .aquatic,
        "harpia": .forest,
        "quokka": .forest,
        "manta-oceanica-gigante": .aquatic,
        "bico-de-sapato": .wetland,
        "lince-iberico": .forest,
        "urso-malaio": .forest,
        "tatu-canastra": .grassland,
        "baleia-azul": .aquatic,
        "tartaruga-de-couro": .aquatic,
        "dugongo": .aquatic
    ]

    /// Valor exato de `plan.md` › Parâmetros provisórios. Não altere sem revisar o plan.
    static let yieldByRarity: [Rarity: Double] = [
        .s: 1.5,
        .a: 1.35,
        .b: 1.2,
        .c: 1.1,
        .d: 1.0
    ]

    static let all: [SpeciesDefinition] = RescueCatalog.all.map { species in
        guard let biome = principalBiome[species.id] else {
            preconditionFailure("RescueSpeciesBridge.principalBiome não tem entrada para '\(species.id)'")
        }
        guard let yield = yieldByRarity[species.rarity] else {
            preconditionFailure("RescueSpeciesBridge.yieldByRarity não tem entrada para raridade '\(species.rarity)'")
        }
        return SpeciesDefinition(
            id: species.id,
            displayName: species.displayName,
            symbol: species.symbol,
            principalBiome: biome,
            baseYield: yield
        )
    }
}
