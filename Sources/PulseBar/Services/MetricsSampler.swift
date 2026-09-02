import Darwin
import Foundation

actor MetricsSampler {
    private var previousCPU: host_cpu_load_info?
    private let pageSize: UInt64 = {
        var size = vm_size_t(0)
        host_page_size(mach_host_self(), &size)
        return UInt64(size == 0 ? 4096 : size)
    }()

    func sample() -> SystemMetrics {
        var metrics = SystemMetrics()
        metrics.memoryTotalBytes = ProcessInfo.processInfo.physicalMemory
        metrics.cpuPercent = sampleCPU()
        sampleMemory(&metrics)
        return metrics
    }

    private func sampleCPU() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        defer { previousCPU = info }
        guard let previousCPU else { return 0 }

        let user = UInt64(info.cpu_ticks.0) &- UInt64(previousCPU.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1) &- UInt64(previousCPU.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2) &- UInt64(previousCPU.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3) &- UInt64(previousCPU.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return min(100, Double(user + system + nice) / Double(total) * 100)
    }

    private func sampleMemory(_ metrics: inout SystemMetrics) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        let ps = pageSize
        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)
        let appPages = internalPages > purgeable ? internalPages - purgeable : 0

        metrics.wiredBytes = wired * ps
        metrics.compressorBytes = compressed * ps
        metrics.purgeableBytes = purgeable * ps
        metrics.inactiveBytes = UInt64(stats.inactive_count) * ps
        metrics.freeBytes = UInt64(stats.free_count) * ps
        metrics.memoryUsedBytes = min(metrics.memoryTotalBytes, (appPages + wired + compressed) * ps)

        let ratio = metrics.memoryUsedRatio
        if ratio >= 0.9 || compressed > UInt64(stats.active_count) {
            metrics.pressure = .critical
        } else if ratio >= 0.75 {
            metrics.pressure = .warning
        } else {
            metrics.pressure = .normal
        }
    }
}
