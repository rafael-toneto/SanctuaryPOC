import SwiftUI
import Combine

@MainActor
final class SanctuaryMapViewModel: ObservableObject {
    @ObservedObject var store: SanctuaryStore

    let minimumZoom: CGFloat = 0.55
    let maximumZoom: CGFloat = 2.25

    @Published var selectedUndefinedLotID: Int?
    @Published var committedZoom: CGFloat = 1
    @Published var centerRequest = 0

    let gestureGate = SanctuaryMapGestureGate()

    // MARK: - Combine & Cache
    private var cancellables = Set<AnyCancellable>()
    private var lastCacheKey: Int = -1
    private var _cachedLotCount: Int = 21
    private var _cachedCanvasSize: CGSize = .zero
    private var _cachedLots: [SanctuaryMapLot] = []
    private var _cachedDisplayableLots: [SanctuaryMapLot] = []
    private var _cachedVisibleLotPositions: [CGPoint] = []
    private var _cachedOwnedLotPositions: [CGPoint] = []
    private var _cachedOwnedSkeletonSegments: [SanctuaryMapSegment] = []
    private var _cachedSanctuaryActiveRect: CGRect = .zero
    private var _cachedCloudPuffs: [SanctuaryMapLot] = []

    private struct MapStateSnapshot: Equatable {
        let terrainSnapshots: [TerrainSnapshot]
        let animalAssignments: [UUID: AnimalLocation]

        struct TerrainSnapshot: Equatable {
            let id: UUID
            let mapSlot: Int?
            let biome: Biome
            let isUnlocked: Bool
            let collectable: Int
        }
    }

    init(store: SanctuaryStore) {
        self.store = store
        refreshCacheIfNeeded()
        setupStateObservation()
    }

