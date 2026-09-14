import SwiftUI

@MainActor
final class SanctuaryMapViewModel: ObservableObject {
    @ObservedObject var store: SanctuaryStore

    let minimumZoom: CGFloat = 0.55
    let maximumZoom: CGFloat = 2.25

    @Published var selectedUndefinedLotID: Int?
    @Published var committedZoom: CGFloat = 1
    @Published var centerRequest = 0

    let gestureGate = SanctuaryMapGestureGate()

    init(store: SanctuaryStore) {
        self.store = store
    }

    var lotCount: Int {
        let lastOccupiedSlot = store.state.terrains.compactMap(\.mapSlot).max() ?? -1
        let requiredCount = max(lastOccupiedSlot + 300, store.state.terrains.count + 300)
        let completeTrios = (requiredCount + 2) / 3 * 3
        return max(21, completeTrios)
    }

    var lots: [SanctuaryMapLot] {
        SanctuaryMapLayout.lots(count: lotCount, canvasSize: canvasSize)
    }

    var canvasSize: CGSize {
        SanctuaryMapLayout.canvasSize(for: lotCount)
    }

    var displayableLots: [SanctuaryMapLot] {
        let allLots = lots
        let ownedLotIDs = Set(store.state.terrains.compactMap { $0.mapSlot })
        let ownedPositions = allLots.filter { ownedLotIDs.contains($0.id) }.map { $0.position }

        return allLots.filter { lot in
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
    }

    var visibleLotPositions: [CGPoint] {
        displayableLots.map(\.position)
    }

    var sanctuaryActiveRect: CGRect {
        let positions = visibleLotPositions
        guard let first = positions.first else {
            return CGRect(x: canvasSize.width / 2 - 300, y: canvasSize.height / 2 - 300, width: 600, height: 600)
        }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for pos in positions {
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

        return CGRect(
            x: boundMinX,
            y: boundMinY,
            width: boundMaxX - boundMinX,
            height: boundMaxY - boundMinY
        )
    }

    var cloudPuffs: [SanctuaryMapLot] {
        let displayable = displayableLots
        let displayableIDs = Set(displayable.map(\.id))
        let dispPositions = displayable.map(\.position)
        guard !dispPositions.isEmpty else { return [] }

        return lots.compactMap { lot in
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

            guard closestDist < 650 else { return nil }

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
