import Combine
import Foundation

enum RefreshInterval: Double, CaseIterable, Identifiable {
    case halfSecond = 0.5
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .halfSecond: "0.5 seconds"
        case .oneSecond: "1 second"
        case .twoSeconds: "2 seconds"
        case .fiveSeconds: "5 seconds"
        case .tenSeconds: "10 seconds"
        }
    }
}

enum OverlayAppearance: String, CaseIterable, Identifiable {
    case ocean = "Ocean"
    case aurora = "Aurora"
    case sunset = "Sunset"
    case graphite = "Graphite"

    var id: String { rawValue }
}

@MainActor
final class PreferencesService: ObservableObject {
    private enum Key {
        static let metricsInterval = "metricsRefreshInterval"
        static let processInterval = "processRefreshInterval"
        static let appearance = "overlayAppearance"
        static let tintStrength = "overlayTintStrength"
    }

    @Published var metricsInterval: RefreshInterval {
        didSet { defaults.set(metricsInterval.rawValue, forKey: Key.metricsInterval) }
    }

    @Published var processInterval: RefreshInterval {
        didSet { defaults.set(processInterval.rawValue, forKey: Key.processInterval) }
    }

    @Published var appearance: OverlayAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    @Published var tintStrength: Double {
        didSet { defaults.set(tintStrength, forKey: Key.tintStrength) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let metricsValue = defaults.object(forKey: Key.metricsInterval) as? Double
        metricsInterval = metricsValue.flatMap(RefreshInterval.init(rawValue:)) ?? .oneSecond

        let processValue = defaults.object(forKey: Key.processInterval) as? Double
        processInterval = processValue.flatMap(RefreshInterval.init(rawValue:)) ?? .twoSeconds

        let appearanceValue = defaults.string(forKey: Key.appearance)
        appearance = appearanceValue.flatMap(OverlayAppearance.init(rawValue:)) ?? .ocean

        let savedTint = defaults.object(forKey: Key.tintStrength) as? Double
        tintStrength = min(0.45, max(0, savedTint ?? 0.2))
    }

    func reset() {
        metricsInterval = .oneSecond
        processInterval = .twoSeconds
        appearance = .ocean
        tintStrength = 0.2
    }
}
