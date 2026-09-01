import SwiftUI

struct TerrainRouteView: View {
    @ObservedObject var store: SanctuaryStore
    let terrainID: UUID

    var body: some View {
        Group {
            if let terrain = store.terrain(withID: terrainID) {
                if terrain.isUnlocked {
                    TerrainDetailView(store: store, terrainID: terrainID)
                } else {
                    TerrainExpansionView(store: store, terrainID: terrainID)
                }
            } else {
                ContentUnavailableView("Terreno indisponível", systemImage: "exclamationmark.triangle")
            }
        }
        .sanctuaryNoticeOverlay(store: store)
    }
}

struct TerrainDetailView: View {
    @ObservedObject var store: SanctuaryStore
    @Environment(\.dismiss) private var dismiss
    let terrainID: UUID

    private var terrain: Terrain? {
        store.terrain(withID: terrainID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SanctuaryBackdrop()

                if let terrain {
                    ScrollView {
                        VStack(spacing: 20) {
                            terrainHero(terrain)
                            productionPanel(terrain)
                            residentsPanel(terrain)
                            upgradesPanel(terrain)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(terrain?.biome.title ?? "Terreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func terrainHero(_ terrain: Terrain) -> some View {
        ZStack(alignment: .bottomLeading) {
            terrain.biome.gradient

            Image(systemName: terrain.biome.symbolName)
                .font(.system(size: 132, weight: .bold))
                .foregroundStyle(.white.opacity(0.09))
                .offset(x: 120, y: 20)

            HStack(alignment: .bottom, spacing: 14) {
                if let species = store.residentSpecies(in: terrain.id) {
                    Text(species.symbol)
                        .font(.system(size: 62))
                        .frame(width: 84, height: 84)
                        .background(.black.opacity(0.2), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16)))
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 34, weight: .bold))
                        .frame(width: 76, height: 76)
                        .background(.white.opacity(0.12), in: Circle())
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.residentSpecies(in: terrain.id)?.displayName ?? "Terreno livre")
                        .font(.title2.bold())
                        .foregroundStyle(SanctuaryTheme.cream)
                    Text(terrain.biome.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(20)
        }
        .frame(height: 184)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.14)))
    }

    private func productionPanel(_ terrain: Terrain) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(
                eyebrow: "Produção passiva",
                title: "Recursos acumulados"
            )

