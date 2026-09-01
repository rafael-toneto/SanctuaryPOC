import SwiftUI

struct TerrainCard: View {
    @ObservedObject var store: SanctuaryStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let terrain: Terrain
    let open: () -> Void
    let collect: () -> Void

    private var residents: [AnimalInstance] {
        store.residents(in: terrain.id)
    }

    private var species: SpeciesDefinition? {
        store.residentSpecies(in: terrain.id)
    }

    private var capacity: Int {
        store.capacity(of: terrain)
    }

    private var collectableAmount: Int {
        Int(floor(terrain.storedResources))
    }

    var body: some View {
        visualCard
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { open() }
            .modifier(CollectAccessibilityAction(amount: collectableAmount, action: collect))
    }

    private var visualCard: some View {
        baseCard
            .overlay(alignment: .topTrailing) {
                collectButton
            }
    }

    private var baseCard: some View {
        ZStack(alignment: .topTrailing) {
            terrain.biome.gradient

            decorativeLayer

            if terrain.isUnlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 300 : 226)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: terrain.biome.accentColor.opacity(0.16), radius: 24, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture(perform: open)
    }

    @ViewBuilder
    private var collectButton: some View {
        if terrain.isUnlocked, collectableAmount > 0 {
            Button(action: collect) {
                Label(collectableAmount.formatted(), systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(SanctuaryTheme.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(SanctuaryTheme.lime, in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Coletar \(collectableAmount) recursos do terreno \(terrain.biome.title)")
        }
    }

    private var decorativeLayer: some View {
        ZStack {
            Image(systemName: terrain.biome.symbolName)
                .font(.system(size: 144, weight: .bold))
                .foregroundStyle(.white.opacity(0.075))
                .rotationEffect(.degrees(-12))
                .offset(x: 105, y: 48)

            Circle()
                .fill(.white.opacity(0.055))
                .frame(width: 180)
                .offset(x: -130, y: 95)

            if terrain.biome == .aquatic || terrain.biome == .wetland {
                Image(systemName: "water.waves")
                    .font(.system(size: 74, weight: .light))
                    .foregroundStyle(.white.opacity(0.1))
                    .offset(x: -90, y: 70)
            }
        }
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        if !terrain.isUnlocked {
            return "Terreno \(terrain.biome.title), bloqueado"
        }
        if let species {
            return "Terreno \(terrain.biome.title), \(species.displayName)"
        }
        return "Terreno \(terrain.biome.title), disponível"
    }

    private var accessibilityValue: String {
        if !terrain.isUnlocked {
            return "Expansão por \(Int(store.config.terrainPurchaseCost)) recursos"
        }
        if species != nil {
            return "\(residents.count) de \(capacity) acolhidos, \(collectableAmount) recursos para coletar"
        }
        return "Sem animais acolhidos"
    }

    private var accessibilityHint: String {
        terrain.isUnlocked ? "Abre os detalhes do terreno" : "Abre a expansão do santuário"
    }

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BiomeBadge(biome: terrain.biome)
                Spacer()
            }

            Spacer()

            if let species {
                HStack(alignment: .center, spacing: 14) {
                    Text(species.symbol)
                        .font(.system(size: 54))
                        .frame(width: 72, height: 72)
                        .background(.black.opacity(0.18), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(species.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(SanctuaryTheme.cream)
                            .lineLimit(2)
                        Text("\(residents.count) de \(capacity) acolhidos")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terreno disponível")
                            .font(.title3.bold())
                            .foregroundStyle(SanctuaryTheme.cream)
                        Text("Toque para acolher um animal")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Label(
                    "\((store.productionRate(of: terrain) * 60).formatted(.number.precision(.fractionLength(1))))/min",
                    systemImage: "clock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(20)
        .padding(.top, 2)
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            BiomeBadge(biome: terrain.biome)
            Spacer()

            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.24), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expandir santuário")
                        .font(.title3.bold())
                        .foregroundStyle(SanctuaryTheme.cream)
                    Text("Novo terreno \(terrain.biome.title.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer()

            Label(Int(store.config.terrainPurchaseCost).formatted(), systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(SanctuaryTheme.cream)
        }
        .padding(20)
        .background(.black.opacity(0.25))
    }
}

private struct CollectAccessibilityAction: ViewModifier {
    let amount: Int
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if amount > 0 {
            content.accessibilityAction(named: Text("Coletar \(amount) recursos"), action)
        } else {
            content
        }
    }
}

struct TerrainPathConnector: View {
    let leansRight: Bool

    var body: some View {
        Capsule()
            .fill(SanctuaryTheme.sand.opacity(0.55))
            .frame(width: 7, height: 34)
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
            .rotationEffect(.degrees(leansRight ? -18 : 18))
            .padding(.vertical, 3)
            .accessibilityHidden(true)
    }
}
