import Combine
import SwiftUI

@MainActor
final class RescueViewModel: ObservableObject {
    @Published var balance = RescueBalance.poc
    @Published var encounter = Encounter.random(balance: .poc)
    @Published var message: SanctuaryNotice?
    @Published var showsLab = false
    @Published var showsBasketSheet = false

    // Moita: índices das folhas ainda presentes. Vazio = animal revelado (fase 2 liberada).
    // Contagem e limiar são apresentação (Artigo 5), não regra — por isso ficam aqui, fora de
    // `RescueBalance`.
    static let bushLeafCount = 24
    static let bushRevealThreshold = 6
    static let bushSize = CGSize(width: 210, height: 190)
    @Published var remainingLeaves: Set<Int> = Set(0..<RescueViewModel.bushLeafCount)

    // Distância entre estes dois pontos julga o arremesso; ambos em .named("rescueArena").
    @Published var targetCenter: CGPoint = .zero
    @Published var basketCenter: CGPoint = .zero

    // Puxada em andamento (segue o dedo) ou deslocamento animado do arremesso em voo.
    @Published var dragTranslation: CGSize = .zero
    @Published var isThrowInFlight = false

    let weather = WeatherProvider()

    // Mesmo achatamento usado para desenhar o alvo e para julgar a distância — uma conta só.
    let targetSquash: Double = 0.45

    // Puxada considerada "corda no limite" para o háptico. Não limita o arremesso.
    let maxPull: Double = 150
    let stretchHaptics = StretchHaptics()

    // Cortes de velocidade só para a cor da seta — apresentação, não regra (Artigo 5).
    private let calmWindThreshold: Double = 1
    private let strongWindThreshold: Double = 30

    // Raio de toque que remove uma folha da moita — apresentação, não regra.
    private let leafRemovalRadius: Double = 30

    // Forward das mudanças de `weather` (ObservableObject próprio) para esta view model, já
    // que a View não observa mais `weather` diretamente.
    private var cancellables = Set<AnyCancellable>()

    init() {
        weather.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Fim de encontro

    var stockDepleted: Bool {
        encounter.stock.values.allSatisfy { $0 <= 0 }
    }

    var encounterEnded: Bool {
        encounter.outcome != nil || stockDepleted
    }

    var canThrow: Bool {
        !isThrowInFlight && !encounterEnded && animalRevealed
            && encounter.stock[encounter.selectedTier, default: 0] > 0
    }

    var currentStock: Int {
        encounter.stock[encounter.selectedTier, default: 0]
    }

    func startNewEncounter() {
        encounter = .random(balance: balance)
        dragTranslation = .zero
        message = nil
        remainingLeaves = Set(0..<Self.bushLeafCount)
    }

    // MARK: - Clima

    var windColor: Color {
        let speed = weather.conditions.windSpeedKmh
        if speed < calmWindThreshold { return .secondary }
        if speed >= strongWindThreshold { return SanctuaryTheme.warning }
        return SanctuaryTheme.lime
    }

    var windDirectionPhrase: String {
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

    var weatherAccessibilityLabel: String {
        let speed = Int(weather.conditions.windSpeedKmh.rounded())
        let windPart = speed < 1
            ? "Vento parado."
            : "Vento de \(speed) quilômetros por hora, soprando \(windDirectionPhrase)."
        return "\(windPart) \(weather.conditions.sky.title)."
    }

    // MARK: - Animal e alvo

    /// Onde cairia um arremesso mirado no centro do alvo, com o clima atual — a prévia do
    /// desvio. `throwVector: .zero` zera o termo da chuva (guarda em `WeatherEngine.landing`),
    /// então isto mostra só o vento, que é o que a faixa de clima promete.
    var windGhostLanding: CGPoint? {
        guard animalRevealed else { return nil }
        guard weather.conditions.windSpeedKmh > 0 else { return nil }
        return WeatherEngine.landing(
            aimed: targetCenter, throwVector: .zero,
            conditions: weather.conditions, balance: balance, squash: targetSquash
        )
    }

    // MARK: - Moita

    var animalRevealed: Bool {
        remainingLeaves.isEmpty
    }

    /// Posição determinística por índice — espiral por ângulo áureo, não `random` (senão as
    /// folhas trocariam de lugar a cada redesenho). Usada tanto para posicionar a folha na
    /// View quanto para julgar o toque em `removeLeaves`.
    func leafPosition(_ index: Int) -> CGPoint {
        let goldenAngle = 137.508 * Double.pi / 180
        let maxRadius = min(Self.bushSize.width, Self.bushSize.height) / 2 - 12
        let t = Double(index) / Double(Self.bushLeafCount)
        let r = maxRadius * t.squareRoot()
        let theta = Double(index) * goldenAngle
        return CGPoint(
            x: Self.bushSize.width / 2 + r * cos(theta),
            y: Self.bushSize.height / 2 + r * sin(theta) * 0.85
        )
    }

    func removeLeaves(near point: CGPoint, animation: Animation) {
        guard !animalRevealed else { return }
        let hit = remainingLeaves.filter { index in
            let leaf = leafPosition(index)
            return hypot(leaf.x - point.x, leaf.y - point.y) <= leafRemovalRadius
        }
        guard !hit.isEmpty else { return }

        withAnimation(animation) {
            remainingLeaves.subtract(hit)
            if !remainingLeaves.isEmpty && remainingLeaves.count < Self.bushRevealThreshold {
                remainingLeaves.removeAll()
            }
        }
        SanctuaryHaptics.selection()
    }

    func revealBush(animation: Animation) {
        guard !animalRevealed else { return }
        withAnimation(animation) {
            remainingLeaves.removeAll()
        }
        SanctuaryHaptics.selection()
    }

    // MARK: - Arremesso

    func beginThrow(translation: CGSize) {
        guard canThrow else { return }
        dragTranslation = translation
        let pull = hypot(translation.width, translation.height)
        stretchHaptics.update(progress: pull / maxPull)
    }

    func endThrow(translation: CGSize) {
        guard canThrow else { return }
        stretchHaptics.release()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + balance.throwDuration) { [weak self] in
            guard let self else { return }
            guard hasRainSkid else {
                self.resolveThrow(species: species, tier: tier, landing: finalLanding)
                return
            }
            withAnimation(.easeOut(duration: self.balance.rainSkidDuration)) {
                self.dragTranslation = CGSize(width: finalLanding.x - self.basketCenter.x, height: finalLanding.y - self.basketCenter.y)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.balance.rainSkidDuration) {
                self.resolveThrow(species: species, tier: tier, landing: finalLanding)
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

    func showWarning(_ text: String) {
        let notice = SanctuaryNotice(message: text, kind: .warning)
        message = notice
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            if self?.message?.id == notice.id { self?.message = nil }
        }
    }
}
