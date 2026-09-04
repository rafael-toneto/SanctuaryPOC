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

    @State private var balance = RescueBalance.poc
    @State private var encounter = Encounter.random(balance: .poc)
    @State private var message: SanctuaryNotice?
    @State private var showsLab = false
    @StateObject private var weather = WeatherProvider()

    // Distância entre estes dois pontos julga o arremesso; ambos em .named("rescueArena").
    @State private var targetCenter: CGPoint = .zero
    @State private var basketCenter: CGPoint = .zero

    // Puxada em andamento (segue o dedo) ou deslocamento animado do arremesso em voo.
    @State private var dragTranslation: CGSize = .zero
    @State private var isThrowInFlight = false

    // Mesmo achatamento usado para desenhar o alvo e para julgar a distância — uma conta só.
    private let targetSquash: Double = 0.45

    // Puxada considerada "corda no limite" para o háptico. Não limita o arremesso.
    private let maxPull: Double = 150
    private let stretchHaptics = StretchHaptics()

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
        .task { await weather.refresh() }
        .overlay(alignment: .bottom) {
            if let message, !encounterEnded {
                NoticeBanner(notice: message)
                    .padding(.bottom, 210)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if encounterEnded {
                endedCard
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: message)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: encounterEnded)
        .sheet(isPresented: $showsLab) {
            RescueLabSheet(balance: $balance, weather: weather, rollNewAnimal: startNewEncounter)
        }
    }

    // MARK: - Fim de encontro

    private var stockDepleted: Bool {
        encounter.stock.values.allSatisfy { $0 <= 0 }
    }

    private var encounterEnded: Bool {
        encounter.outcome != nil || stockDepleted
    }

    private var canThrow: Bool {
        !isThrowInFlight && !encounterEnded && encounter.stock[encounter.selectedTier, default: 0] > 0
    }

    private var endedCard: some View {
        VStack(spacing: 16) {
            if let message {
                Label(
                    message.message,
                    systemImage: message.kind == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(SanctuaryTheme.cream)
            }

            Button {
                startNewEncounter()
            } label: {
                Text("Encontrar outro animal")
            }
            .buttonStyle(FilledActionButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(SanctuaryTheme.forest, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .padding(24)
    }

    private func startNewEncounter() {
        encounter = .random(balance: balance)
        dragTranslation = .zero
        message = nil
    }

    // MARK: - Topo

    private var topBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    HStack {
                        closeButton
                        labButton
                        Spacer()
                        rarityBadge
                    }
                    speciesName
                }
            } else {
                HStack(spacing: 12) {
                    closeButton
                    labButton
                    speciesName
                    rarityBadge
                }
            }
        }
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
            showsLab = true
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
        Text(encounter.species.displayName.uppercased())
            .font(.subheadline.bold())
            .tracking(1.0)
            .foregroundStyle(SanctuaryTheme.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    private var rarityBadge: some View {
        HStack(spacing: 6) {
            Text(encounter.species.rarity.letter)
                .font(.caption.bold())
            Text(encounter.species.rarity.title)
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
            Text(encounter.species.symbol)
                .font(.system(size: 110))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
                .accessibilityHidden(true)

            targetRing
        }
    }

    private var targetRing: some View {
        ZStack {
            Ellipse()
                .fill(SanctuaryTheme.lime.opacity(0.14))
                .frame(width: balance.hitRadius * 2, height: balance.hitRadius * 2 * targetSquash)
            Ellipse()
                .stroke(SanctuaryTheme.lime, lineWidth: 2)
                .frame(width: balance.hitRadius * 2, height: balance.hitRadius * 2 * targetSquash)
            Ellipse()
                .fill(SanctuaryTheme.lime.opacity(0.30))
                .frame(width: balance.coreRadius * 2, height: balance.coreRadius * 2 * targetSquash)
            Ellipse()
                .stroke(SanctuaryTheme.lime, lineWidth: 1.5)
                .frame(width: balance.coreRadius * 2, height: balance.coreRadius * 2 * targetSquash)
        }
        .background(captureCenter(into: $targetCenter))
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
                    .offset(dragTranslation)
                    .allowsHitTesting(canThrow)
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
            .background(captureCenter(into: $basketCenter))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var basket: some View {
        ZStack {
            Circle()
                .fill(SanctuaryTheme.forest)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(SanctuaryTheme.lime, lineWidth: 2))
            Text(encounter.species.family.symbol)
                .font(.system(size: 30))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Arremesso

    private var throwGesture: some Gesture {
        DragGesture(coordinateSpace: .named("rescueArena"))
            .onChanged { value in
                guard canThrow else { return }
                dragTranslation = value.translation
                let pull = hypot(value.translation.width, value.translation.height)
                stretchHaptics.update(progress: pull / maxPull)
            }
            .onEnded { value in
                guard canThrow else { return }
                stretchHaptics.release()
                let translation = value.translation
                let landing = CGPoint(
                    x: basketCenter.x - translation.width * balance.throwSensitivity,
                    y: basketCenter.y - translation.height * balance.throwSensitivity
                )
                let tier = encounter.selectedTier
                let species = encounter.species

                isThrowInFlight = true
                withAnimation(.easeOut(duration: balance.throwDuration)) {
                    dragTranslation = CGSize(
                        width: -translation.width * balance.throwSensitivity,
                        height: -translation.height * balance.throwSensitivity
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + balance.throwDuration) {
                    resolveThrow(species: species, tier: tier, landing: landing)
                }
            }
    }

    private func resolveThrow(species: RescueSpecies, tier: Int, landing: CGPoint) {
        let dx = landing.x - targetCenter.x
        let dy = landing.y - targetCenter.y
        let distance = hypot(dx, dy / targetSquash)
        let precision = RescueEngine.precision(distance: distance, balance: balance)

        var generator = SystemRandomNumberGenerator()
        let outcome = RescueEngine.resolve(
            species: species,
            tier: tier,
            precision: precision,
            balance: balance,
            using: &generator
        )

        // Sempre consome a cesta usada, mesmo quando o pouso foi .miss.
        encounter.stock[tier, default: 0] -= 1

        switch outcome {
        case .rescued:
            encounter.outcome = .rescued
            SanctuaryHaptics.success()
            message = SanctuaryNotice(message: "\(species.displayName) foi resgatado.", kind: .success)
        case .fled:
            encounter.outcome = .fled
            message = SanctuaryNotice(message: "\(species.displayName) fugiu.", kind: .warning)
        case .stayed:
            if stockDepleted {
                message = SanctuaryNotice(message: "As cestas acabaram.", kind: .warning)
            } else {
                showWarning("A cesta não convenceu. O animal continua ali.")
            }
        }

        isThrowInFlight = false
        dragTranslation = .zero
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
        VStack(spacing: 12) {
            familiesRow
            tiersRow
        }
    }

    private var familiesRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(BasketFamily.allCases) { family in
                        familyButton(family)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(BasketFamily.allCases) { family in
                        familyButton(family)
                    }
                }
            }
        }
    }

    private func familyButton(_ family: BasketFamily) -> some View {
        let compatible = RescueEngine.isCompatible(family, with: encounter.species)
        return Button {
            selectFamily(family)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(family.symbol)
                        .font(.system(size: 26))
                        .frame(width: 52, height: 52)
                        .background(compatible ? SanctuaryTheme.lime.opacity(0.18) : .white.opacity(0.05), in: Circle())
                        .overlay(
                            Circle().stroke(compatible ? SanctuaryTheme.lime : .white.opacity(0.1), lineWidth: compatible ? 2 : 1)
                        )

                    if !compatible {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.55), in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                Text(family.shortTitle)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(compatible ? SanctuaryTheme.cream : .secondary)
            }
            .opacity(compatible ? 1 : 0.55)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(family.title)
        .accessibilityHint(compatible ? "Cesta selecionada" : "Incompatível com \(encounter.species.displayName)")
    }

    private func selectFamily(_ family: BasketFamily) {
        guard RescueEngine.isCompatible(family, with: encounter.species) else {
            showWarning("\(encounter.species.displayName) aceita \(encounter.species.family.title).")
            return
        }
        // Já é a família selecionada por padrão: nada muda, nenhuma cesta é consumida.
    }

    private var tiersRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach([1, 2, 3], id: \.self) { tier in
                        tierSlot(tier)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ForEach([1, 2, 3], id: \.self) { tier in
                        tierSlot(tier)
                    }
                }
            }
        }
    }

    private func tierSlot(_ tier: Int) -> some View {
        let remaining = encounter.stock[tier, default: 0]
        let selected = encounter.selectedTier == tier
        let disabled = remaining == 0
        return Button {
            encounter.selectedTier = tier
            SanctuaryHaptics.selection()
        } label: {
            VStack(spacing: 4) {
                Text(encounter.species.family.basketName(tier: tier))
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(SanctuaryTheme.cream)
                Text("\(remaining) restantes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(.white.opacity(selected ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? SanctuaryTheme.lime : .white.opacity(0.08), lineWidth: selected ? 2 : 1)
            )
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel("\(encounter.species.family.basketName(tier: tier)), \(remaining) restantes")
    }

    private func showWarning(_ text: String) {
        let notice = SanctuaryNotice(message: text, kind: .warning)
        message = notice
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if message?.id == notice.id { message = nil }
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

#Preview {
    RescueView()
}
