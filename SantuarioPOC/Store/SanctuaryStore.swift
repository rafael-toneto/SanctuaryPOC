import Combine
import Foundation

struct SanctuaryNotice: Identifiable, Equatable {
    enum Kind {
        case success
        case warning
    }

    let id = UUID()
    let message: String
    let kind: Kind
}

enum SanctuaryActionError: Error, Equatable, LocalizedError {
    case terrainLocked
    case terrainAlreadyUnlocked
    case incompatibleBiome
    case differentSpecies
    case noWaitingAnimal
    case terrainFull
    case noResident
    case insufficientResources(missing: Int)
    case upgradePending
    case maximumLevel
    case mapSlotAlreadyDefined

    var errorDescription: String? {
        switch self {
        case .terrainLocked:
            "Este terreno ainda precisa ser expandido."
        case .terrainAlreadyUnlocked:
            "Este terreno já está disponível."
        case .incompatibleBiome:
            "Na POC, esta espécie só pode usar seu bioma Principal."
        case .differentSpecies:
            "Um terreno só pode acolher uma espécie por vez."
        case .noWaitingAnimal:
            "Não há outro indivíduo dessa espécie aguardando terreno."
        case .terrainFull:
            "A capacidade deste terreno foi atingida."
        case .noResident:
            "Não há animais para devolver à Central de acolhimento."
        case let .insufficientResources(missing):
            "Faltam \(missing) recursos."
        case .upgradePending:
            "Esta melhoria depende de uma regra ainda em definição."
        case .maximumLevel:
            "Esta melhoria já chegou ao nível 10."
        case .mapSlotAlreadyDefined:
            "Este espaço do mapa já possui um terreno."
        }
    }
}

struct SpeciesSummary: Identifiable {
    let species: SpeciesDefinition
    let waitingCount: Int
    let accommodatedCount: Int

    var id: String { species.id }
}

@MainActor
final class SanctuaryStore: ObservableObject {
    @Published private(set) var state: SanctuaryState
    @Published private(set) var notice: SanctuaryNotice?
    @Published var demoSpeed: Double = 1

    let config: BalanceConfig
    let speciesCatalog: [SpeciesDefinition]

    private let persistence: SanctuaryPersisting
    private var isActive = false
    private var ticksSinceSave = 0

    init(
        persistence: SanctuaryPersisting = UserDefaultsSanctuaryPersistence(),
        config: BalanceConfig = .poc,
        speciesCatalog: [SpeciesDefinition] = DemoSpecies.all,
        now: Date = .now
    ) {
        self.persistence = persistence
        self.config = config
        self.speciesCatalog = speciesCatalog

        if let saved = persistence.load(), saved.schemaVersion == SanctuaryState.currentSchemaVersion {
            var restored = saved
            let catalogByID = Dictionary(uniqueKeysWithValues: speciesCatalog.map { ($0.id, $0) })
            Self.normalize(
                state: &restored,
                at: now,
                config: config,
                speciesByID: catalogByID
            )
            Self.settleAll(
                state: &restored,
                at: now,
                mode: .offline,
                elapsedScale: 1,
                config: config,
                speciesByID: catalogByID
            )
            state = restored
        } else {
            state = SanctuaryState.demo(at: now, config: config)
        }
        persistence.save(state)
    }

    var totalPendingResources: Double {
        state.terrains.reduce(0) { $0 + $1.storedResources }
    }

    var totalCollectableResources: Int {
        state.terrains.reduce(0) { $0 + Int(floor($1.storedResources)) }
    }

    var waitingAnimalCount: Int {
        state.animals.filter { $0.location == .waiting }.count
    }

    var unlockedTerrainCount: Int {
        state.terrains.filter(\.isUnlocked).count
    }

    var accommodatedAnimalCount: Int {
        state.animals.count - waitingAnimalCount
    }

    var speciesSummaries: [SpeciesSummary] {
        speciesCatalog.map { species in
            SpeciesSummary(
                species: species,
                waitingCount: state.animals.filter {
                    $0.speciesID == species.id && $0.location == .waiting
                }.count,
                accommodatedCount: state.animals.filter {
                    guard $0.speciesID == species.id else { return false }
                    if case .terrain = $0.location { return true }
                    return false
                }.count
            )
        }
    }

    func terrain(withID id: UUID) -> Terrain? {
        state.terrains.first { $0.id == id }
    }

    func species(withID id: String) -> SpeciesDefinition? {
        speciesCatalog.first { $0.id == id }
    }

    func residents(in terrainID: UUID) -> [AnimalInstance] {
        state.animals.filter { $0.location == .terrain(terrainID) }
    }

