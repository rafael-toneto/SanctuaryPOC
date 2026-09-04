import Foundation

enum Rarity: String, CaseIterable, Identifiable {
    case s, a, b, c, d

    var id: String { rawValue }

    var title: String {
        switch self {
        case .s: "Lendário"
        case .a: "Épico"
        case .b: "Raro"
        case .c: "Incomum"
        case .d: "Frequente"
        }
    }

    var letter: String {
        switch self {
        case .s: "S"
        case .a: "A"
        case .b: "B"
        case .c: "C"
        case .d: "D"
        }
    }
}

enum BasketFamily: String, CaseIterable, Identifiable {
    case carnivore, herbivore, invertebrate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .carnivore: "Dieta Carnívora e Piscívora"
        case .herbivore: "Dieta Herbívora"
        case .invertebrate: "Dieta de Invertebrados"
        }
    }

    var shortTitle: String {
        switch self {
        case .carnivore: "Carnívora"
        case .herbivore: "Herbívora"
        case .invertebrate: "Invertebrados"
        }
    }

    var symbol: String {
        switch self {
        case .carnivore: "🥩"
        case .herbivore: "🍇"
        case .invertebrate: "🐛"
        }
    }

    func basketName(tier: Int) -> String {
        switch (self, tier) {
        case (.carnivore, 1): "Cesta de Carnes Secas"
        case (.carnivore, 2): "Cesta de Carnes Frescas"
        case (.carnivore, 3): "Cesta de Carnes Nobres"
        case (.herbivore, 1): "Cesta de Folhas e Frutos Secos"
        case (.herbivore, 2): "Cesta de Folhas e Frutas Frescas"
        case (.herbivore, 3): "Cesta de Folhas e Frutas Exóticas"
        case (.invertebrate, 1): "Cesta de Invertebrados Miúdos"
        case (.invertebrate, 2): "Cesta de Invertebrados Médios"
        case (.invertebrate, 3): "Cesta de Invertebrados Suculentos"
        default: ""
        }
    }
}

struct RescueSpecies: Identifiable, Equatable {
    let id: String
    let displayName: String
    let symbol: String
    let rarity: Rarity
    let family: BasketFamily
}