    private func setupStateObservation() {
        store.$state
            .map { state in
                MapStateSnapshot(
                    terrainSnapshots: state.terrains.map {
                        MapStateSnapshot.TerrainSnapshot(
                            id: $0.id,
                            mapSlot: $0.mapSlot,
                            biome: $0.biome,
                            isUnlocked: $0.isUnlocked,
                            collectable: Int(floor($0.storedResources))
                        )
                    },
                    animalAssignments: Dictionary(uniqueKeysWithValues: state.animals.map { ($0.id, $0.location) })
                )
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshCacheIfNeeded()
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private var currentTerrainKey: Int {
        var hasher = Hasher()
        hasher.combine(store.state.terrains.count)
        for t in store.state.terrains {
            hasher.combine(t.id)
            hasher.combine(t.mapSlot ?? -1)
            hasher.combine(t.biome)
            hasher.combine(t.isUnlocked)
            hasher.combine(Int(floor(t.storedResources)))
        }
        return hasher.finalize()
    }

    private func refreshCacheIfNeeded() {
        let key = currentTerrainKey
        guard key != lastCacheKey else { return }
        lastCacheKey = key

        // 1. Lot count & canvas
        let lastOccupiedSlot = store.state.terrains.compactMap(\.mapSlot).max() ?? -1
        let requiredCount = max(lastOccupiedSlot + 300, store.state.terrains.count + 300)
        let completeTrios = (requiredCount + 2) / 3 * 3
        _cachedLotCount = max(21, completeTrios)
        _cachedCanvasSize = SanctuaryMapLayout.canvasSize(for: _cachedLotCount)
        _cachedLots = SanctuaryMapLayout.lots(count: _cachedLotCount, canvasSize: _cachedCanvasSize)

        // 2. Displayable lots & Owned lots
        let ownedLotIDs = Set(store.state.terrains.compactMap { $0.mapSlot })
        let ownedPositions = _cachedLots.filter { ownedLotIDs.contains($0.id) }.map { $0.position }
        _cachedOwnedLotPositions = ownedPositions
        _cachedOwnedSkeletonSegments = Self.buildSkeleton(from: ownedPositions)

        _cachedDisplayableLots = _cachedLots.filter { lot in
            if terrain(at: lot.id) != nil {
                return true
            }

            return ownedPositions.contains { ownedPos in
                let dx = lot.position.x - ownedPos.x
                let dy = lot.position.y - ownedPos.y
                let distance = hypot(dx, dy)
                return distance < 180
            }
        }

        // 3. Positions & Active rect
        _cachedVisibleLotPositions = _cachedDisplayableLots.map(\.position)

        if let first = _cachedVisibleLotPositions.first {
            var minX = first.x
            var maxX = first.x
            var minY = first.y
            var maxY = first.y
            for pos in _cachedVisibleLotPositions {
                minX = min(minX, pos.x)
                maxX = max(maxX, pos.x)
                minY = min(minY, pos.y)
                maxY = max(maxY, pos.y)
            }

            let halfLotWidth: CGFloat = SanctuaryMapLayout.lotSize.width / 2
            let halfLotHeight: CGFloat = SanctuaryMapLayout.lotSize.height / 2
            let cloudEdgeMargin: CGFloat = 20

            let boundMinX = minX - halfLotWidth - cloudEdgeMargin
            let boundMaxX = maxX + halfLotWidth + cloudEdgeMargin
            let boundMinY = minY - halfLotHeight - cloudEdgeMargin
            let boundMaxY = maxY + halfLotHeight + cloudEdgeMargin

            _cachedSanctuaryActiveRect = CGRect(
                x: boundMinX,
                y: boundMinY,
                width: boundMaxX - boundMinX,
                height: boundMaxY - boundMinY
            )
        } else {
            _cachedSanctuaryActiveRect = CGRect(
                x: _cachedCanvasSize.width / 2 - 300,
                y: _cachedCanvasSize.height / 2 - 300,
                width: 600,
                height: 600
            )
        }

        // 4. Cloud puffs (otimizado: limite de 380pt de distância em vez de 650pt)
        let displayableIDs = Set(_cachedDisplayableLots.map(\.id))
        let dispPositions = _cachedVisibleLotPositions

        if dispPositions.isEmpty {
            _cachedCloudPuffs = []
        } else {
            _cachedCloudPuffs = _cachedLots.compactMap { lot in
                guard !displayableIDs.contains(lot.id) else { return nil }

                var closestDist: CGFloat = .infinity
                var pushX: CGFloat = 0
                var pushY: CGFloat = 0
                var closeCount = 0

                for dp in dispPositions {
                    let d = hypot(lot.position.x - dp.x, lot.position.y - dp.y)
                    if d < closestDist {
                        closestDist = d
                    }
                    if d < 250 && d > 1 {
                        pushX += (lot.position.x - dp.x) / d
                        pushY += (lot.position.y - dp.y) / d
                        closeCount += 1
                    }
                }

                // Nuvens até 380pt garantem cobertura contínua e farta na borda
                // sem gerar centenas de nuvens distantes que nunca entrariam na tela.
                guard closestDist < 380 else { return nil }

                var finalPos = lot.position
                if closeCount > 0 {
                    let pushLen = hypot(pushX, pushY)
                    if pushLen > 0.001 {
                        finalPos = CGPoint(
                            x: lot.position.x + (pushX / pushLen) * 50,
                            y: lot.position.y + (pushY / pushLen) * 50
                        )
                    }
                }

                return SanctuaryMapLot(id: lot.id, position: finalPos, rotation: lot.rotation)
            }
        }
    }

    private static func buildSkeleton(from positions: [CGPoint]) -> [SanctuaryMapSegment] {
        guard positions.count > 1 else { return [] }

        let n = positions.count
        var segments: [SanctuaryMapSegment] = []
        var adj = [Set<Int>](repeating: Set<Int>(), count: n)

        // 1. Conexões diretas entre terrenos vizinhos adjacentes no grid hexagonal (distância <= 185pt)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let dist = hypot(dx, dy)
                if dist <= 185 {
                    segments.append(SanctuaryMapSegment(start: positions[i], end: positions[j]))
                    adj[i].insert(j)
                    adj[j].insert(i)
                }
            }
        }

        // 2. Minimum Spanning Tree (Kruskal) para conectar qualquer ramificação ou ilha de terrenos comprados
        struct Edge: Comparable {
            let dist: CGFloat
            let u: Int
            let v: Int
            static func < (lhs: Edge, rhs: Edge) -> Bool { lhs.dist < rhs.dist }
        }

        var allEdges: [Edge] = []
        for i in 0..<n {
            for j in (i + 1)..<n {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                allEdges.append(Edge(dist: hypot(dx, dy), u: i, v: j))
            }
        }
        allEdges.sort()

        var parent = Array(0..<n)
        func findRoot(_ x: Int) -> Int {
            var curr = x
            while parent[curr] != curr {
                parent[curr] = parent[parent[curr]]
                curr = parent[curr]
            }
            return curr
        }

        for edge in allEdges {
            let rootU = findRoot(edge.u)
            let rootV = findRoot(edge.v)
            if rootU != rootV {
                parent[rootU] = rootV
                if !adj[edge.u].contains(edge.v) {
                    segments.append(SanctuaryMapSegment(start: positions[edge.u], end: positions[edge.v]))
                    adj[edge.u].insert(edge.v)
                    adj[edge.v].insert(edge.u)
                }
            }
        }

        return segments
    }

