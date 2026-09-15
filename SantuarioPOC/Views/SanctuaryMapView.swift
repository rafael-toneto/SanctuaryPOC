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
            SanctuaryZoomScrollView(
                zoomScale: $viewModel.committedZoom,
                centerRequest: viewModel.centerRequest,
                minimumZoomScale: viewModel.minimumZoom,
                maximumZoomScale: viewModel.maximumZoom,
                canvasSize: viewModel.canvasSize,
                activeRectLimit: viewModel.sanctuaryActiveRect,
                ownedLotPositions: viewModel.ownedLotPositions,
                ownedSkeletonSegments: viewModel.ownedSkeletonSegments,
                gestureGate: viewModel.gestureGate
            ) {
                ZStack(alignment: .topLeading) {
                    SanctuaryMapBackdrop()

                    // Terrenos indefinidos (camada base de floresta escura)
                    ForEach(viewModel.displayableLots) { lot in
                        if viewModel.terrain(at: lot.id) == nil {
                            UndefinedTerrainBase(rotation: lot.rotation)
                                .frame(
                                    width: SanctuaryMapLayout.lotInteractionSize.width,
                                    height: SanctuaryMapLayout.lotInteractionSize.height
                                )
                                .position(lot.position)
                                .zIndex(0)
                                .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.85, dampingFraction: 0.78), value: viewModel.displayableLots)

                    // Camada de nuvens circulares densas ao redor de todos os terrenos visíveis
                    ForEach(viewModel.cloudPuffs) { lot in
                        Image("clouds-background")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 420, height: 420)
                            .position(lot.position)
                            .opacity(0.75)
                            .zIndex(500)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .animation(.spring(response: 0.9, dampingFraction: 0.76), value: viewModel.cloudPuffs)

                    // Terrenos já adquiridos
                    ForEach(viewModel.displayableLots) { lot in
                        if let terrain = viewModel.terrain(at: lot.id) {
                            SanctuaryTerrainLot(
                                terrain: terrain,
                                rotation: lot.rotation,
                                residents: viewModel.residents(in: terrain.id),
                                species: viewModel.residentSpecies(in: terrain.id),
                                open: {
                                    viewModel.openTerrain(terrain, callback: openTerrain)
                                }
                            )
                            .frame(
                                width: SanctuaryMapLayout.lotInteractionSize.width,
                                height: SanctuaryMapLayout.lotInteractionSize.height
                            )
                            .position(lot.position)
                            .zIndex(1000 + lot.position.y)
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.85, dampingFraction: 0.8), value: viewModel.ownedTerrainCount)

                    // Botões de compra (+) nos terrenos disponíveis
                    ForEach(viewModel.displayableLots) { lot in
                        if viewModel.terrain(at: lot.id) == nil {
                            UndefinedTerrainButton(
                                rotation: lot.rotation,
                                chooseBiome: {
                                    viewModel.selectUndefinedLot(id: lot.id)
                                }
                            )
                            .frame(
                                width: SanctuaryMapLayout.lotInteractionSize.width,
                                height: SanctuaryMapLayout.lotInteractionSize.height
                            )
                            .position(lot.position)
                            .zIndex(15000 + lot.position.y)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: viewModel.displayableLots)

                    // Decorações de floresta
                    ForEach(viewModel.displayableLots) { lot in
                        if let terrain = viewModel.terrain(at: lot.id), terrain.biome == .forest {
                            ForestDecorationsLot(rotation: lot.rotation)
                                .frame(
                                    width: SanctuaryMapLayout.lotInteractionSize.width,
                                    height: SanctuaryMapLayout.lotInteractionSize.height
                                )
                                .position(lot.position)
                                .zIndex(10000 + lot.position.y)
                        }
                    }

                    // Insígnias de recursos e animais
                    ForEach(viewModel.displayableLots) { lot in
                        if let terrain = viewModel.terrain(at: lot.id) {
                            TerrainBadgeLot(
                                terrain: terrain,
                                rotation: lot.rotation,
                                collect: { collect(terrain) },
                                showBadges: showMapBadges,
                                residentCount: viewModel.residents(in: terrain.id).count
                            )
                            .frame(
                                width: SanctuaryMapLayout.lotInteractionSize.width,
                                height: SanctuaryMapLayout.lotInteractionSize.height
                            )
                            .position(lot.position)
                            .zIndex(20000 + lot.position.y)
                        }
                    }
                }
                .frame(width: viewModel.canvasSize.width, height: viewModel.canvasSize.height)
            }
            .background(SanctuaryTheme.ink)
            .accessibilityLabel("Mapa navegável do santuário")

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
                    Label("Arraste • belisque", systemImage: "hand.draw.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SanctuaryTheme.cream)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SanctuaryTheme.ink.opacity(0.84), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.12)))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        .accessibilityHidden(true)

                    Label("\(viewModel.cloudPuffs.count) nuvens (debug)", systemImage: "cloud.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SanctuaryTheme.cream.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SanctuaryTheme.ink.opacity(0.84), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.12)))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                        .accessibilityLabel("Contador de debug: \(viewModel.cloudPuffs.count) nuvens ativas")
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
