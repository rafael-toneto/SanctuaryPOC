import Combine
import SwiftUI

private enum SanctuarySheet: Identifiable {
    case terrain(UUID)
    case storage
    case lab

    var id: String {
        switch self {
        case let .terrain(id): "terrain-\(id.uuidString)"
        case .storage: "storage"
        case .lab: "lab"
        }
    }
}

struct SanctuaryView: View {
    @EnvironmentObject private var store: SanctuaryStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeSheet: SanctuarySheet?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SanctuaryBackdrop()

            VStack(spacing: 0) {
                mapOverview

                SanctuaryMapView(
                    store: store,
                    openTerrain: { activeSheet = .terrain($0.id) },
                    collect: { terrain in
                        if store.collect(from: terrain.id) > 0 { SanctuaryHaptics.success() }
                    }
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .overlay(alignment: .bottom) {
            if activeSheet == nil, let notice = store.notice {
                NoticeBanner(notice: notice)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: store.notice)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .terrain(terrainID):
                TerrainRouteView(store: store, terrainID: terrainID)
                    .presentationDragIndicator(.visible)
            case .storage:
                AnimalStorageView(store: store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .lab:
                POCLabView(store: store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear { store.resume() }
        .onReceive(timer) { store.tick(at: $0) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.resume()
            case .background:
                store.pause()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SANTUÁRIO")
                    .font(.caption2.bold())
                    .tracking(1.8)
                    .foregroundStyle(SanctuaryTheme.lime)
                Text("Refúgio vivo")
                    .font(.headline.bold())
                    .foregroundStyle(SanctuaryTheme.cream)
            }

            Spacer()

            if store.totalCollectableResources > 0 {
                Button {
                    if store.collectAll() > 0 { SanctuaryHaptics.success() }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(SanctuaryTheme.lime)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Coletar todos os recursos")
                .accessibilityValue(store.totalCollectableResources.formatted())
            }

            ResourcePill(amount: store.state.wallet)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(SanctuaryTheme.ink.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }

    private var mapOverview: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MAPA DO SANTUÁRIO")
                    .font(.caption2.bold())
                    .tracking(1.3)
                    .foregroundStyle(SanctuaryTheme.lime)
                Text("Terrenos em expansão")
                    .font(.headline.bold())
                    .foregroundStyle(SanctuaryTheme.cream)
            }

            Spacer(minLength: 4)

            compactMetric(
                icon: "square.grid.2x2.fill",
                value: "\(store.unlockedTerrainCount)/\(store.state.terrains.count)",
                label: "ATIVOS"
            )
            compactMetric(
                icon: "pawprint.fill",
                value: store.accommodatedAnimalCount.formatted(),
                label: "ANIMAIS"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(SanctuaryTheme.deepForest.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }

    private func compactMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(SanctuaryTheme.lime)
                Text(value)
                    .font(.caption.bold())
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08)))
    }

    private var bottomBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    storageButton
                    labButton
                }
            } else {
                HStack(spacing: 12) {
                    storageButton
                    labButton
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(SanctuaryTheme.ink.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }

    private var storageButton: some View {
        Button {
            activeSheet = .storage
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "tray.full.fill")
                Text("Acolhimento")
                Text(store.waitingAnimalCount.formatted())
                    .font(.caption.bold())
                    .foregroundStyle(SanctuaryTheme.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(SanctuaryTheme.lime, in: Capsule())
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SoftActionButtonStyle())
    }

    private var labButton: some View {
        Button {
            activeSheet = .lab
        } label: {
            Label("Demo", systemImage: "flask.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SoftActionButtonStyle())
    }
}
