import SwiftUI

struct AnimalStorageView: View {
    @ObservedObject var store: SanctuaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpeciesID: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundStyle(SanctuaryTheme.lime)
                        Text("Esta Central existe para testar o armazenamento e a movimentação sem implementar mapa ou resgate. Ela não define o fluxo final quando faltar capacidade.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.white.opacity(0.055))
                }

                Section("Aguardando terreno") {
                    ForEach(store.speciesSummaries) { summary in
                        speciesRow(summary)
                            .listRowBackground(Color.white.opacity(0.055))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SanctuaryTheme.ink)
            .navigationTitle("Central de acolhimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .confirmationDialog(
                "Escolha um terreno",
                isPresented: Binding(
                    get: { selectedSpeciesID != nil },
                    set: { if !$0 { selectedSpeciesID = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let selectedSpeciesID,
                   let species = store.species(withID: selectedSpeciesID) {
                    ForEach(store.eligibleTerrains(for: species)) { terrain in
                        let count = store.residents(in: terrain.id).count
                        Button("\(terrain.biome.title) • \(count)/\(store.capacity(of: terrain))") {
                            if case .success = store.placeAnimal(
                                speciesID: selectedSpeciesID,
                                into: terrain.id
                            ) {
                                SanctuaryHaptics.selection()
                            }
                            self.selectedSpeciesID = nil
                        }
                    }
                }
            } message: {
                Text("Terrenos ocupados só aparecem quando já acolhem a mesma espécie e ainda têm capacidade.")
            }
        }
        .sanctuaryNoticeOverlay(store: store)
    }

    private func speciesRow(_ summary: SpeciesSummary) -> some View {
        let targets = store.eligibleTerrains(for: summary.species)

        return HStack(spacing: 12) {
            Text(summary.species.symbol)
                .font(.system(size: 34))
                .frame(width: 52, height: 52)
                .background(summary.species.principalBiome.accentColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.species.displayName)
                    .font(.headline)
                HStack(spacing: 7) {
                    Label(summary.species.principalBiome.title, systemImage: summary.species.principalBiome.symbolName)
                    Text("•")
                    Text("\(summary.waitingCount) aguardando")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("\(summary.accommodatedCount) já acolhido(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if summary.waitingCount > 0, !targets.isEmpty {
                Button("Acolher") {
                    selectedSpeciesID = summary.species.id
                }
                .buttonStyle(.borderedProminent)
                .tint(summary.species.principalBiome.accentColor)
            } else {
                Image(systemName: summary.waitingCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(summary.waitingCount == 0 ? SanctuaryTheme.lime : SanctuaryTheme.warning)
                    .accessibilityLabel(summary.waitingCount == 0 ? "Nenhum aguardando" : "Sem terreno disponível")
            }
        }
        .padding(.vertical, 5)
    }
}

struct TerrainExpansionView: View {
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
                        VStack(spacing: 22) {
                            ZStack {
                                terrain.biome.gradient
                                Image(systemName: terrain.biome.symbolName)
                                    .font(.system(size: 120, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.12))
                                VStack(spacing: 10) {
                                    Image(systemName: "lock.open.fill")
                                        .font(.largeTitle)
                                    Text("Novo terreno \(terrain.biome.title.lowercased())")
                                        .font(.title2.bold())
                                }
                                .foregroundStyle(SanctuaryTheme.cream)
                            }
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.15)))

                            SectionHeading(
                                eyebrow: "Expansão",
                                title: "Abra espaço para novos cuidados",
                                detail: "Comprar o lote libera um terreno vazio. Depois, um animal compatível pode ser acolhido pela Central."
                            )

                            HStack(spacing: 12) {
                                MetricChip(
                                    icon: "sparkles",
                                    value: Int(store.config.terrainPurchaseCost).formatted(),
                                    label: "custo provisório"
                                )
                                MetricChip(
                                    icon: "wallet.pass.fill",
                                    value: Int(floor(store.state.wallet)).formatted(),
                                    label: "seu saldo"
                                )
                            }

                            Button {
                                if case .success = store.buyTerrain(terrain.id) {
                                    SanctuaryHaptics.success()
                                    dismiss()
                                }
                            } label: {
                                Label("Expandir santuário", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(FilledActionButtonStyle(tint: terrain.biome.accentColor))
                            .accessibilityHint(
                                "Custa \(Int(store.config.terrainPurchaseCost)) recursos. Saldo atual: \(Int(floor(store.state.wallet)))."
                            )

                            Label(
                                "O bioma deste lote é predefinido apenas para a POC. Escolha, conversão ou bioma fixo ainda são decisões abertas.",
                                systemImage: "info.circle.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Expandir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct POCLabView: View {
    @ObservedObject var store: SanctuaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "flask.fill")
                            .foregroundStyle(SanctuaryTheme.lime)
                        Text("Estes controles existem somente para alcançar estados da POC rapidamente. Não representam ações do jogo final.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Economia e tempo") {
                    Button {
                        store.addResourcesForTesting(100)
                        SanctuaryHaptics.selection()
                    } label: {
                        Label("Adicionar 100 recursos", systemImage: "sparkles")
                    }

                    Button {
                        store.simulateOffline(hours: 1)
                        SanctuaryHaptics.selection()
                    } label: {
                        Label("Simular 1 hora offline", systemImage: "clock.arrow.circlepath")
                    }

                    Picker("Velocidade ativa", selection: $store.demoSpeed) {
                        Text("1×").tag(1.0)
                        Text("10×").tag(10.0)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Animais de teste") {
                    ForEach(store.speciesCatalog) { species in
                        Button {
                            store.addAnimalForTesting(speciesID: species.id)
                            SanctuaryHaptics.selection()
                        } label: {
                            HStack {
                                Text(species.symbol)
                                Text("Adicionar \(species.displayName)")
                                Spacer()
                                Text(species.principalBiome.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Restaurar demonstração", role: .destructive) {
                        confirmsReset = true
                    }
                } footer: {
                    Text("Apaga somente o estado local desta POC e retorna ao cenário inicial.")
                }
            }
            .navigationTitle("Laboratório da POC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .confirmationDialog(
                "Restaurar a demonstração?",
                isPresented: $confirmsReset,
                titleVisibility: .visible
            ) {
                Button("Restaurar", role: .destructive) {
                    store.resetDemo()
                    SanctuaryHaptics.success()
                }
            } message: {
                Text("Saldo, terrenos, animais e melhorias voltarão ao cenário inicial.")
            }
        }
        .sanctuaryNoticeOverlay(store: store)
    }
}