    var lotCount: Int {
        refreshCacheIfNeeded()
        return _cachedLotCount
    }

    var lots: [SanctuaryMapLot] {
        refreshCacheIfNeeded()
        return _cachedLots
    }

    var canvasSize: CGSize {
        refreshCacheIfNeeded()
        return _cachedCanvasSize
    }

    var displayableLots: [SanctuaryMapLot] {
        refreshCacheIfNeeded()
        return _cachedDisplayableLots
    }

    var visibleLotPositions: [CGPoint] {
        refreshCacheIfNeeded()
        return _cachedVisibleLotPositions
    }

    var ownedLotPositions: [CGPoint] {
        refreshCacheIfNeeded()
        return _cachedOwnedLotPositions
    }

    var ownedSkeletonSegments: [SanctuaryMapSegment] {
        refreshCacheIfNeeded()
        return _cachedOwnedSkeletonSegments
    }

    var sanctuaryActiveRect: CGRect {
        refreshCacheIfNeeded()
        return _cachedSanctuaryActiveRect
    }

    var cloudPuffs: [SanctuaryMapLot] {
        refreshCacheIfNeeded()
        return _cachedCloudPuffs
    }

    var ownedTerrainCount: Int {
        store.state.terrains.count
    }

    func residents(in terrainID: UUID) -> [AnimalInstance] {
        store.residents(in: terrainID)
    }

    func residentSpecies(in terrainID: UUID) -> SpeciesDefinition? {
        store.residentSpecies(in: terrainID)
    }

    func terrain(at mapSlot: Int) -> Terrain? {
        store.state.terrains.first { $0.mapSlot == mapSlot }
    }

    func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(maximumZoom, max(minimumZoom, value))
    }

    func updateZoom(by factor: CGFloat) {
        withAnimation(.easeInOut(duration: 0.22)) {
            committedZoom = clampedZoom(committedZoom * factor)
        }
        SanctuaryHaptics.selection()
    }

    func zoomIn() {
        updateZoom(by: 1.25)
    }

    func zoomOut() {
        updateZoom(by: 0.8)
    }

    func requestCenter() {
        centerRequest += 1
        SanctuaryHaptics.selection()
    }

    func defineSelectedLot(as biome: Biome) {
        guard let mapSlot = selectedUndefinedLotID else { return }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.76)) {
            if case .success = store.defineTerrain(biome: biome, atMapSlot: mapSlot) {
                SanctuaryHaptics.success()
                refreshCacheIfNeeded()
            }
        }
    }

    func selectUndefinedLot(id: Int) {
        guard !gestureGate.suppressesLotActions else { return }
        selectedUndefinedLotID = id
        SanctuaryHaptics.selection()
    }

    func openTerrain(_ terrain: Terrain, callback: (Terrain) -> Void) {
        guard !gestureGate.suppressesLotActions else { return }
        SanctuaryHaptics.selection()
        callback(terrain)
    }

    func collectTerrain(_ terrain: Terrain, callback: (Terrain) -> Void) {
        guard !gestureGate.suppressesLotActions else { return }
        callback(terrain)
    }
}
