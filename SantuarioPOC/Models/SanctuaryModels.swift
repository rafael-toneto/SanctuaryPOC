import Foundation

enum Biome: String, CaseIterable, Codable, Identifiable {
    case aquatic
    case wetland
    case forest
    case grassland

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aquatic: "Aquático"
        case .wetland: "Úmido"
        case .forest: "Floresta"
        case .grassland: "Campo"
        }
    }

    var subtitle: String {
        switch self {
        case .aquatic: "Águas protegidas"
        case .wetland: "Margens e áreas alagadas"
        case .forest: "Copas e refúgios verdes"
        case .grassland: "Campos abertos e ensolarados"
        }
    }
}

enum TerrainUpgradeTrack: Int, CaseIterable, Codable, Identifiable {
    case baseProduction = 1
    case generationInterval = 2
    case offlineEfficiency = 3
    case doubleCollection = 4
    case capacity = 5
    case reproduction = 6
    case principalBiome = 7
    case offlineInterval = 8

    var id: Int { rawValue }

    var effectDescription: String {
        switch self {
        case .baseProduction:
            "Aumenta a produção-base de cada animal."
        case .generationInterval:
            "Reduz o intervalo de cada geração de recurso."
        case .offlineEfficiency:
            "Aumenta a eficiência da produção offline."
        case .doubleCollection:
            "Aumenta a chance de uma produção dobrada."
        case .capacity:
            "Aumenta a capacidade para indivíduos da mesma espécie."
        case .reproduction:
            "Aumenta a taxa de reprodução do terreno."
        case .principalBiome:
            "Aumenta o bônus quando o bioma é Principal para a espécie."
        case .offlineInterval:
            "Reduz o intervalo de geração durante o período offline."
        }
    }

    var isImplementedInPOC: Bool {
        switch self {
        case .baseProduction, .generationInterval, .offlineEfficiency, .capacity, .offlineInterval:
            true
        case .doubleCollection, .reproduction, .principalBiome:
            false
        }
    }

    var pendingReason: String? {
        switch self {
        case .doubleCollection:
            "Aguardando a regra de probabilidade."
        case .reproduction:
            "Aguardando regras e limites de reprodução."
        case .principalBiome:
            "Aguardando a matriz canônica de compatibilidade."
        default:
            nil
        }
    }

    func name(for biome: Biome) -> String {
        switch (self, biome) {
        case (.baseProduction, .aquatic): "Produtividade Aquática"
        case (.baseProduction, .wetland): "Fertilidade dos Sedimentos"
        case (.baseProduction, .forest): "Ciclagem de Nutrientes"
        case (.baseProduction, .grassland): "Fixação de Nitrogênio"

        case (.generationInterval, .aquatic): "Oxigenação da Água"
        case (.generationInterval, .wetland): "Circulação Hídrica"
        case (.generationInterval, .forest): "Eficiência Radicular"
        case (.generationInterval, .grassland): "Aeração do Solo"

        case (.offlineEfficiency, .aquatic): "Estabilidade da Água"
        case (.offlineEfficiency, .wetland): "Retenção de Nutrientes"
        case (.offlineEfficiency, .forest): "Reserva de Biomassa"
        case (.offlineEfficiency, .grassland): "Retenção Hídrica"

        case (.doubleCollection, .aquatic): "Produtividade Planctônica"
        case (.doubleCollection, .wetland): "Pulso de Nutrientes"
        case (.doubleCollection, .forest): "Frutificação Sazonal"
        case (.doubleCollection, .grassland): "Floração Sazonal"

        case (.capacity, .aquatic): "Complexidade Aquática"
        case (.capacity, .wetland): "Diversidade das Margens"
        case (.capacity, .forest): "Estratos da Floresta"
        case (.capacity, .grassland): "Diversidade de Microhabitats"

        case (.reproduction, .aquatic): "Zonas Reprodutivas Aquáticas"
        case (.reproduction, .wetland): "Berçários Naturais"
        case (.reproduction, .forest): "Refúgios Reprodutivos"
        case (.reproduction, .grassland): "Zonas Reprodutivas"

        case (.principalBiome, .aquatic): "Integridade Aquática"
        case (.principalBiome, .wetland): "Integridade Palustre-Costeira"
        case (.principalBiome, .forest): "Integridade Florestal"
        case (.principalBiome, .grassland): "Integridade Campestre"

        case (.offlineInterval, .aquatic): "Circulação Aquática"
        case (.offlineInterval, .wetland): "Renovação Hidrológica"
        case (.offlineInterval, .forest): "Regeneração Florestal"
        case (.offlineInterval, .grassland): "Regeneração Campestre"
        }
    }
}

struct SpeciesDefinition: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let symbol: String
    let principalBiome: Biome
    let baseYield: Double
}

