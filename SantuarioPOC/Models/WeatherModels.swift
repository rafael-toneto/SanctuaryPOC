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