    func residentSpecies(in terrainID: UUID) -> SpeciesDefinition? {
        guard let speciesID = residents(in: terrainID).first?.speciesID else { return nil }
        return species(withID: speciesID)
    }

    func waitingCount(for speciesID: String) -> Int {
        state.animals.filter { $0.speciesID == speciesID && $0.location == .waiting }.count
    }

    func capacity(of terrain: Terrain) -> Int {
        config.capacity(for: terrain)
    }

    func productionRate(of terrain: Terrain, mode: ProductionMode = .online) -> Double {
        ProductionEngine.productionRate(
            terrain: terrain,
            residents: residents(in: terrain.id),
            speciesByID: speciesByID,
            mode: mode,
            config: config
        )
    }

    func eligibleTerrains(for species: SpeciesDefinition) -> [Terrain] {
        state.terrains.filter { terrain in
            guard terrain.isUnlocked, terrain.biome == species.principalBiome else { return false }
            let terrainResidents = residents(in: terrain.id)
            guard terrainResidents.count < capacity(of: terrain) else { return false }
            return terrainResidents.isEmpty || terrainResidents.first?.speciesID == species.id
        }
    }

    func upgradeCost(for track: TerrainUpgradeTrack, terrain: Terrain) -> Int {
        Int(config.upgradeCost(for: track, currentLevel: terrain.level(of: track)))
    }

    func resume(at now: Date = .now) {
        guard !isActive else { return }
        var updated = state
        Self.settleAll(
            state: &updated,
            at: now,
            mode: .offline,
            elapsedScale: 1,
            config: config,
            speciesByID: speciesByID
        )
        state = updated
        isActive = true
        save()
    }

    func pause(at now: Date = .now) {
        guard isActive else {
            save()
            return
        }
        settleOnline(at: now)
        isActive = false
        save()
    }

    func tick(at now: Date = .now) {
        guard isActive else { return }
        settleOnline(at: now)
        ticksSinceSave += 1
        if ticksSinceSave >= 5 {
            ticksSinceSave = 0
            save()
        }
    }

    @discardableResult
    func collect(from terrainID: UUID, at now: Date = .now) -> Int {
        settleOnline(at: now)
        guard let index = state.terrains.firstIndex(where: { $0.id == terrainID }) else { return 0 }

        var updated = state
        let amount = Int(floor(updated.terrains[index].storedResources))
        guard amount > 0 else {
            announce("Ainda não há um recurso inteiro para coletar.", kind: .warning)
            return 0
        }
        updated.terrains[index].storedResources -= Double(amount)
        updated.wallet += Double(amount)
        state = updated
        save()
        announce("+\(amount) recursos coletados", kind: .success)
        return amount
    }

    @discardableResult
    func collectAll(at now: Date = .now) -> Int {
        settleOnline(at: now)
        var updated = state
        var total = 0
        for index in updated.terrains.indices {
            let amount = Int(floor(updated.terrains[index].storedResources))
            total += amount
            updated.terrains[index].storedResources -= Double(amount)
        }
        guard total > 0 else {
            announce("Ainda não há recursos inteiros para coletar.", kind: .warning)
            return 0
        }
        updated.wallet += Double(total)
        state = updated
        save()
        announce("+\(total) recursos coletados", kind: .success)
        return total
    }

    @discardableResult
    func placeAnimal(
        speciesID: String,
        into terrainID: UUID,
        at now: Date = .now
    ) -> Result<Void, SanctuaryActionError> {
        settleOnline(at: now)
        guard let terrain = terrain(withID: terrainID), terrain.isUnlocked else {
            return fail(.terrainLocked)
        }
        guard let species = species(withID: speciesID), species.principalBiome == terrain.biome else {
            return fail(.incompatibleBiome)
        }

        let terrainResidents = residents(in: terrainID)
        if let currentSpeciesID = terrainResidents.first?.speciesID, currentSpeciesID != speciesID {
            return fail(.differentSpecies)
        }
        guard terrainResidents.count < capacity(of: terrain) else {
            return fail(.terrainFull)
        }
        guard let animalIndex = state.animals.firstIndex(where: {
            $0.speciesID == speciesID && $0.location == .waiting
        }) else {
            return fail(.noWaitingAnimal)
        }

        var updated = state
        updated.animals[animalIndex].location = .terrain(terrainID)
        state = updated
        save()
        announce("\(species.displayName) foi acolhido", kind: .success)
        return .success(())
    }

    @discardableResult
    func returnOneAnimal(from terrainID: UUID, at now: Date = .now) -> Result<Void, SanctuaryActionError> {
        settleOnline(at: now)
        guard let animalIndex = state.animals.firstIndex(where: { $0.location == .terrain(terrainID) }) else {
            return fail(.noResident)
        }

        let name = species(withID: state.animals[animalIndex].speciesID)?.displayName ?? "Animal"
        var updated = state
        updated.animals[animalIndex].location = .waiting
        state = updated
        save()
        announce("\(name) voltou à Central", kind: .success)
        return .success(())
    }

