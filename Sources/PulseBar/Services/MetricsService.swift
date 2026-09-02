import Combine
import Foundation

@MainActor
final class MetricsService: ObservableObject {
    @Published private(set) var snapshot = SystemMetrics()
    @Published private(set) var history: [MetricHistoryPoint] = []

    private let sampler = MetricsSampler()
    private var timer: Timer?
    private var refreshInterval: TimeInterval
    private var preferencesCancellable: AnyCancellable?

    init(preferences: PreferencesService) {
        refreshInterval = preferences.metricsInterval.rawValue
        preferencesCancellable = preferences.$metricsInterval
            .dropFirst()
            .sink { [weak self] interval in
                guard let self else { return }
                self.refreshInterval = interval.rawValue
                if self.timer != nil {
                    self.schedule()
                }
            }
    }

    func start() {
        stop()
        Task { await tick() }
        schedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private var interval: TimeInterval {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return max(2, refreshInterval)
        }
        return refreshInterval
    }

    private func schedule() {
        timer?.invalidate()
        let interval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
        timer.tolerance = interval * 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() async {
        let next = await sampler.sample()
        if next != snapshot {
            snapshot = next
        }
        let point = MetricHistoryPoint(
            timestamp: Date(),
            cpuPercent: next.cpuPercent,
            memoryPercent: next.memoryUsedRatio * 100
        )
        history.append(point)
        let cutoff = point.timestamp.addingTimeInterval(-300)
        history.removeAll { $0.timestamp < cutoff }
    }
}
