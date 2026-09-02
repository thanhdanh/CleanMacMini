import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    let state = AppState()
    private var overlay: OverlayPanelController?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayPanelController(state: state)
        overlay?.show()
        state.metrics.start()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlay?.pinToTopRightIfNeeded()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        state.metrics.stop()
        state.processes.stop()
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case processes = "Processes"
        case memory = "Memory"
        case clean = "Clean"
        var id: String { rawValue }
    }

    let metrics = MetricsService()
    let processes = ProcessService()
    let memory = MemoryReliefService()
    let disk = DiskCleanerService()
    let loginItem = LoginItemService()

    @Published var isExpanded = false {
        didSet {
            if isExpanded {
                processes.start()
            } else {
                processes.stop()
                metrics.setFastMode(false)
            }
        }
    }

    @Published var selectedTab: Tab = .processes
    @Published var userMovedOverlay = false
}
