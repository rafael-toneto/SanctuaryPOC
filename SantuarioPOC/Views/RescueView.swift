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
    @State private var showsBasketSheet = false
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
        .overlay {
            if let windGhostLanding {
                Ellipse()
                    .stroke(SanctuaryTheme.lime.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: balance.hitRadius * 2, height: balance.hitRadius * 2 * targetSquash)
                    .position(windGhostLanding)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
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

    // Cortes de velocidade só para a cor da seta — apresentação, não regra (Artigo 5).
    private let calmWindThreshold: Double = 1
    private let strongWindThreshold: Double = 30

    private var windColor: Color {
        let speed = weather.conditions.windSpeedKmh
        if speed < calmWindThreshold { return .secondary }
        if speed >= strongWindThreshold { return SanctuaryTheme.warning }
        return SanctuaryTheme.lime
    }

    private var windDirectionPhrase: String {
        let degrees = WeatherEngine.windPushDegrees(weather.conditions)
        let sector = Int((degrees / 45).rounded()) % 8
        return switch sector {
        case 0: "para cima"
        case 1: "para cima e para a direita"
        case 2: "para a direita"
        case 3: "para baixo e para a direita"
        case 4: "para baixo"
        case 5: "para baixo e para a esquerda"
        case 6: "para a esquerda"
        default: "para cima e para a esquerda"
        }
    }

    private var weatherAccessibilityLabel: String {
        let speed = Int(weather.conditions.windSpeedKmh.rounded())
        let windPart = speed < 1
            ? "Vento parado."
            : "Vento de \(speed) quilômetros por hora, soprando \(windDirectionPhrase)."
        return "\(windPart) \(weather.conditions.sky.title)."
    }

    private var weatherStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.subheadline.bold())
                .foregroundStyle(windColor)
                .rotationEffect(.degrees(WeatherEngine.windPushDegrees(weather.conditions)))
            Text("\(Int(weather.conditions.windSpeedKmh.rounded())) km/h")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SanctuaryTheme.cream)
            Image(systemName: weather.conditions.sky.symbol)
                .font(.caption)
                .foregroundStyle(SanctuaryTheme.cream)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1)))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weatherAccessibilityLabel)
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

    /// Onde cairia um arremesso mirado no centro do alvo, com o clima atual — a prévia do
    /// desvio. `throwVector: .zero` zera o termo da chuva (guarda em `WeatherEngine.landing`),
    /// então isto mostra só o vento, que é o que a faixa de clima promete.
    private var windGhostLanding: CGPoint? {
        guard weather.conditions.windSpeedKmh > 0 else { return nil }
        return WeatherEngine.landing(
            aimed: targetCenter, throwVector: .zero,
            conditions: weather.conditions, balance: balance, squash: targetSquash
        )
    }

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
            Image(encounter.species.family.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
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
                let aimedLanding = CGPoint(
                    x: basketCenter.x - translation.width * balance.throwSensitivity,
                    y: basketCenter.y - translation.height * balance.throwSensitivity
                )
                let throwVector = CGVector(
                    dx: -translation.width * balance.throwSensitivity,
                    dy: -translation.height * balance.throwSensitivity
                )
                let conditions = weather.conditions
                var windOnlyConditions = conditions
                windOnlyConditions.rainIntensity = 0

                let windLanding = WeatherEngine.landing(
                    aimed: aimedLanding, throwVector: throwVector,
                    conditions: windOnlyConditions, balance: balance, squash: targetSquash
                )
                let finalLanding = WeatherEngine.landing(
                    aimed: aimedLanding, throwVector: throwVector,
                    conditions: conditions, balance: balance, squash: targetSquash
                )
                let tier = encounter.selectedTier
                let species = encounter.species
                let hasRainSkid = conditions.rainIntensity > 0

                isThrowInFlight = true
                withAnimation(.easeOut(duration: balance.throwDuration)) {
                    dragTranslation = CGSize(width: windLanding.x - basketCenter.x, height: windLanding.y - basketCenter.y)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + balance.throwDuration) {
                    guard hasRainSkid else {
                        resolveThrow(species: species, tier: tier, landing: finalLanding)
                        return
                    }
                    withAnimation(.easeOut(duration: balance.rainSkidDuration)) {
                        dragTranslation = CGSize(width: finalLanding.x - basketCenter.x, height: finalLanding.y - basketCenter.y)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + balance.rainSkidDuration) {
                        resolveThrow(species: species, tier: tier, landing: finalLanding)
                    }
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
        Button {
            showsBasketSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(encounter.species.family.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(encounter.species.family.basketName(tier: encounter.selectedTier))
                        .font(.subheadline.weight(.semibold))
                    Text("\(currentStock) restantes")
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
        .disabled(isThrowInFlight || encounterEnded)
        .accessibilityLabel("Cesta selecionada: \(encounter.species.family.basketName(tier: encounter.selectedTier)), \(currentStock) restantes")
        .accessibilityHint("Toque para escolher outra cesta")
        .sheet(isPresented: $showsBasketSheet) {
            BasketSheet(species: encounter.species, stock: encounter.stock, selectedTier: $encounter.selectedTier)
        }
    }

    private var currentStock: Int {
        encounter.stock[encounter.selectedTier, default: 0]
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
    RescueView()
}
