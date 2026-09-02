import Darwin
import Foundation

struct RawProcessUsage: Sendable {
    let pid: pid_t
    let parentPID: pid_t
    let cpuPercent: Double
    let memoryBytes: UInt64
}

private struct CPUSample {
    let user: UInt64
    let system: UInt64
    let timestamp: TimeInterval
}

actor ProcessSampler {
    private var previous: [pid_t: CPUSample] = [:]
    private let cpuCount = max(1, Double(ProcessInfo.processInfo.processorCount))

    func snapshot(sort: ProcessSort) -> [RawProcessUsage] {
        let pids = allPids()
        var usage: [RawProcessUsage] = []
        usage.reserveCapacity(min(pids.count, 256))
        var nextPrevious: [pid_t: CPUSample] = [:]
        nextPrevious.reserveCapacity(pids.count)
        let now = ProcessInfo.processInfo.systemUptime

        for pid in pids where pid > 0 {
            guard let task = taskInfo(pid) else { continue }
            let sample = CPUSample(user: task.pti_total_user, system: task.pti_total_system, timestamp: now)
            nextPrevious[pid] = sample
            var cpu = 0.0
            if let last = previous[pid] {
                let deltaNs = (sample.user &- last.user) + (sample.system &- last.system)
                let deltaT = max(0.001, now - last.timestamp)
                cpu = min(100 * cpuCount, (Double(deltaNs) / 1_000_000_000 / deltaT / cpuCount) * 100)
            }
            usage.append(
                RawProcessUsage(
                    pid: pid,
                    parentPID: parentPID(pid),
                    cpuPercent: cpu,
                    memoryBytes: task.pti_resident_size
                )
            )
        }

        previous = nextPrevious

        switch sort {
        case .cpu:
            usage.sort { $0.cpuPercent > $1.cpuPercent }
        case .memory:
            usage.sort { $0.memoryBytes > $1.memoryBytes }
        }

        return usage
    }

    private func allPids() -> [pid_t] {
        let raw = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard raw > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(raw) / MemoryLayout<pid_t>.size + 8)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }
        let count = Int(filled) / MemoryLayout<pid_t>.size
        return Array(pids.prefix(count))
    }

    private func taskInfo(_ pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.stride)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard result == size else { return nil }
        return info
    }

    private func parentPID(_ pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return 0 }
        return pid_t(info.pbi_ppid)
    }
}
