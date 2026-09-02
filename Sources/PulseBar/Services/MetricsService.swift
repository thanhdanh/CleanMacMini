import Combine
import Foundation

@MainActor
final class MetricsService: ObservableObject {
    @Published private(set) var snapshot = SystemMetrics()

    private let sampler = MetricsSampler()
    private var timer: Timer?
    private var fastMode = false

    func start() {
        stop()
        Task { await tick() }
        schedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setFastMode(_ enabled: Bool) {
        guard fastMode != enabled else { return }
        fastMode = enabled
        if timer != nil {
            schedule()
        }
    }

    private var interval: TimeInterval {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return 2.0
        }
        return fastMode ? 0.8 : 1.2
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
    }
}