            HStack(alignment: .firstTextBaseline) {
                Text(terrain.storedResources.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(SanctuaryTheme.cream)
                    .contentTransition(.numericText())
                Text("recursos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(
                    "\((store.productionRate(of: terrain) * 60).formatted(.number.precision(.fractionLength(1))))/min",
                    systemImage: "clock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(terrain.biome.accentColor)
            }

            Button {
                if store.collect(from: terrain.id) > 0 { SanctuaryHaptics.success() }
            } label: {
                Label("Coletar", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(FilledActionButtonStyle())
            .disabled(Int(floor(terrain.storedResources)) == 0)
            .opacity(Int(floor(terrain.storedResources)) == 0 ? 0.45 : 1)
        }
        .padding(18)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
    }

    @ViewBuilder
    private func residentsPanel(_ terrain: Terrain) -> some View {
        let residents = store.residents(in: terrain.id)
        let capacity = store.capacity(of: terrain)

        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(
                eyebrow: "Acolhimento",
                title: "Moradores do terreno",
                detail: "Cada terreno recebe somente uma espécie por vez."
            )

            if let species = store.residentSpecies(in: terrain.id) {
                HStack(spacing: 12) {
                    Text(species.symbol)
                        .font(.largeTitle)
                        .frame(width: 58, height: 58)
                        .background(terrain.biome.accentColor.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(species.displayName)
                            .font(.headline)
                        Text("\(residents.count) de \(capacity) indivíduos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ProgressView(value: Double(residents.count), total: Double(capacity))
                    .tint(terrain.biome.accentColor)

                HStack(spacing: 10) {
                    Button {
                        if case .success = store.returnOneAnimal(from: terrain.id) {
                            SanctuaryHaptics.selection()
                        }
                    } label: {
                        Label("Devolver 1", systemImage: "minus")
                    }
                    .buttonStyle(SoftActionButtonStyle())

                    Button {
                        if case .success = store.placeAnimal(speciesID: species.id, into: terrain.id) {
                            SanctuaryHaptics.selection()
                        }
                    } label: {
                        Label("Acolher +1", systemImage: "plus")
                    }
                    .buttonStyle(SoftActionButtonStyle())
                    .disabled(residents.count >= capacity || store.waitingCount(for: species.id) == 0)
                    .opacity(residents.count >= capacity || store.waitingCount(for: species.id) == 0 ? 0.45 : 1)
                }

                if residents.count >= capacity {
                    Label("Terreno cheio — melhore a capacidade abaixo.", systemImage: "info.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(SanctuaryTheme.warning)
                } else if store.waitingCount(for: species.id) == 0 {
                    Text("Nenhum outro indivíduo dessa espécie aguarda terreno.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                let candidates = store.speciesSummaries.filter {
                    $0.species.principalBiome == terrain.biome && $0.waitingCount > 0
                }

                if candidates.isEmpty {
                    ContentUnavailableView(
                        "Nenhum animal compatível aguardando",
                        systemImage: "tray",
                        description: Text("Use o Laboratório da POC para adicionar um animal de teste.")
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(candidates) { summary in
                        HStack(spacing: 12) {
                            Text(summary.species.symbol)
                                .font(.largeTitle)
                                .frame(width: 54, height: 54)
                                .background(terrain.biome.accentColor.opacity(0.16), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary.species.displayName)
                                    .font(.headline)
                                Text("\(summary.waitingCount) aguardando")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Acolher") {
                                if case .success = store.placeAnimal(
                                    speciesID: summary.species.id,
                                    into: terrain.id
                                ) {
                                    SanctuaryHaptics.selection()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(terrain.biome.accentColor)
                        }
                        .padding(12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
    }

    private func upgradesPanel(_ terrain: Terrain) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(
                eyebrow: "Progressão",
                title: "Melhorias do terreno",
                detail: "As oito trilhas canônicas aparecem aqui. Cinco têm parâmetros provisórios testáveis; as demais aguardam regras do produto."
            )

            ForEach(TerrainUpgradeTrack.allCases) { track in
                UpgradeRow(store: store, terrain: terrain, track: track)
            }
        }
    }
}

private struct UpgradeRow: View {
    @ObservedObject var store: SanctuaryStore
    let terrain: Terrain
    let track: TerrainUpgradeTrack

    private var level: Int { terrain.level(of: track) }
    private var cost: Int { store.upgradeCost(for: track, terrain: terrain) }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(terrain.biome.accentColor.opacity(0.16))
                    Text(track.rawValue.formatted())
                        .font(.subheadline.bold())
                        .foregroundStyle(terrain.biome.accentColor)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name(for: terrain.biome))
                        .font(.headline)
                    Text(track.effectDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Text("\(level)/10")
                    .font(.caption.bold())
                    .foregroundStyle(track.isImplementedInPOC ? SanctuaryTheme.lime : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.07), in: Capsule())
            }

            if track.isImplementedInPOC {
                HStack(spacing: 12) {
                    Text(effectPreview)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(terrain.biome.accentColor)
                    Spacer()
                    if level < 10 {
                        Button {
                            if case .success = store.buyUpgrade(track, for: terrain.id) {
                                SanctuaryHaptics.success()
                            }
                        } label: {
                            Label(cost.formatted(), systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(terrain.biome.accentColor)
                        .foregroundStyle(SanctuaryTheme.ink)
                        .accessibilityLabel("Melhorar \(track.name(for: terrain.biome)) por \(cost) recursos")
                        .accessibilityHint("Nível atual \(level) de 10")
                    } else {
                        Label("Máximo", systemImage: "checkmark.seal.fill")
                            .font(.caption.bold())
                            .foregroundStyle(SanctuaryTheme.lime)
                    }
                }
            } else if let reason = track.pendingReason {
                Label(reason, systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(SanctuaryTheme.warning)
            }
        }
        .padding(15)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.075)))
    }

    private var effectPreview: String {
        switch track {
        case .baseProduction:
            "+15% de produção por nível"
        case .generationInterval:
            "−6% no intervalo geral por nível"
        case .offlineEfficiency:
            "+8 p.p. de eficiência offline por nível"
        case .capacity:
            "+1 vaga por nível"
        case .offlineInterval:
            "−5% no intervalo offline por nível"
        default:
            ""
        }
    }
}
