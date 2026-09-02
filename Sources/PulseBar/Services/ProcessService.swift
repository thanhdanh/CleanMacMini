import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class ProcessService: ObservableObject {
    @Published private(set) var items: [ProcessInfoItem] = []
    @Published var sort: ProcessSort = .cpu {
        didSet { Task { await refresh() } }
    }
    @Published var query = "" {
        didSet { scheduleQueryRefresh() }
    }

    private let sampler = ProcessSampler()
    private var timer: Timer?
    private var queryTask: Task<Void, Never>?

    private static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "cfprefsd",
        "PulseBar", "syspolicyd", "runningboardd", "logd"
    ]

    func start() {
        stop()
        Task { await refresh() }
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        timer.tolerance = 0.4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        queryTask?.cancel()
    }

    func quit(_ item: ProcessInfoItem, force: Bool) -> String? {
        if item.isProtected {
            return "System process — PulseBar will not stop it."
        }
        if let app = NSRunningApplication(processIdentifier: item.pid) {
            let ok = force ? app.forceTerminate() : app.terminate()
            if ok {
                items.removeAll { $0.pid == item.pid }
                return nil
            }
        }
        let signal = force ? SIGKILL : SIGTERM
        if kill(item.pid, signal) == 0 {
            items.removeAll { $0.pid == item.pid }
            return nil
        }
        return "Could not stop \(item.name). You may not own this process."
    }

    private func scheduleQueryRefresh() {
        queryTask?.cancel()
        queryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func refresh() async {
        let sort = sort
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let raw = await sampler.snapshot(sort: sort, limit: 40)

        var byPid: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            byPid[app.processIdentifier] = app
        }

        var next: [ProcessInfoItem] = []
        next.reserveCapacity(40)
        for row in raw {
            if next.count >= 40 { break }
            let app = byPid[row.pid]
            let name = app?.localizedName ?? Self.processName(row.pid)
            if name.isEmpty { continue }
            if !query.isEmpty, !name.lowercased().contains(query), !String(row.pid).contains(query) {
                continue
            }
            next.append(
                ProcessInfoItem(
                    pid: row.pid,
                    name: name,
                    cpuPercent: row.cpuPercent,
                    memoryBytes: row.memoryBytes,
                    isApp: app?.activationPolicy == .regular,
                    isProtected: Self.isProtected(name: name, pid: row.pid),
                    icon: app?.icon
                )
            )
        }
        items = next
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 64)
        let result = proc_name(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return "" }
        return String(cString: buffer)
    }

    private static func isProtected(name: String, pid: pid_t) -> Bool {
        pid <= 1 || protectedNames.contains(name)
    }
}
