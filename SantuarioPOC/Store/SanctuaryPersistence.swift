import Foundation

protocol SanctuaryPersisting {
    func load() -> SanctuaryState?
    func save(_ state: SanctuaryState)
    func clear()
}

final class UserDefaultsSanctuaryPersistence: SanctuaryPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "sanctuary-poc-state-v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> SanctuaryState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SanctuaryState.self, from: data)
    }

    func save(_ state: SanctuaryState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