enum DemoSpecies {
    static let all: [SpeciesDefinition] = [
        SpeciesDefinition(
            id: "lobo-guara-demo",
            displayName: "Lobo-guará",
            symbol: "🐺",
            principalBiome: .grassland,
            baseYield: 1.0
        ),
        SpeciesDefinition(
            id: "tamandua-demo",
            displayName: "Tamanduá-bandeira",
            symbol: "🐾",
            principalBiome: .grassland,
            baseYield: 1.15
        ),
        SpeciesDefinition(
            id: "mico-leao-demo",
            displayName: "Mico-leão-dourado",
            symbol: "🐒",
            principalBiome: .forest,
            baseYield: 1.1
        ),
        SpeciesDefinition(
            id: "jacare-demo",
            displayName: "Jacaré-de-papo-amarelo",
            symbol: "🐊",
            principalBiome: .wetland,
            baseYield: 1.2
        ),
        SpeciesDefinition(
            id: "peixe-boi-demo",
            displayName: "Peixe-boi-da-amazônia",
            symbol: "🐋",
            principalBiome: .aquatic,
            baseYield: 1.3
        )
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

enum AnimalLocation: Codable, Equatable {
    case waiting
    case terrain(UUID)

    private enum CodingKeys: String, CodingKey {
        case kind
        case terrainID
    }

    private enum Kind: String, Codable {
        case waiting
        case terrain
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .waiting:
            self = .waiting
        case .terrain:
            self = .terrain(try container.decode(UUID.self, forKey: .terrainID))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .waiting:
            try container.encode(Kind.waiting, forKey: .kind)
        case let .terrain(terrainID):
            try container.encode(Kind.terrain, forKey: .kind)
            try container.encode(terrainID, forKey: .terrainID)
        }
    }
}

struct AnimalInstance: Identifiable, Codable, Equatable {
    let id: UUID
    let speciesID: String
    var location: AnimalLocation
}

struct Terrain: Identifiable, Codable, Equatable {
    let id: UUID
    let biome: Biome
    var isUnlocked: Bool
    var storedResources: Double
    var lastSettledAt: Date
    var upgradeLevels: [TerrainUpgradeTrack: Int]
    // Optional keeps states saved before the algorithmic map backwards-compatible.
    // SanctuaryStore assigns a stable slot while normalizing older saves.
    var mapSlot: Int? = nil

    func level(of track: TerrainUpgradeTrack) -> Int {
        upgradeLevels[track, default: 0]
    }

    mutating func increaseLevel(of track: TerrainUpgradeTrack) {
        upgradeLevels[track] = min(10, level(of: track) + 1)
    }
}

struct SanctuaryState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var wallet: Double
    var terrains: [Terrain]
    var animals: [AnimalInstance]

    static func demo(at now: Date, config: BalanceConfig = .poc) -> SanctuaryState {
        let grasslandID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let forestID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let wetlandID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        let aquaticID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!

        let terrains = [
            Terrain(
                id: grasslandID,
                biome: .grassland,
                isUnlocked: true,
                storedResources: 18,
                lastSettledAt: now,
                upgradeLevels: [:],
                mapSlot: 0
            ),
            Terrain(
                id: forestID,
                biome: .forest,
                isUnlocked: true,
                storedResources: 0,
                lastSettledAt: now,
                upgradeLevels: [:],
                mapSlot: 1
            ),
            Terrain(
                id: wetlandID,
                biome: .wetland,
                isUnlocked: true,
                storedResources: 9,
                lastSettledAt: now,
                upgradeLevels: [:],
                mapSlot: 2
            ),
            Terrain(
                id: aquaticID,
                biome: .aquatic,
                isUnlocked: false,
                storedResources: 0,
                lastSettledAt: now,
                upgradeLevels: [:],
                mapSlot: 3
            )
        ]

        let animals = [
            // Grassland (4 animals)
            AnimalInstance(id: UUID(), speciesID: "lobo-guara-demo", location: .terrain(grasslandID)),
            AnimalInstance(id: UUID(), speciesID: "lobo-guara-demo", location: .terrain(grasslandID)),
            AnimalInstance(id: UUID(), speciesID: "lobo-guara-demo", location: .terrain(grasslandID)),
            AnimalInstance(id: UUID(), speciesID: "lobo-guara-demo", location: .terrain(grasslandID)),

            // Forest (4 animals)
            AnimalInstance(id: UUID(), speciesID: "mico-leao-demo", location: .terrain(forestID)),
            AnimalInstance(id: UUID(), speciesID: "mico-leao-demo", location: .terrain(forestID)),
            AnimalInstance(id: UUID(), speciesID: "mico-leao-demo", location: .terrain(forestID)),
            AnimalInstance(id: UUID(), speciesID: "mico-leao-demo", location: .terrain(forestID)),

            // Wetland (4 animals)
            AnimalInstance(id: UUID(), speciesID: "jacare-demo", location: .terrain(wetlandID)),
            AnimalInstance(id: UUID(), speciesID: "jacare-demo", location: .terrain(wetlandID)),
            AnimalInstance(id: UUID(), speciesID: "jacare-demo", location: .terrain(wetlandID)),
            AnimalInstance(id: UUID(), speciesID: "jacare-demo", location: .terrain(wetlandID))
        ]

        return SanctuaryState(
            schemaVersion: currentSchemaVersion,
            wallet: config.startingWallet,
            terrains: terrains,
            animals: animals
        )
    }
}

