import XCTest
import SwiftUI
@testable import SantuarioPOC

final class InMemorySanctuaryPersistence: SanctuaryPersisting {
    var storedState: SanctuaryState?
    private(set) var saveCount = 0

    init(state: SanctuaryState? = nil) {
        storedState = state
    }

    func load() -> SanctuaryState? {
        storedState
    }

    func save(_ state: SanctuaryState) {
        storedState = state
        saveCount += 1
    }

    func clear() {
        storedState = nil
    }
}

@MainActor
final class SanctuaryRulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testDemoStartsWithOnlySanctuaryContent() {
        let store = makeStore()

        XCTAssertEqual(store.state.terrains.count, 4)
        XCTAssertEqual(store.unlockedTerrainCount, 3)
        XCTAssertEqual(store.accommodatedAnimalCount, 3)
        XCTAssertEqual(store.waitingAnimalCount, 7)
        XCTAssertEqual(store.state.wallet, 160)
    }

    func testTerrainAcceptsSameSpeciesUntilCapacity() throws {
        let store = makeStore()
        let field = try XCTUnwrap(store.state.terrains.first { $0.biome == .grassland })

        XCTAssertSuccess(store.placeAnimal(speciesID: "lobo-guara-demo", into: field.id, at: now))
        XCTAssertEqual(store.residents(in: field.id).count, 3)

        store.addAnimalForTesting(speciesID: "lobo-guara-demo")
        XCTAssertFailure(
            store.placeAnimal(speciesID: "lobo-guara-demo", into: field.id, at: now),
            equals: .terrainFull
        )
    }

    func testTerrainNeverMixesSpecies() throws {
        let store = makeStore()
        let field = try XCTUnwrap(store.state.terrains.first { $0.biome == .grassland })

        XCTAssertFailure(
            store.placeAnimal(speciesID: "tamandua-demo", into: field.id, at: now),
            equals: .differentSpecies
        )
        XCTAssertEqual(store.residents(in: field.id).map(\.speciesID), ["lobo-guara-demo", "lobo-guara-demo"])
    }

    func testRemovingLastResidentMakesTerrainAvailableForAnotherSpecies() throws {
        let store = makeStore()
        let field = try XCTUnwrap(store.state.terrains.first { $0.biome == .grassland })

        XCTAssertSuccess(store.returnOneAnimal(from: field.id, at: now))
        XCTAssertSuccess(store.returnOneAnimal(from: field.id, at: now))
        XCTAssertNil(store.residentSpecies(in: field.id))

        XCTAssertSuccess(store.placeAnimal(speciesID: "tamandua-demo", into: field.id, at: now))
        XCTAssertEqual(store.residentSpecies(in: field.id)?.id, "tamandua-demo")
    }

    func testCapacityUpgradeAddsSpaceWithoutChangingResidents() throws {
        let store = makeStore()
        let field = try XCTUnwrap(store.state.terrains.first { $0.biome == .grassland })

        XCTAssertEqual(store.capacity(of: field), 3)
        XCTAssertSuccess(store.buyUpgrade(.capacity, for: field.id, at: now))

        let upgraded = try XCTUnwrap(store.terrain(withID: field.id))
        XCTAssertEqual(store.capacity(of: upgraded), 4)
        XCTAssertEqual(store.residents(in: field.id).count, 2)
        XCTAssertEqual(store.state.wallet, 90)
    }

    func testEmptyTerrainDoesNotProduce() throws {
        let state = SanctuaryState.demo(at: now)
        let forest = try XCTUnwrap(state.terrains.first { $0.biome == .forest })

        XCTAssertEqual(
            ProductionEngine.accruedResources(
                terrain: forest,
                residents: [],
                elapsed: 3_600,
                mode: .online
            ),
            0
        )
    }

    func testProductionScalesWithResidentCount() throws {
        let state = SanctuaryState.demo(at: now)
        let field = try XCTUnwrap(state.terrains.first { $0.biome == .grassland })
        let residents = state.animals.filter { $0.location == .terrain(field.id) }

        let oneResidentRate = ProductionEngine.productionRate(
            terrain: field,
            residents: Array(residents.prefix(1)),
            mode: .online
        )
        let twoResidentRate = ProductionEngine.productionRate(
            terrain: field,
            residents: residents,
            mode: .online
        )

        XCTAssertEqual(twoResidentRate, oneResidentRate * 2, accuracy: 0.000_001)
    }

    func testProductionUpgradesAffectOnlyTheirConfiguredDimension() throws {
        let state = SanctuaryState.demo(at: now)
        let field = try XCTUnwrap(state.terrains.first { $0.biome == .grassland })
        let residents = state.animals.filter { $0.location == .terrain(field.id) }
        let baseOnline = ProductionEngine.productionRate(
            terrain: field,
            residents: residents,
            mode: .online
        )
        let baseOffline = ProductionEngine.productionRate(
            terrain: field,
            residents: residents,
            mode: .offline
        )

        var productionTerrain = field
        productionTerrain.upgradeLevels[.baseProduction] = 1
        XCTAssertGreaterThan(
            ProductionEngine.productionRate(
                terrain: productionTerrain,
                residents: residents,
                mode: .online
            ),
            baseOnline
        )

        var efficiencyTerrain = field
        efficiencyTerrain.upgradeLevels[.offlineEfficiency] = 1
        XCTAssertEqual(
            ProductionEngine.productionRate(
                terrain: efficiencyTerrain,
                residents: residents,
                mode: .online
            ),
            baseOnline,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            ProductionEngine.productionRate(
                terrain: efficiencyTerrain,
                residents: residents,
                mode: .offline
            ),
            baseOffline
        )

        var generalIntervalTerrain = field
        generalIntervalTerrain.upgradeLevels[.generationInterval] = 1
        XCTAssertGreaterThan(
            ProductionEngine.productionRate(
                terrain: generalIntervalTerrain,
                residents: residents,
                mode: .online
            ),
            baseOnline
        )
        XCTAssertGreaterThan(
            ProductionEngine.productionRate(
                terrain: generalIntervalTerrain,
                residents: residents,
                mode: .offline
            ),
            baseOffline
        )

        var offlineIntervalTerrain = field
        offlineIntervalTerrain.upgradeLevels[.offlineInterval] = 1
        XCTAssertEqual(
            ProductionEngine.productionRate(
                terrain: offlineIntervalTerrain,
                residents: residents,
                mode: .online
            ),
            baseOnline,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            ProductionEngine.productionRate(
                terrain: offlineIntervalTerrain,
                residents: residents,
                mode: .offline
            ),
            baseOffline
        )
    }

    func testOfflineProductionIsCapped() throws {
        let state = SanctuaryState.demo(at: now)
        let field = try XCTUnwrap(state.terrains.first { $0.biome == .grassland })
        let residents = state.animals.filter { $0.location == .terrain(field.id) }

        let atLimit = ProductionEngine.accruedResources(
            terrain: field,
            residents: residents,
            elapsed: BalanceConfig.poc.offlineLimit,
            mode: .offline
        )
        let beyondLimit = ProductionEngine.accruedResources(
            terrain: field,
            residents: residents,
            elapsed: BalanceConfig.poc.offlineLimit * 10,
            mode: .offline
        )

        XCTAssertEqual(beyondLimit, atLimit, accuracy: 0.000_001)
    }

    func testClockMovingBackwardsNeverRemovesResources() throws {
        let state = SanctuaryState.demo(at: now)
        let field = try XCTUnwrap(state.terrains.first { $0.biome == .grassland })
        let residents = state.animals.filter { $0.location == .terrain(field.id) }

        XCTAssertEqual(
            ProductionEngine.accruedResources(
                terrain: field,
                residents: residents,
                elapsed: -100,
                mode: .offline
            ),
            0
        )
    }

    func testStoreRebasesAfterClockMovesBackwards() throws {
        var seeded = SanctuaryState.demo(at: now)
        let future = now.addingTimeInterval(300)
        for index in seeded.terrains.indices {
            seeded.terrains[index].lastSettledAt = future
        }
        let store = makeStore(state: seeded)
        let field = try XCTUnwrap(store.state.terrains.first { $0.biome == .grassland })
        let beforeTick = field.storedResources

        XCTAssertEqual(field.lastSettledAt, now)
        store.resume(at: now)
        store.tick(at: now.addingTimeInterval(10))

        XCTAssertGreaterThan(try XCTUnwrap(store.terrain(withID: field.id)).storedResources, beforeTick)
    }

    func testRestoredStateIsNormalizedToSanctuaryInvariants() throws {
        var seeded = SanctuaryState.demo(at: now)
        let fieldIndex = try XCTUnwrap(seeded.terrains.firstIndex { $0.biome == .grassland })
        let fieldID = seeded.terrains[fieldIndex].id
        seeded.wallet = -20
        seeded.terrains[fieldIndex].storedResources = -8
        seeded.terrains[fieldIndex].upgradeLevels[.capacity] = 99
        seeded.animals.append(
            AnimalInstance(id: UUID(), speciesID: "removed-species", location: .terrain(fieldID))
        )
        seeded.animals.append(
            AnimalInstance(id: UUID(), speciesID: "mico-leao-demo", location: .terrain(fieldID))
        )
        seeded.animals.append(
            AnimalInstance(id: UUID(), speciesID: "mico-leao-demo", location: .terrain(UUID()))
        )

        let store = makeStore(state: seeded)
        let normalizedField = try XCTUnwrap(store.terrain(withID: fieldID))

        XCTAssertEqual(store.state.wallet, 0)
        XCTAssertEqual(normalizedField.storedResources, 0)
        XCTAssertEqual(normalizedField.level(of: .capacity), 10)
        XCTAssertFalse(store.state.animals.contains { $0.speciesID == "removed-species" })
        XCTAssertTrue(
            store.state.animals
                .filter { $0.speciesID == "mico-leao-demo" }
                .allSatisfy { $0.location == .waiting }
        )
        XCTAssertEqual(Set(store.residents(in: fieldID).map(\.speciesID)), ["lobo-guara-demo"])
    }

    func testCollectionMovesWholeResourcesAndPreservesFraction() throws {
        var seeded = SanctuaryState.demo(at: now)
        let fieldIndex = try XCTUnwrap(seeded.terrains.firstIndex { $0.biome == .grassland })
        seeded.terrains[fieldIndex].storedResources = 12.75
        let store = makeStore(state: seeded)

        XCTAssertEqual(store.collect(from: seeded.terrains[fieldIndex].id, at: now), 12)
        XCTAssertEqual(store.state.wallet, 172)
        XCTAssertEqual(store.terrain(withID: seeded.terrains[fieldIndex].id)?.storedResources ?? 0, 0.75, accuracy: 0.000_001)
        XCTAssertEqual(store.collect(from: seeded.terrains[fieldIndex].id, at: now), 0)
    }

    func testCollectAllMovesWholeResourcesPerTerrainAndKeepsFractions() {
        var seeded = SanctuaryState.demo(at: now)
        for index in seeded.terrains.indices {
            seeded.terrains[index].storedResources = Double(index) + 0.75
        }
        let store = makeStore(state: seeded)
        let expectedWhole = 0 + 1 + 2

        XCTAssertEqual(store.collectAll(at: now), expectedWhole)
        XCTAssertEqual(store.state.wallet, 160 + Double(expectedWhole))
        for terrain in store.state.terrains where terrain.isUnlocked {
            XCTAssertEqual(terrain.storedResources, 0.75, accuracy: 0.000_001)
        }
        XCTAssertEqual(store.state.terrains.first { !$0.isUnlocked }?.storedResources, 0)
    }

    func testTerrainPurchaseIsAtomicWhenFundsAreInsufficient() throws {
        var seeded = SanctuaryState.demo(at: now)
        seeded.wallet = 20
        let store = makeStore(state: seeded)
        let aquatic = try XCTUnwrap(store.state.terrains.first { $0.biome == .aquatic })

        XCTAssertFailure(store.buyTerrain(aquatic.id, at: now), equals: .insufficientResources(missing: 100))
        XCTAssertEqual(store.state.wallet, 20)
        XCTAssertFalse(try XCTUnwrap(store.terrain(withID: aquatic.id)).isUnlocked)
    }

    func testTerrainPurchaseDeductsOnceAndUnlocksTheExistingSlot() throws {
        let store = makeStore()
        let aquatic = try XCTUnwrap(store.state.terrains.first { $0.biome == .aquatic })

        XCTAssertSuccess(store.buyTerrain(aquatic.id, at: now))
        XCTAssertTrue(try XCTUnwrap(store.terrain(withID: aquatic.id)).isUnlocked)
        XCTAssertEqual(store.state.wallet, 40)

        XCTAssertFailure(store.buyTerrain(aquatic.id, at: now), equals: .terrainAlreadyUnlocked)
        XCTAssertEqual(store.state.wallet, 40)
        XCTAssertEqual(store.state.terrains.count, 4)
    }

    func testUndefinedMapSlotCanBecomeAUsablePersistedTerrain() throws {
        let persistence = InMemorySanctuaryPersistence()
        let store = SanctuaryStore(persistence: persistence, now: now)

        XCTAssertSuccess(store.defineTerrain(biome: .forest, atMapSlot: 8, at: now))
        let created = try XCTUnwrap(store.state.terrains.first { $0.mapSlot == 8 })
        XCTAssertEqual(created.biome, .forest)
        XCTAssertTrue(created.isUnlocked)
        XCTAssertEqual(store.state.terrains.count, 5)

        XCTAssertFailure(
            store.defineTerrain(biome: .aquatic, atMapSlot: 8, at: now),
            equals: .mapSlotAlreadyDefined
        )
        XCTAssertEqual(store.state.terrains.count, 5)

        let restored = SanctuaryStore(persistence: persistence, now: now)
        XCTAssertEqual(restored.terrain(withID: created.id)?.mapSlot, 8)
    }

    func testAlgorithmicMapUsesTheThreeFittingRotations() throws {
        let lots = SanctuaryMapLayout.lots(
            count: 24,
            canvasSize: CGSize(width: 1_360, height: 1_360)
        )

        XCTAssertEqual(lots.count, 24)
        for index in lots.indices {
            XCTAssertFalse(lots[..<index].contains { $0.position == lots[index].position })
        }
        XCTAssertEqual(lots[0].rotation.degrees, 0, accuracy: 0.000_001)
        XCTAssertEqual(lots[1].rotation.degrees, -120, accuracy: 0.000_001)
        XCTAssertEqual(lots[2].rotation.degrees, 120, accuracy: 0.000_001)

        let rotations = Set(lots.map { Int($0.rotation.degrees.rounded()) })
        XCTAssertEqual(rotations, Set([0, -120, 120]))

        let firstNeighborDistance = hypot(
            lots[1].position.x - lots[0].position.x,
            lots[1].position.y - lots[0].position.y
        )
        XCTAssertEqual(firstNeighborDistance, SanctuaryMapLayout.centerSpacing, accuracy: 0.000_001)
    }

    func testPendingUpgradeCannotChargeWallet() throws {
        let store = makeStore()
        let field = try XCTUnwrap(store.state.terrains.first { $0.biome == .grassland })

        XCTAssertFailure(store.buyUpgrade(.reproduction, for: field.id, at: now), equals: .upgradePending)
        XCTAssertEqual(store.state.wallet, 160)
        XCTAssertEqual(store.terrain(withID: field.id)?.level(of: .reproduction), 0)
    }

    func testStatePersistsAcrossStoreInstances() {
        let persistence = InMemorySanctuaryPersistence()
        let first = SanctuaryStore(persistence: persistence, now: now)
        first.addResourcesForTesting(100)

        let second = SanctuaryStore(persistence: persistence, now: now)
        XCTAssertEqual(second.state.wallet, 260)
        XCTAssertGreaterThanOrEqual(persistence.saveCount, 2)
    }

    func testUserDefaultsPersistenceRoundTripsJSONAndRejectsCorruption() throws {
        let suiteName = "SantuarioPOCTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsSanctuaryPersistence(defaults: defaults, key: "test-state")
        let expected = SanctuaryState.demo(at: now)

        persistence.save(expected)
        XCTAssertEqual(persistence.load(), expected)

        defaults.set(Data("invalid-json".utf8), forKey: "test-state")
        XCTAssertNil(persistence.load())
    }

    func testSchemaMismatchRestoresTheDemoSeed() {
        var incompatible = SanctuaryState.demo(at: now)
        incompatible.schemaVersion = SanctuaryState.currentSchemaVersion + 1
        incompatible.wallet = 9_999

        let store = makeStore(state: incompatible)

        XCTAssertEqual(store.state.schemaVersion, SanctuaryState.currentSchemaVersion)
        XCTAssertEqual(store.state.wallet, BalanceConfig.poc.startingWallet)
    }

    func testOfflineAccrualIsNotDuplicatedOnSecondLoadAtSameTime() throws {
        let initial = SanctuaryState.demo(at: now)
        let persistence = InMemorySanctuaryPersistence(state: initial)
        let oneHourLater = now.addingTimeInterval(3_600)

        let firstLoad = SanctuaryStore(persistence: persistence, now: oneHourLater)
        let fieldID = try XCTUnwrap(firstLoad.state.terrains.first { $0.biome == .grassland }?.id)
        let afterFirstLoad = try XCTUnwrap(firstLoad.terrain(withID: fieldID)?.storedResources)

        let secondLoad = SanctuaryStore(persistence: persistence, now: oneHourLater)
        let afterSecondLoad = try XCTUnwrap(secondLoad.terrain(withID: fieldID)?.storedResources)

        XCTAssertEqual(afterSecondLoad, afterFirstLoad, accuracy: 0.000_001)
    }

    func testAllCanonicalUpgradeNamesArePresentForEveryBiome() {
        for biome in Biome.allCases {
            for track in TerrainUpgradeTrack.allCases {
                XCTAssertFalse(track.name(for: biome).isEmpty)
            }
        }
    }

    private func makeStore(state: SanctuaryState? = nil) -> SanctuaryStore {
        SanctuaryStore(
            persistence: InMemorySanctuaryPersistence(state: state),
            now: now
        )
    }

    private func XCTAssertSuccess(
        _ result: Result<Void, SanctuaryActionError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case let .failure(error) = result {
            XCTFail("Expected success, received \(error)", file: file, line: line)
        }
    }

    private func XCTAssertFailure(
        _ result: Result<Void, SanctuaryActionError>,
        equals expected: SanctuaryActionError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            XCTFail("Expected failure \(expected), received success", file: file, line: line)
        case let .failure(error):
            XCTAssertEqual(error, expected, file: file, line: line)
        }
    }
}
