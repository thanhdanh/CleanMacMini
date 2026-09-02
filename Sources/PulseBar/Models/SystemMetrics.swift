import Foundation

enum MemoryPressure: Equatable {
    case normal
    case warning
    case critical
}

struct SystemMetrics: Equatable {
    var cpuPercent: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var inactiveBytes: UInt64 = 0
    var purgeableBytes: UInt64 = 0
    var compressorBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var pressure: MemoryPressure = .normal

    var memoryUsedRatio: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return min(1, Double(memoryUsedBytes) / Double(memoryTotalBytes))
    }

    var reclaimableBytes: UInt64 {
        inactiveBytes + purgeableBytes
    }
}
