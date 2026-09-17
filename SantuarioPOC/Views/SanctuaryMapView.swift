import SwiftUI

struct SanctuaryMapView: View {
    let store: SanctuaryStore
    var showMapBadges: Bool = true
    let openTerrain: (Terrain) -> Void
    let collect: (Terrain) -> Void

    @StateObject private var viewModel: SanctuaryMapViewModel

    init(
        store: SanctuaryStore,
        showMapBadges: Bool = true,
        openTerrain: @escaping (Terrain) -> Void,
        collect: @escaping (Terrain) -> Void
    ) {
        self.store = store
        self.showMapBadges = showMapBadges
        self.openTerrain = openTerrain
        self.collect = collect
        _viewModel = StateObject(wrappedValue: SanctuaryMapViewModel(store: store))
    }

    var body: some View {
        ZStack {
            SanctuarySpriteMapView(
                viewModel: viewModel,
                store: store,
                openTerrain: openTerrain,
                collect: collect
            )
            // Keep SpriteKit inside the space allocated by the parent layout.
            // Extending it below the bottom inset makes the camera calculate
            // against pixels hidden by the bottom bar, cutting off lower terrain.
            .background(SanctuaryTheme.ink)
            .accessibilityLabel("Mapa navegável do santuário em SpriteKit")

            mapInstructions

            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        mapControlButton(
                            systemImage: "minus.magnifyingglass",
                            accessibilityLabel: "Diminuir mapa"
                        ) {
                            viewModel.zoomOut()
                        }

                        mapControlButton(
                            systemImage: "scope",
                            accessibilityLabel: "Centralizar mapa"
                        ) {
                            viewModel.requestCenter()
                        }

                        mapControlButton(
                            systemImage: "plus.magnifyingglass",
                            accessibilityLabel: "Ampliar mapa"
                        ) {
                            viewModel.zoomIn()
                        }
                    }
                }

                Spacer()
                mapLegend
            }
            .padding(12)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.selectedUndefinedLotID != nil },
                set: { if !$0 { viewModel.selectedUndefinedLotID = nil } }
            )
        ) {
            BiomeSelectionSheet { biome in
                if viewModel.selectedUndefinedLotID != nil {
                    viewModel.defineSelectedLot(as: biome)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(SanctuaryTheme.ink)
        }
    }

    private func mapControlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.bold())
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(SanctuaryTheme.cream)
        .background(SanctuaryTheme.ink.opacity(0.86), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .accessibilityLabel(accessibilityLabel)
    }

    private var mapInstructions: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        FPSOverlayView()

                        Label("Arraste • belisque", systemImage: "hand.draw.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SanctuaryTheme.cream)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(SanctuaryTheme.ink.opacity(0.84), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.12)))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            .accessibilityHidden(true)
                    }

                }

                Spacer()
            }
            Spacer()
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private var mapLegend: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Biome.allCases) { biome in
                    MapLegendItem(color: biome.mapColor, title: biome.mapTitle)
                }
                MapLegendItem(color: .white, title: "A definir", hasBorder: true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(SanctuaryTheme.ink.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.13)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .frame(maxWidth: 520)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legenda: azul aquático, verde-água úmido, verde floresta, verde amarelado planície e branco a definir")
    }
}

struct MapLegendItem: View {
    let color: Color
    let title: String
    var hasBorder = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay {
                    if hasBorder {
                        Circle().stroke(.black.opacity(0.3), lineWidth: 1)
                    }
                }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SanctuaryTheme.cream)
        }
    }
}

extension Biome {
    var mapAssetName: String {
        switch self {
        case .aquatic: "TerrainAquatic"
        case .wetland: "TerrainWetland"
        case .forest: "TerrainForest"
        case .grassland: "TerrainGrassland"
        }
    }

    var mapColor: Color {
        switch self {
        case .aquatic: Color(red: 0.11, green: 0.39, blue: 0.94)
        case .wetland: Color(red: 0.10, green: 0.72, blue: 0.67)
        case .forest: Color(red: 0.03, green: 0.68, blue: 0.04)
        case .grassland: Color(red: 0.68, green: 0.78, blue: 0.25)
        }
    }
}

#Preview("Mapa do santuário") {
    SanctuaryMapView(
        store: SanctuaryStore(persistence: PreviewSanctuaryPersistence()),
        openTerrain: { _ in },
        collect: { _ in }
    )
    .frame(height: 760)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .padding()
    .background(SanctuaryTheme.ink)
}

private final class PreviewSanctuaryPersistence: SanctuaryPersisting {
    func load() -> SanctuaryState? { nil }
    func save(_ state: SanctuaryState) {}
    func clear() {}
}