    @discardableResult
    func buyTerrain(_ terrainID: UUID, at now: Date = .now) -> Result<Void, SanctuaryActionError> {
        settleOnline(at: now)
        guard let index = state.terrains.firstIndex(where: { $0.id == terrainID }) else {
            return fail(.terrainLocked)
        }
        guard !state.terrains[index].isUnlocked else {
            return fail(.terrainAlreadyUnlocked)
        }
        let cost = config.terrainPurchaseCost
        guard state.wallet >= cost else {
            return fail(.insufficientResources(missing: Int(ceil(cost - state.wallet))))
        }

        var updated = state
        updated.wallet -= cost
        updated.terrains[index].isUnlocked = true
        updated.terrains[index].lastSettledAt = now
        state = updated
        save()
        announce("Novo terreno disponível", kind: .success)
        return .success(())
    }

    /// Turns a white map slot into a usable, persisted terrain.
    @discardableResult
    func defineTerrain(
        biome: Biome,
        atMapSlot mapSlot: Int,
        at now: Date = .now
    ) -> Result<Void, SanctuaryActionError> {
        settleOnline(at: now)
        guard mapSlot >= 0,
              !state.terrains.contains(where: { $0.mapSlot == mapSlot }) else {
            return fail(.mapSlotAlreadyDefined)
        }

        var updated = state
        updated.terrains.append(
            Terrain(
                id: UUID(),
                biome: biome,
                isUnlocked: true,
                storedResources: 0,
                lastSettledAt: now,
                upgradeLevels: [:],
                mapSlot: mapSlot
            )
        )
        state = updated
        save()
        announce("Novo terreno de \(biome.title) criado", kind: .success)
        return .success(())
    }

    @discardableResult
    func buyUpgrade(
        _ track: TerrainUpgradeTrack,
        for terrainID: UUID,
        at now: Date = .now
    ) -> Result<Void, SanctuaryActionError> {
        settleOnline(at: now)
        guard track.isImplementedInPOC else { return fail(.upgradePending) }
        guard let index = state.terrains.firstIndex(where: { $0.id == terrainID }),
              state.terrains[index].isUnlocked else {
            return fail(.terrainLocked)
        }

        let terrain = state.terrains[index]
        let currentLevel = terrain.level(of: track)
        guard currentLevel < 10 else { return fail(.maximumLevel) }
        let cost = config.upgradeCost(for: track, currentLevel: currentLevel)
        guard state.wallet >= cost else {
            return fail(.insufficientResources(missing: Int(ceil(cost - state.wallet))))
        }

        var updated = state
        updated.wallet -= cost
        updated.terrains[index].increaseLevel(of: track)
        state = updated
        save()
        announce("Melhoria elevada ao nível \(currentLevel + 1)", kind: .success)
        return .success(())
    }

    func addResourcesForTesting(_ amount: Int = 100) {
        var updated = state
        updated.wallet += Double(max(0, amount))
        state = updated
        save()
        announce("+\(amount) recursos de teste", kind: .success)
    }

    func addAnimalForTesting(speciesID: String) {
        guard let species = species(withID: speciesID) else { return }
        var updated = state
        updated.animals.append(
            AnimalInstance(id: UUID(), speciesID: speciesID, location: .waiting)
        )
        state = updated
        save()
        announce("\(species.displayName) adicionado à Central", kind: .success)
    }

    func simulateOffline(hours: Double = 1, at now: Date = .now) {
        settleOnline(at: now)
        var updated = state
        for index in updated.terrains.indices where updated.terrains[index].isUnlocked {
            let terrainID = updated.terrains[index].id
            let terrainResidents = updated.animals.filter { $0.location == .terrain(terrainID) }
            updated.terrains[index].storedResources += ProductionEngine.accruedResources(
                terrain: updated.terrains[index],
                residents: terrainResidents,
                speciesByID: speciesByID,
                elapsed: max(0, hours) * 60 * 60,
                mode: .offline,
                config: config
            )
        }
        state = updated
        save()
        announce("Produção de \(hours.formatted(.number.precision(.fractionLength(0)))) h simulada", kind: .success)
    }

    func resetDemo(at now: Date = .now) {
        persistence.clear()
        state = SanctuaryState.demo(at: now, config: config)
        demoSpeed = 1
        save()
        announce("Demonstração restaurada", kind: .success)
    }

