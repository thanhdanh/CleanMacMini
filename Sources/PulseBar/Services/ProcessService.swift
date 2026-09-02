import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class ProcessService: ObservableObject {
    @Published private(set) var items: [ProcessInfoItem] = []
    @Published private(set) var applications: [ProcessInfoItem] = []
    @Published var sort: ProcessSort = .cpu {
        didSet { Task { await refresh() } }
    }
    @Published var query = "" {
        didSet { scheduleQueryRefresh() }
    }

    private let sampler = ProcessSampler()
    private var timer: Timer?
    private var queryTask: Task<Void, Never>?
    private var refreshInterval: TimeInterval
    private var preferencesCancellable: AnyCancellable?

    private static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "cfprefsd",
        "PulseBar", "syspolicyd", "runningboardd", "logd"
    ]

    init(preferences: PreferencesService) {
        refreshInterval = preferences.processInterval.rawValue
        preferencesCancellable = preferences.$processInterval
            .dropFirst()
            .sink { [weak self] interval in
                guard let self else { return }
                self.refreshInterval = interval.rawValue
                if self.timer != nil {
                    self.start()
                }
            }
    }

    func start() {
        stop()
        Task { await refresh() }
        let interval = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? max(2, refreshInterval)
            : refreshInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        timer.tolerance = interval * 0.2
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
        let raw = await sampler.snapshot(sort: sort)

        var byPid: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            byPid[app.processIdentifier] = app
        }

        let regularApps = byPid.filter { $0.value.activationPolicy == .regular }
        let regularPIDs = Set(regularApps.keys)
        let parentByPID = Dictionary(uniqueKeysWithValues: raw.map { ($0.pid, $0.parentPID) })
        var appUsage: [pid_t: (cpu: Double, memory: UInt64)] = [:]

        for row in raw {
            guard let ownerPID = Self.ownerApplicationPID(
                for: row.pid,
                applicationPIDs: regularPIDs,
                parentByPID: parentByPID
            ) else { continue }
            var usage = appUsage[ownerPID] ?? (cpu: 0, memory: 0)
            usage.cpu += row.cpuPercent
            usage.memory += row.memoryBytes
            appUsage[ownerPID] = usage
        }

        applications = regularApps.compactMap { pid, app in
            guard let name = app.localizedName else { return nil }
            let usage = appUsage[pid] ?? (cpu: 0, memory: 0)
            return ProcessInfoItem(
                pid: pid,
                name: name,
                cpuPercent: usage.cpu,
                memoryBytes: usage.memory,
                isApp: true,
                isProtected: Self.isProtected(name: name, pid: pid),
                icon: app.icon
            )
        }
        .sorted { lhs, rhs in
            if lhs.memoryBytes == rhs.memoryBytes { return lhs.name < rhs.name }
            return lhs.memoryBytes > rhs.memoryBytes
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

    private static func ownerApplicationPID(
        for pid: pid_t,
        applicationPIDs: Set<pid_t>,
        parentByPID: [pid_t: pid_t]
    ) -> pid_t? {
        var current = pid
        var visited: Set<pid_t> = []

        for _ in 0..<32 {
            if applicationPIDs.contains(current) { return current }
            guard current > 1, visited.insert(current).inserted,
                  let parent = parentByPID[current], parent != current else { return nil }
            current = parent
        }
        return nil
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
