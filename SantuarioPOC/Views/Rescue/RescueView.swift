import SwiftUI

struct Encounter {
    let species: RescueSpecies
    var stock: [Int: Int]
    var selectedTier: Int
    var outcome: AttemptOutcome?

    static func random(balance: RescueBalance) -> Encounter {
        Encounter(
            species: RescueCatalog.all.randomElement()!,
            stock: balance.startingStock,
            selectedTier: 1,
            outcome: nil
        )
    }
}

struct RescueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var viewModel: RescueViewModel

    init(store: SanctuaryStore) {
        _viewModel = StateObject(wrappedValue: RescueViewModel(store: store))
    }

    var body: some View {
        ZStack {
            SanctuaryBackdrop()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                animalAndTarget
                Spacer(minLength: 8)
                slingshot
                Spacer(minLength: 18)
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .coordinateSpace(name: "rescueArena")
        .overlay {
            if let windGhostLanding = viewModel.windGhostLanding {
                Ellipse()
                    .stroke(SanctuaryTheme.lime.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: viewModel.balance.hitRadius * 2, height: viewModel.balance.hitRadius * 2 * viewModel.targetSquash)
                    .position(windGhostLanding)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .task { await viewModel.weather.refresh() }
        .overlay(alignment: .bottom) {
            if let message = viewModel.message, !viewModel.encounterEnded {
                NoticeBanner(notice: message)
                    .padding(.bottom, 210)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if viewModel.encounterEnded {
                endedCard
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: viewModel.message)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: viewModel.encounterEnded)
        .sheet(isPresented: $viewModel.showsLab) {
            RescueLabSheet(balance: $viewModel.balance, weather: viewModel.weather, rollNewAnimal: viewModel.startNewEncounter)
        }
    }

    // MARK: - Fim de encontro

    private var endedCard: some View {
        VStack(spacing: 16) {
            if let message = viewModel.message {
                Label(
                    message.message,
                    systemImage: message.kind == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(SanctuaryTheme.cream)
            }

            Button {
                viewModel.startNewEncounter()
            } label: {
                Text("Encontrar outro animal")
            }
            .buttonStyle(FilledActionButtonStyle())

            Button {
                dismiss()
            } label: {
                Text("Ir ao santuário")
            }
            .buttonStyle(SoftActionButtonStyle())
            .accessibilityLabel("Ir ao santuário")
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(SanctuaryTheme.forest, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .padding(24)
    }

    // MARK: - Topo

    private var topBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    HStack {
                        closeButton
                        weatherStrip
                        labButton
                        Spacer()
                        rarityBadge
                    }
                    speciesName
                }
            } else {
                HStack(spacing: 12) {
                    closeButton
                    weatherStrip
                    labButton
                    speciesName
                    rarityBadge
                }
            }
        }
    }

    // MARK: - Clima

    private var weatherStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.windColor)
                .rotationEffect(.degrees(WeatherEngine.windPushDegrees(viewModel.weather.conditions)))
            Text("\(Int(viewModel.weather.conditions.windSpeedKmh.rounded())) km/h")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SanctuaryTheme.cream)
            Image(systemName: viewModel.weather.conditions.sky.symbol)
                .font(.caption)
                .foregroundStyle(SanctuaryTheme.cream)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1)))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.weatherAccessibilityLabel)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.headline.bold())
                .foregroundStyle(SanctuaryTheme.cream)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.1)))
        }
        .accessibilityLabel("Fechar encontro")
    }

    private var labButton: some View {
        Button {
            viewModel.showsLab = true
        } label: {
            Image(systemName: "flask.fill")
                .font(.headline.bold())
                .foregroundStyle(SanctuaryTheme.cream)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.1)))
        }
        .accessibilityLabel("Laboratório do resgate")
    }

    private var speciesName: some View {
        Text(viewModel.encounter.species.displayName.uppercased())
            .font(.subheadline.bold())
            .tracking(1.0)
            .foregroundStyle(SanctuaryTheme.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    private var rarityBadge: some View {
        HStack(spacing: 6) {
            Text(viewModel.encounter.species.rarity.letter)
                .font(.caption.bold())
            Text(viewModel.encounter.species.rarity.title)
                .font(.caption2)
        }
        .foregroundStyle(SanctuaryTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SanctuaryTheme.lime, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Animal e alvo

    private var animalAndTarget: some View {
        VStack(spacing: -14) {
            Text(viewModel.encounter.species.symbol)
                .font(.system(size: 110))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
                .accessibilityHidden(true)

            targetRing
        }
        // Overlay, não fluxo do VStack: a moita não pode deslocar nem redimensionar o emoji
        // ou o targetRing — captureCenter(into: $viewModel.targetCenter) depende desse layout intacto.
        .overlay(alignment: .top) {
            if !viewModel.animalRevealed {
                bushOverlay
            }
        }
    }

    // MARK: - Moita

    private var bushOverlay: some View {
        ZStack {
            ForEach(0..<RescueViewModel.bushLeafCount, id: \.self) { index in
                if viewModel.remainingLeaves.contains(index) {
                    leafShape(index)
                        .position(viewModel.leafPosition(index))
                        .transition(bushFallTransition)
                }
            }
        }
        .frame(width: RescueViewModel.bushSize.width, height: RescueViewModel.bushSize.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in viewModel.removeLeaves(near: value.location, animation: bushAnimation) }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moita escondendo o \(viewModel.encounter.species.displayName). Toque duas vezes para afastar.")
        .accessibilityAction { viewModel.revealBush(animation: bushAnimation) }
    }

    private var bushFallTransition: AnyTransition {
        reduceMotion ? .opacity : .offset(y: 40).combined(with: .opacity)
    }

    private var bushAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.7)
    }

    private func leafShape(_ index: Int) -> some View {
        let color = index % 3 == 0 ? SanctuaryTheme.lime : SanctuaryTheme.forest
        return Group {
            if index % 2 == 0 {
                Capsule().fill(color)
            } else {
                Ellipse().fill(color)
            }
        }
        .frame(width: 26, height: 14)
        .rotationEffect(.degrees(leafRotation(index)))
    }

    private func leafRotation(_ index: Int) -> Double {
        Double((index * 53) % 360)
    }

    private var targetRing: some View {
        ZStack {
            Ellipse()
                .fill(SanctuaryTheme.lime.opacity(0.14))
                .frame(width: viewModel.balance.hitRadius * 2, height: viewModel.balance.hitRadius * 2 * viewModel.targetSquash)
            Ellipse()
                .stroke(SanctuaryTheme.lime, lineWidth: 2)
                .frame(width: viewModel.balance.hitRadius * 2, height: viewModel.balance.hitRadius * 2 * viewModel.targetSquash)
            Ellipse()
                .fill(SanctuaryTheme.lime.opacity(0.30))
                .frame(width: viewModel.balance.coreRadius * 2, height: viewModel.balance.coreRadius * 2 * viewModel.targetSquash)
            Ellipse()
                .stroke(SanctuaryTheme.lime, lineWidth: 1.5)
                .frame(width: viewModel.balance.coreRadius * 2, height: viewModel.balance.coreRadius * 2 * viewModel.targetSquash)
        }
        .background(captureCenter(into: $viewModel.targetCenter))
        .accessibilityHidden(true)
    }

    // MARK: - Estilingue

    private var slingshot: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                HStack(spacing: 22) {
                    Capsule()
                        .fill(SanctuaryTheme.sand)
                        .frame(width: 10, height: 96)
                        .rotationEffect(.degrees(-14), anchor: .bottom)
                    Capsule()
                        .fill(SanctuaryTheme.sand)
                        .frame(width: 10, height: 96)
                        .rotationEffect(.degrees(14), anchor: .bottom)
                }

                // Âncora fixa: captura o centro de repouso, nunca se move com o arremesso.
                basketAnchor
                    .offset(y: -46)

                basket
                    .offset(y: -46)
                    .offset(viewModel.dragTranslation)
                    .allowsHitTesting(viewModel.canThrow)
                    .gesture(throwGesture)
            }
            .frame(height: 110)

            Text("PUXE E SOLTE")
                .font(.caption2.bold())
                .tracking(1.4)
                .foregroundStyle(.secondary)
        }
    }

    private var basketAnchor: some View {
        Color.clear
            .frame(width: 64, height: 64)
            .background(captureCenter(into: $viewModel.basketCenter))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var basket: some View {
        ZStack {
            Circle()
                .fill(SanctuaryTheme.forest)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(SanctuaryTheme.lime, lineWidth: 2))
            Image(viewModel.encounter.species.family.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Arremesso

    private var throwGesture: some Gesture {
        DragGesture(coordinateSpace: .named("rescueArena"))
            .onChanged { value in viewModel.beginThrow(translation: value.translation) }
            .onEnded { value in viewModel.endThrow(translation: value.translation) }
    }

    private func captureCenter(into point: Binding<CGPoint>) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { point.wrappedValue = center(of: proxy) }
                .onChange(of: proxy.frame(in: .named("rescueArena"))) { _, _ in
                    point.wrappedValue = center(of: proxy)
                }
        }
    }

    private func center(of proxy: GeometryProxy) -> CGPoint {
        let frame = proxy.frame(in: .named("rescueArena"))
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: - Rodapé

    private var footer: some View {
        Button {
            viewModel.showsBasketSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(viewModel.encounter.species.family.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.encounter.species.family.basketName(tier: viewModel.encounter.selectedTier))
                        .font(.subheadline.weight(.semibold))
                    Text("\(viewModel.currentStock) restantes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
        }
        .buttonStyle(SoftActionButtonStyle())
        .disabled(viewModel.isThrowInFlight || viewModel.encounterEnded)
        .accessibilityLabel("Cesta selecionada: \(viewModel.encounter.species.family.basketName(tier: viewModel.encounter.selectedTier)), \(viewModel.currentStock) restantes")
        .accessibilityHint("Toque para escolher outra cesta")
        .sheet(isPresented: $viewModel.showsBasketSheet) {
            BasketSheet(species: viewModel.encounter.species, stock: viewModel.encounter.stock, selectedTier: $viewModel.encounter.selectedTier)
        }
    }
}

// MARK: - Laboratório do resgate

struct RescueLabSheet: View {
    @Binding var balance: RescueBalance
    @ObservedObject var weather: WeatherProvider
    var rollNewAnimal: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "flask.fill")
                            .foregroundStyle(SanctuaryTheme.lime)
                        Text("Estes controles existem para calibrar o resgate com o aparelho na mão. Não representam valores do jogo final.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Clima") {
                    Picker("Céu", selection: skyBinding) {
                        ForEach(SkyCondition.allCases) { sky in
                            Text(sky.title).tag(sky)
                        }
                    }

                    sliderRow("Velocidade do vento", value: windSpeedBinding, range: 0...60, format: "%.0f km/h")
                    sliderRow("Direção do vento (de onde vem)", value: windDirectionBinding, range: 0...359, format: "%.0f°")

                    if weather.conditions.sky == .rain {
                        sliderRow("Intensidade da chuva", value: rainIntensityBinding, range: 0...1, format: "%.2f")
                    }

                    Toggle("Usar clima real", isOn: useRealWeatherBinding)

                    Text("Fonte: \(weatherSourceLabel)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Calibração de toque") {
                    sliderRow("Sensibilidade do arremesso", value: $balance.throwSensitivity, range: 1.0...5.0, format: "%.1f×")
                    sliderRow("Desvio do vento", value: $balance.windDriftPerKmh, range: 0...4, format: "%.2f pt/km/h")
                    sliderRow("Escorregão da chuva", value: $balance.rainSkidMax, range: 0...80, format: "%.0f pt")
                    sliderRow("Raio base do alvo", value: $balance.hitRadiusBase, range: 40...160, format: "%.0f pt")
                }

                Section("Mão firme") {
                    Stepper(value: $balance.steadyHandLevel, in: 1...10) {
                        Text("Nível \(balance.steadyHandLevel) — raio resultante \(Int(balance.hitRadius)) pt")
                    }
                    .accessibilityLabel("Nível de Mão Firme")
                    .accessibilityValue("\(balance.steadyHandLevel), raio resultante \(Int(balance.hitRadius)) pontos")
                }

                Section("Chance base por raridade") {
                    ForEach(Rarity.allCases) { rarity in
                        sliderRow(rarity.title, value: baseChanceBinding(rarity), range: 0...1, format: "%.2f")
                    }
                }

                Section("Multiplicador por nível de cesta") {
                    ForEach([1, 2, 3], id: \.self) { tier in
                        sliderRow("Nível \(tier)", value: tierMultiplierBinding(tier), range: 0.5...3.0, format: "%.2f×")
                    }
                }

                Section("Precisão") {
                    sliderRow("Multiplicador do núcleo", value: $balance.coreMultiplier, range: 1.0...3.0, format: "%.2f×")
                }

                Section("Chance de fuga por raridade") {
                    ForEach(Rarity.allCases) { rarity in
                        sliderRow(rarity.title, value: fleeChanceBinding(rarity), range: 0...1, format: "%.2f")
                    }
                }

                Section {
                    Button {
                        rollNewAnimal()
                    } label: {
                        Label("Sortear outro animal", systemImage: "shuffle")
                    }

                    Button("Restaurar valores provisórios", role: .destructive) {
                        balance = .poc
                    }
                }
            }
            .navigationTitle("Laboratório do resgate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(String(format: format, value.wrappedValue))")
                .font(.subheadline)
            Slider(value: value, in: range)
                .accessibilityLabel(label)
                .accessibilityValue(String(format: format, value.wrappedValue))
        }
    }

    private func baseChanceBinding(_ rarity: Rarity) -> Binding<Double> {
        Binding(
            get: { balance.baseChance[rarity, default: 0] },
            set: { balance.baseChance[rarity] = $0 }
        )
    }

    private func tierMultiplierBinding(_ tier: Int) -> Binding<Double> {
        Binding(
            get: { balance.tierMultiplier[tier, default: 1] },
            set: { balance.tierMultiplier[tier] = $0 }
        )
    }

    private func fleeChanceBinding(_ rarity: Rarity) -> Binding<Double> {
        Binding(
            get: { balance.fleeChance[rarity, default: 0] },
            set: { balance.fleeChance[rarity] = $0 }
        )
    }

    // MARK: - Clima

    private var weatherSourceLabel: String {
        switch weather.source {
        case .live: "clima real"
        case .fallback: "clima simulado"
        case .manual: "ajustado à mão"
        }
    }

    private var skyBinding: Binding<SkyCondition> {
        Binding(
            get: { weather.conditions.sky },
            set: { newSky in
                var conditions = weather.conditions
                conditions.sky = newSky
                if newSky != .rain { conditions.rainIntensity = 0 }
                weather.override(conditions)
            }
        )
    }

    private var windSpeedBinding: Binding<Double> {
        Binding(
            get: { weather.conditions.windSpeedKmh },
            set: { var conditions = weather.conditions; conditions.windSpeedKmh = $0; weather.override(conditions) }
        )
    }

    private var windDirectionBinding: Binding<Double> {
        Binding(
            get: { weather.conditions.windFromDegrees },
            set: { var conditions = weather.conditions; conditions.windFromDegrees = $0; weather.override(conditions) }
        )
    }

    private var rainIntensityBinding: Binding<Double> {
        Binding(
            get: { weather.conditions.rainIntensity },
            set: { var conditions = weather.conditions; conditions.rainIntensity = $0; weather.override(conditions) }
        )
    }

    private var useRealWeatherBinding: Binding<Bool> {
        Binding(
            get: { weather.source == .live },
            set: { useReal in
                if useReal {
                    Task { await weather.refresh(force: true) }
                } else {
                    weather.override(weather.conditions)
                }
            }
        )
    }
}