    private func settleOnline(at now: Date) {
        var updated = state
        Self.settleAll(
            state: &updated,
            at: now,
            mode: .online,
            elapsedScale: demoSpeed,
            config: config,
            speciesByID: speciesByID
        )
        state = updated
    }

    private static func settleAll(
        state: inout SanctuaryState,
        at now: Date,
        mode: ProductionMode,
        elapsedScale: Double,
        config: BalanceConfig,
        speciesByID: [String: SpeciesDefinition]
    ) {
        for index in state.terrains.indices {
            let elapsed = now.timeIntervalSince(state.terrains[index].lastSettledAt)
            guard elapsed > 0 else {
                if now < state.terrains[index].lastSettledAt {
                    state.terrains[index].lastSettledAt = now
                }
                continue
            }
            let terrainID = state.terrains[index].id
            let terrainResidents = state.animals.filter { $0.location == .terrain(terrainID) }
            state.terrains[index].storedResources += ProductionEngine.accruedResources(
                terrain: state.terrains[index],
                residents: terrainResidents,
                speciesByID: speciesByID,
                elapsed: elapsed * max(0, elapsedScale),
                mode: mode,
                config: config
            )
            state.terrains[index].lastSettledAt = now
        }
    }

    private static func normalize(
        state: inout SanctuaryState,
        at now: Date,
        config: BalanceConfig,
        speciesByID: [String: SpeciesDefinition]
    ) {
        state.wallet = state.wallet.isFinite ? max(0, state.wallet) : config.startingWallet

        var seenTerrainIDs = Set<UUID>()
        state.terrains = state.terrains.filter { seenTerrainIDs.insert($0.id).inserted }
        if state.terrains.isEmpty {
            state = SanctuaryState.demo(at: now, config: config)
        }

        for index in state.terrains.indices {
            if state.terrains[index].isUnlocked {
                let stored = state.terrains[index].storedResources
                state.terrains[index].storedResources = stored.isFinite ? max(0, stored) : 0
            } else {
                state.terrains[index].storedResources = 0
            }

            state.terrains[index].upgradeLevels = state.terrains[index].upgradeLevels.mapValues {
                min(10, max(0, $0))
            }
        }

        // Saved states from the fixed-position map have no slot. Invalid or
        // duplicated slots are deterministically moved to the first free cell.
        var occupiedMapSlots = Set<Int>()
        var nextFreeMapSlot = 0
        for index in state.terrains.indices {
            if let slot = state.terrains[index].mapSlot,
               slot >= 0,
               occupiedMapSlots.insert(slot).inserted {
                continue
            }

            while occupiedMapSlots.contains(nextFreeMapSlot) {
                nextFreeMapSlot += 1
            }
            state.terrains[index].mapSlot = nextFreeMapSlot
            occupiedMapSlots.insert(nextFreeMapSlot)
        }

        var seenAnimalIDs = Set<UUID>()
        state.animals = state.animals.filter { animal in
            seenAnimalIDs.insert(animal.id).inserted && speciesByID[animal.speciesID] != nil
        }

        let terrainByID = Dictionary(uniqueKeysWithValues: state.terrains.map { ($0.id, $0) })
        for index in state.animals.indices {
            guard case let .terrain(terrainID) = state.animals[index].location else { continue }
            guard terrainByID[terrainID]?.isUnlocked == true else {
                state.animals[index].location = .waiting
                continue
            }
        }

        for terrain in state.terrains where terrain.isUnlocked {
            var residentSpeciesID: String?
            var acceptedCount = 0
            let capacity = config.capacity(for: terrain)

            for index in state.animals.indices {
                guard state.animals[index].location == .terrain(terrain.id),
                      let species = speciesByID[state.animals[index].speciesID] else {
                    continue
                }

                guard species.principalBiome == terrain.biome else {
                    state.animals[index].location = .waiting
                    continue
                }

                if residentSpeciesID == nil {
                    residentSpeciesID = species.id
                }
                guard residentSpeciesID == species.id, acceptedCount < capacity else {
                    state.animals[index].location = .waiting
                    continue
                }
                acceptedCount += 1
            }
        }
    }

    private func save() {
        persistence.save(state)
    }

    private var speciesByID: [String: SpeciesDefinition] {
        Dictionary(uniqueKeysWithValues: speciesCatalog.map { ($0.id, $0) })
    }

    private func announce(_ message: String, kind: SanctuaryNotice.Kind) {
        let newNotice = SanctuaryNotice(message: message, kind: kind)
        notice = newNotice
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard self?.notice?.id == newNotice.id else { return }
            self?.notice = nil
        }
    }

    private func fail(_ error: SanctuaryActionError) -> Result<Void, SanctuaryActionError> {
        announce(error.localizedDescription, kind: .warning)
        return .failure(error)
    }
}