// ponytail: emoji é placeholder; arte por espécie substitui isto
enum RescueCatalog {
    static let all: [RescueSpecies] = [
        RescueSpecies(id: "jararaca-ilhoa", displayName: "Jararaca-ilhoa", symbol: "🐍", rarity: .s, family: .carnivore),
        RescueSpecies(id: "axolote", displayName: "Axolote", symbol: "🦎", rarity: .s, family: .invertebrate),
        RescueSpecies(id: "arara-azul", displayName: "Arara-azul", symbol: "🦜", rarity: .s, family: .herbivore),
        RescueSpecies(id: "soldadinho-do-araripe", displayName: "Soldadinho-do-Araripe", symbol: "🐦", rarity: .s, family: .herbivore),
        RescueSpecies(id: "tigre-de-sumatra", displayName: "Tigre-de-Sumatra", symbol: "🐯", rarity: .s, family: .carnivore),

        RescueSpecies(id: "peixe-mao-vermelho", displayName: "Peixe-mão-vermelho", symbol: "🐠", rarity: .a, family: .invertebrate),
        RescueSpecies(id: "tarantula-azul-de-gooty", displayName: "Tarântula-azul-de-Gooty", symbol: "🕷️", rarity: .a, family: .invertebrate),
        RescueSpecies(id: "orangotango-de-tapanuli", displayName: "Orangotango-de-Tapanuli", symbol: "🦧", rarity: .a, family: .herbivore),
        RescueSpecies(id: "rinoceronte-negro", displayName: "Rinoceronte-negro", symbol: "🦏", rarity: .a, family: .herbivore),
        RescueSpecies(id: "onca-pintada", displayName: "Onça-pintada", symbol: "🐆", rarity: .a, family: .carnivore),
        RescueSpecies(id: "jacare-do-papo-amarelo", displayName: "Jacaré-do-papo-amarelo", symbol: "🐊", rarity: .a, family: .carnivore),
        RescueSpecies(id: "lobo-guara", displayName: "Lobo-guará", symbol: "🐺", rarity: .a, family: .herbivore),
        RescueSpecies(id: "indri", displayName: "Indri", symbol: "🐒", rarity: .a, family: .herbivore),

        RescueSpecies(id: "sapo-dourado-do-panama", displayName: "Sapo-dourado-do-Panamá", symbol: "🐸", rarity: .b, family: .invertebrate),
        RescueSpecies(id: "mico-leao-dourado", displayName: "Mico-leão-dourado", symbol: "🐒", rarity: .b, family: .herbivore),
        RescueSpecies(id: "dragao-de-komodo", displayName: "Dragão-de-Komodo", symbol: "🦎", rarity: .b, family: .carnivore),
        RescueSpecies(id: "gavial", displayName: "Gavial", symbol: "🐊", rarity: .b, family: .carnivore),
        RescueSpecies(id: "elefante-da-floresta-africana", displayName: "Elefante-da-floresta-africana", symbol: "🐘", rarity: .b, family: .herbivore),
        RescueSpecies(id: "gorila-oriental", displayName: "Gorila-oriental", symbol: "🦍", rarity: .b, family: .herbivore),
        RescueSpecies(id: "pangolim-chines", displayName: "Pangolim-chinês", symbol: "🦔", rarity: .b, family: .invertebrate),
        RescueSpecies(id: "rolinha-do-planalto", displayName: "Rolinha-do-planalto", symbol: "🕊️", rarity: .b, family: .herbivore),
        RescueSpecies(id: "urso-polar", displayName: "Urso-polar", symbol: "🐻‍❄️", rarity: .b, family: .carnivore),
        RescueSpecies(id: "cavalo-marinho-do-cabo", displayName: "Cavalo-marinho-do-Cabo", symbol: "🐴", rarity: .b, family: .invertebrate),
        RescueSpecies(id: "aguia-filipina", displayName: "Águia-filipina", symbol: "🦅", rarity: .b, family: .carnivore),
        RescueSpecies(id: "leopardo-das-neves", displayName: "Leopardo-das-neves", symbol: "🐆", rarity: .b, family: .carnivore),

        RescueSpecies(id: "camelo-bactriano-selvagem", displayName: "Camelo-bactriano-selvagem", symbol: "🐫", rarity: .c, family: .herbivore),
        RescueSpecies(id: "preguica-pigmeia-de-tres-dedos", displayName: "Preguiça-pigmeia-de-três-dedos", symbol: "🦥", rarity: .c, family: .herbivore),
        RescueSpecies(id: "bicho-pau-da-ilha-lord-howe", displayName: "Bicho-pau-da-ilha-Lord-Howe", symbol: "🦗", rarity: .c, family: .herbivore),
        RescueSpecies(id: "muriqui-do-norte", displayName: "Muriqui-do-norte", symbol: "🐒", rarity: .c, family: .herbivore),
        RescueSpecies(id: "panda-vermelho", displayName: "Panda-vermelho", symbol: "🐼", rarity: .c, family: .herbivore),
        RescueSpecies(id: "salamandra-gigante-chinesa", displayName: "Salamandra-gigante-chinesa", symbol: "🦎", rarity: .c, family: .carnivore),
        RescueSpecies(id: "canguru-arboricola-de-matschie", displayName: "Canguru-arborícola-de-Matschie", symbol: "🦘", rarity: .c, family: .herbivore),
        RescueSpecies(id: "boto-cor-de-rosa", displayName: "Boto-cor-de-rosa", symbol: "🐬", rarity: .c, family: .carnivore),
        RescueSpecies(id: "peixe-boi", displayName: "Peixe-boi", symbol: "🐋", rarity: .c, family: .herbivore),
        RescueSpecies(id: "ave-secretaria", displayName: "Ave-secretária", symbol: "🦅", rarity: .c, family: .carnivore),
        RescueSpecies(id: "peixe-serra-de-dentes-grandes", displayName: "Peixe-serra-de-dentes-grandes", symbol: "🐟", rarity: .c, family: .carnivore),
        RescueSpecies(id: "esturjao-beluga", displayName: "Esturjão-beluga", symbol: "🐟", rarity: .c, family: .carnivore),
        RescueSpecies(id: "ra-roxa-indiana", displayName: "Rã-roxa-indiana", symbol: "🐸", rarity: .c, family: .invertebrate),
        RescueSpecies(id: "ariranha", displayName: "Ariranha", symbol: "🦦", rarity: .c, family: .carnivore),
        RescueSpecies(id: "tubarao-martelo-gigante", displayName: "Tubarão-martelo-gigante", symbol: "🦈", rarity: .c, family: .carnivore),
        RescueSpecies(id: "ocapi", displayName: "Ocapi", symbol: "🦓", rarity: .c, family: .herbivore),

        RescueSpecies(id: "pinguim-imperador", displayName: "Pinguim-imperador", symbol: "🐧", rarity: .d, family: .carnivore),
        RescueSpecies(id: "lontra-marinha", displayName: "Lontra-marinha", symbol: "🦦", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "tamandua-bandeira", displayName: "Tamanduá-bandeira", symbol: "🐾", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "caranguejo-dos-coqueiros", displayName: "Caranguejo-dos-coqueiros", symbol: "🦀", rarity: .d, family: .herbivore),
        RescueSpecies(id: "addax", displayName: "Addax", symbol: "🐐", rarity: .d, family: .herbivore),
        RescueSpecies(id: "diabo-da-tasmania", displayName: "Diabo-da-Tasmânia", symbol: "😈", rarity: .d, family: .carnivore),
        RescueSpecies(id: "kakapo", displayName: "Kakapo", symbol: "🦜", rarity: .d, family: .herbivore),
        RescueSpecies(id: "iguana-marinha", displayName: "Iguana-marinha", symbol: "🦎", rarity: .d, family: .herbivore),
        RescueSpecies(id: "anta-malaia", displayName: "Anta-malaia", symbol: "🐖", rarity: .d, family: .herbivore),
        RescueSpecies(id: "nautilo-de-camara", displayName: "Náutilo-de-câmara", symbol: "🐚", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "harpia", displayName: "Harpia", symbol: "🦅", rarity: .d, family: .carnivore),
        RescueSpecies(id: "quokka", displayName: "Quokka", symbol: "🐹", rarity: .d, family: .herbivore),
        RescueSpecies(id: "manta-oceanica-gigante", displayName: "Manta-oceânica-gigante", symbol: "🦈", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "bico-de-sapato", displayName: "Bico-de-sapato", symbol: "🦩", rarity: .d, family: .carnivore),
        RescueSpecies(id: "lince-iberico", displayName: "Lince-ibérico", symbol: "🐈", rarity: .d, family: .carnivore),
        RescueSpecies(id: "urso-malaio", displayName: "Urso-malaio", symbol: "🐻", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "tatu-canastra", displayName: "Tatu-canastra", symbol: "🦔", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "baleia-azul", displayName: "Baleia-azul", symbol: "🐋", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "tartaruga-de-couro", displayName: "Tartaruga-de-couro", symbol: "🐢", rarity: .d, family: .invertebrate),
        RescueSpecies(id: "dugongo", displayName: "Dugongo", symbol: "🐋", rarity: .d, family: .herbivore)
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

// Todo número abaixo é provisório — ver `specs/001-minigame-de-resgate/spec.md`
// (seção "Parâmetros provisórios" / decisões em aberto de fórmula de resgate).
struct RescueBalance: Equatable {
    var baseChance: [Rarity: Double]
    var tierMultiplier: [Int: Double]
    var coreMultiplier: Double
    var ringMultiplier: Double
    var upgradeMultiplier: Double
    var minChance: Double
    var maxChance: Double
    var fleeChance: [Rarity: Double]
    var startingStock: [Int: Int]
    var hitRadiusBase: Double
    var hitRadiusPerLevel: Double
    var coreRadiusRatio: Double
    var steadyHandLevel: Int
    var throwSensitivity: Double
    var throwDuration: Double

    static let poc = RescueBalance(
        baseChance: [.s: 0.05, .a: 0.10, .b: 0.18, .c: 0.30, .d: 0.45],
        tierMultiplier: [1: 1.0, 2: 1.5, 3: 2.2],
        coreMultiplier: 1.8,
        ringMultiplier: 1.0,
        upgradeMultiplier: 1.0,
        minChance: 0.03,
        maxChance: 0.90,
        fleeChance: [.s: 0.35, .a: 0.28, .b: 0.20, .c: 0.14, .d: 0.08],
        startingStock: [1: 5, 2: 3, 3: 2],
        hitRadiusBase: 82,
        hitRadiusPerLevel: 0.08,
        coreRadiusRatio: 0.40,
        steadyHandLevel: 1,
        throwSensitivity: 2.6,
        throwDuration: 0.42
    )

    var hitRadius: Double { hitRadiusBase * (1 + Double(steadyHandLevel - 1) * hitRadiusPerLevel) }
    var coreRadius: Double { hitRadius * coreRadiusRatio }
}

enum ThrowPrecision {
    case core, ring, miss
}

enum AttemptOutcome {
    case rescued, stayed, fled
}

enum RescueEngine {
    static func isCompatible(_ family: BasketFamily, with species: RescueSpecies) -> Bool {
        family == species.family
    }

    static func precision(distance: Double, balance: RescueBalance) -> ThrowPrecision {
        if distance <= balance.coreRadius {
            return .core
        } else if distance <= balance.hitRadius {
            return .ring
        } else {
            return .miss
        }
    }

    static func rescueChance(
        species: RescueSpecies,
        tier: Int,
        precision: ThrowPrecision,
        balance: RescueBalance
    ) -> Double {
        guard precision != .miss else { return 0 }

        let precisionMultiplier = precision == .core ? balance.coreMultiplier : balance.ringMultiplier
        let base = balance.baseChance[species.rarity, default: 0]
        let tierMult = balance.tierMultiplier[tier, default: 1]
        let raw = base * tierMult * precisionMultiplier * balance.upgradeMultiplier
        return min(balance.maxChance, max(balance.minChance, raw))
    }

    static func resolve(
        species: RescueSpecies,
        tier: Int,
        precision: ThrowPrecision,
        balance: RescueBalance,
        using generator: inout some RandomNumberGenerator
    ) -> AttemptOutcome {
        let chance = rescueChance(species: species, tier: tier, precision: precision, balance: balance)
        if Double.random(in: 0..<1, using: &generator) < chance {
            return .rescued
        }

        let flee = balance.fleeChance[species.rarity, default: 0]
        return Double.random(in: 0..<1, using: &generator) < flee ? .fled : .stayed
    }
}