// MARK: - Hub de cestas

/// Lista as nove cestas agrupadas por família, no formato do Pokémon GO. Só a família
/// compatível com `species` é selecionável — a incompatibilidade fica na regra
/// (`RescueEngine.isCompatible`), não decidida aqui.
struct BasketSheet: View {
    let species: RescueSpecies
    let stock: [Int: Int]
    @Binding var selectedTier: Int
    @Environment(\.dismiss) private var dismiss

    private let tiers = [1, 2, 3]

    var body: some View {
        NavigationStack {
            List {
                ForEach(BasketFamily.allCases) { family in
                    Section(family.title) {
                        ForEach(tiers, id: \.self) { tier in
                            row(family: family, tier: tier)
                        }
                    }
                }
            }
            .navigationTitle("Cestas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(family: BasketFamily, tier: Int) -> some View {
        let compatible = RescueEngine.isCompatible(family, with: species)
        let remaining = stock[tier, default: 0]
        let outOfStock = compatible && remaining <= 0
        let selectable = compatible && !outOfStock
        let selected = compatible && selectedTier == tier
        let reason: String? = !compatible
            ? "\(species.displayName) não come isto"
            : (outOfStock ? "sem estoque" : nil)

        return Button {
            selectedTier = tier
            SanctuaryHaptics.selection()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(family.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(family.basketName(tier: tier))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectable ? SanctuaryTheme.cream : .secondary)
                    if let reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SanctuaryTheme.lime)
                        .accessibilityHidden(true)
                } else if compatible {
                    Text("\(remaining)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(selectable ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(family: family, tier: tier, remaining: remaining, reason: reason, selected: selected))
    }

    private func accessibilityLabel(family: BasketFamily, tier: Int, remaining: Int, reason: String?, selected: Bool) -> String {
        var parts = [family.basketName(tier: tier)]
        if let reason {
            parts.append(reason)
        } else {
            parts.append("\(remaining) restantes")
        }
        if selected {
            parts.append("selecionada")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    RescueView(store: SanctuaryStore(persistence: RescuePreviewPersistence()))
}

private final class RescuePreviewPersistence: SanctuaryPersisting {
    func load() -> SanctuaryState? { nil }
    func save(_ state: SanctuaryState) {}
    func clear() {}
}