struct BalanceConfig: Equatable {
    let baseCapacity: Int
    let baseGenerationInterval: TimeInterval
    let offlineLimit: TimeInterval
    let baseOfflineEfficiency: Double
    let productionBonusPerLevel: Double
    let intervalReductionPerLevel: Double
    let offlineEfficiencyPerLevel: Double
    let offlineIntervalReductionPerLevel: Double
    let capacityBonusPerLevel: Int
    let startingWallet: Double
    let terrainPurchaseCost: Double

    static let poc = BalanceConfig(
        baseCapacity: 3,
        baseGenerationInterval: 10,
        offlineLimit: 4 * 60 * 60,
        baseOfflineEfficiency: 0.35,
        productionBonusPerLevel: 0.15,
        intervalReductionPerLevel: 0.06,
        offlineEfficiencyPerLevel: 0.08,
        offlineIntervalReductionPerLevel: 0.05,
        capacityBonusPerLevel: 1,
        startingWallet: 160,
        terrainPurchaseCost: 120
    )

    func capacity(for terrain: Terrain) -> Int {
        baseCapacity + terrain.level(of: .capacity) * capacityBonusPerLevel
    }

    func interval(for terrain: Terrain, mode: ProductionMode) -> TimeInterval {
        let generalFactor = max(0.35, 1 - Double(terrain.level(of: .generationInterval)) * intervalReductionPerLevel)
        let offlineFactor: Double
        switch mode {
        case .online:
            offlineFactor = 1
        case .offline:
            offlineFactor = max(0.4, 1 - Double(terrain.level(of: .offlineInterval)) * offlineIntervalReductionPerLevel)
        }
        return baseGenerationInterval * generalFactor * offlineFactor
    }

    func productionMultiplier(for terrain: Terrain) -> Double {
        1 + Double(terrain.level(of: .baseProduction)) * productionBonusPerLevel
    }

    func offlineEfficiency(for terrain: Terrain) -> Double {
        min(1, baseOfflineEfficiency + Double(terrain.level(of: .offlineEfficiency)) * offlineEfficiencyPerLevel)
    }

    func upgradeCost(for track: TerrainUpgradeTrack, currentLevel: Int) -> Double {
        let nextLevel = currentLevel + 1
        return Double(25 + track.rawValue * 5 + nextLevel * 20)
    }
}

enum ProductionMode {
    case online
    case offline
}

enum ProductionEngine {
    static func productionRate(
        terrain: Terrain,
        residents: [AnimalInstance],
        speciesByID: [String: SpeciesDefinition] = DemoSpecies.byID,
        mode: ProductionMode,
        config: BalanceConfig = .poc
    ) -> Double {
        guard terrain.isUnlocked, !residents.isEmpty else { return 0 }

        let baseYield = residents.reduce(0.0) { partial, animal in
            partial + (speciesByID[animal.speciesID]?.baseYield ?? 0)
        }
        let interval = config.interval(for: terrain, mode: mode)
        guard interval > 0 else { return 0 }

        var rate = baseYield * config.productionMultiplier(for: terrain) / interval
        if mode == .offline {
            rate *= config.offlineEfficiency(for: terrain)
        }
        return rate
    }

    static func accruedResources(
        terrain: Terrain,
        residents: [AnimalInstance],
        speciesByID: [String: SpeciesDefinition] = DemoSpecies.byID,
        elapsed: TimeInterval,
        mode: ProductionMode,
        config: BalanceConfig = .poc
    ) -> Double {
        let safeElapsed = max(0, elapsed)
        let effectiveElapsed: TimeInterval
        switch mode {
        case .online:
            effectiveElapsed = safeElapsed
        case .offline:
            effectiveElapsed = min(safeElapsed, config.offlineLimit)
        }

        return productionRate(
            terrain: terrain,
            residents: residents,
            speciesByID: speciesByID,
            mode: mode,
            config: config
        ) * effectiveElapsed
    }
}
