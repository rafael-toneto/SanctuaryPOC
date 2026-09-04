import CoreGraphics
import CoreLocation
import Foundation
import WeatherKit

enum SkyCondition: String, CaseIterable, Identifiable {
    case clear, cloudy, rain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: "Sol"
        case .cloudy: "Nublado"
        case .rain: "Chuva"
        }
    }

    var symbol: String {
        switch self {
        case .clear: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        }
    }
}

struct WeatherConditions: Equatable {
    var sky: SkyCondition
    var windSpeedKmh: Double
    var windFromDegrees: Double
    var rainIntensity: Double

    static let clearCalm = WeatherConditions(sky: .clear, windSpeedKmh: 0, windFromDegrees: 0, rainIntensity: 0)
}

@MainActor
final class WeatherProvider: ObservableObject {
    enum Source {
        case live, fallback, manual
    }

    @Published var conditions: WeatherConditions = .clearCalm
    @Published var source: Source = .fallback

    // Chuva "no talo": valor provisório — ver spec.md › Extensão 2 › Parâmetros provisórios.
    private let rainSaturationMmPerHour: Double = 7.5

    // Teto para o caso de a sequência de localização nunca emitir nada (ex.: alerta de
    // permissão ignorado, app foi para o background). Valor provisório.
    private static let locationTimeout: Duration = .seconds(8)

    private let locationManager = CLLocationManager()

    func refresh(force: Bool = false) async {
        guard force || source != .manual else { return }
        do {
            let location = try await requestLocation()
            let weather = try await WeatherService.shared.weather(for: location).currentWeather
            conditions = mapConditions(from: weather)
            source = .live
        } catch {
            // Permissão negada, sem rede, sem entitlement ou timeout: mantém o clima atual
            // e cai no fallback. Nunca um alerta — ver spec.md › Cenário: sem clima disponível.
            source = .fallback
        }
    }

    func override(_ newConditions: WeatherConditions) {
        conditions = newConditions
        source = .manual
    }

    private func mapConditions(from weather: CurrentWeather) -> WeatherConditions {
        let sky: SkyCondition
        if isRain(weather.condition) {
            sky = .rain
        } else if weather.cloudCover > 0.5 {
            sky = .cloudy
        } else {
            sky = .clear
        }

        // UnitSpeed não tem mm/h nativo: converte de m/s (1 m/s = 3.600.000 mm/h).
        let precipitationMetersPerSecond = weather.precipitationIntensity.converted(to: .metersPerSecond).value
        let precipitationMmPerHour = precipitationMetersPerSecond * 3_600_000
        let rainIntensity = sky == .rain ? min(precipitationMmPerHour / rainSaturationMmPerHour, 1) : 0

        return WeatherConditions(
            sky: sky,
            windSpeedKmh: weather.wind.speed.converted(to: .kilometersPerHour).value,
            windFromDegrees: weather.wind.direction.converted(to: .degrees).value,
            rainIntensity: rainIntensity
        )
    }

    private func isRain(_ condition: WeatherCondition) -> Bool {
        switch condition {
        case .drizzle, .freezingDrizzle, .freezingRain, .rain, .heavyRain,
             .thunderstorms, .strongStorms, .isolatedThunderstorms, .scatteredThunderstorms, .sunShowers:
            true
        default:
            false
        }
    }

    // `CLLocationUpdate.liveUpdates()` é um AsyncSequence nativo (iOS 17+): sem continuation
    // manual, sem delegate, e o cancelamento da Task para a entrega sozinho — nada a vazar.
    // Os campos de diagnóstico de `CLLocationUpdate` (autorização negada, indisponível etc.)
    // só existem a partir do iOS 18; no deployment target 17.0 deste projeto, negação ou
    // silêncio do usuário caem no teto de tempo abaixo, que já é a rede de segurança pedida.
    private func requestLocation() async throws -> CLLocation {
        locationManager.requestWhenInUseAuthorization()

        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location {
                        return location
                    }
                }
                throw CLError(.locationUnknown)
            }
            group.addTask {
                try await Task.sleep(for: Self.locationTimeout)
                throw CLError(.locationUnknown)
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

enum WeatherEngine {
    /// Pouso mirado → pouso real. Vento empurra; chuva escorrega na direção do voo.
    /// Chamar com `conditions.rainIntensity` zerado dá o pouso intermediário (só vento),
    /// usado pela view para animar o voo antes do escorregão da chuva.
    static func landing(
        aimed: CGPoint,
        throwVector: CGVector,
        conditions: WeatherConditions,
        balance: RescueBalance,
        squash: Double
    ) -> CGPoint {
        let wind = windOffset(conditions: conditions, balance: balance, squash: squash)
        let rain = rainOffset(throwVector: throwVector, conditions: conditions, balance: balance, squash: squash)
        return CGPoint(x: aimed.x + wind.dx + rain.dx, y: aimed.y + wind.dy + rain.dy)
    }

    // ponytail: bússola achatada em cima da arena, 0° = topo. Se a perspectiva de T011
    // mudar o eixo do chão, este é o único lugar a mexer.
    /// Direção para onde o vento empurra (não de onde ele vem), na mesma convenção usada
    /// para desenhar e julgar o arremesso: 0° no topo da tela, sentido horário — a mesma
    /// que `.rotationEffect(.degrees(_:))` usa. A seta do mostrador (T009) consome esta
    /// função para nunca discordar do desvio real.
    static func windPushDegrees(_ conditions: WeatherConditions) -> Double {
        // windFromDegrees é de onde o vento vem; o empurrão vai para o lado oposto.
        (conditions.windFromDegrees + 180).truncatingRemainder(dividingBy: 360)
    }

    private static func windOffset(conditions: WeatherConditions, balance: RescueBalance, squash: Double) -> CGVector {
        guard conditions.windSpeedKmh > 0 else { return .zero }

        let pushDegrees = windPushDegrees(conditions)
        let radians = pushDegrees * .pi / 180
        let magnitude = conditions.windSpeedKmh * balance.windDriftPerKmh

        // 0° = topo da tela, sentido horário: dx = sin, dy = -cos (eixo Y cresce para baixo).
        return CGVector(dx: sin(radians) * magnitude, dy: -cos(radians) * magnitude * squash)
    }

    private static func rainOffset(throwVector: CGVector, conditions: WeatherConditions, balance: RescueBalance, squash: Double) -> CGVector {
        guard conditions.rainIntensity > 0 else { return .zero }

        // Desfaz o achatamento da tela para obter a direção no chão — o mesmo espaço em que
        // `RescueView.resolveThrow` já compara distâncias (`dy / targetSquash`) — normaliza
        // ali, e só reaplica o achatamento no fim, no y do resultado.
        let ground = CGVector(dx: throwVector.dx, dy: throwVector.dy / squash)
        let length = hypot(ground.dx, ground.dy)
        guard length > 0 else { return .zero }

        let magnitude = conditions.rainIntensity * balance.rainSkidMax
        return CGVector(dx: ground.dx / length * magnitude, dy: ground.dy / length * magnitude * squash)
    }
}
