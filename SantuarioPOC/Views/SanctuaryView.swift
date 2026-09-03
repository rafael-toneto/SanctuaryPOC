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
    @AppStorage("showMapBadges") private var showMapBadges: Bool = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SanctuaryBackdrop()

            SanctuaryMapView(
                store: store,
                showMapBadges: showMapBadges,
                openTerrain: { activeSheet = .terrain($0.id) },
                collect: { terrain in
                    if store.collect(from: terrain.id) > 0 { SanctuaryHaptics.success() }
                }
            )
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

            Button {
                showMapBadges.toggle()
                SanctuaryHaptics.selection()
            } label: {
                Image(systemName: showMapBadges ? "eye.fill" : "eye.slash.fill")
                    .font(.title3)
                    .foregroundStyle(SanctuaryTheme.cream)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .accessibilityLabel(showMapBadges ? "Ocultar indicadores" : "Mostrar indicadores")

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
