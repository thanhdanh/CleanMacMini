import AppKit
import Foundation

struct ProcessInfoItem: Identifiable, Equatable {
    var id: pid_t { pid }
    let pid: pid_t
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let isApp: Bool
    let isProtected: Bool
    let icon: NSImage?
    let processCount: Int

    init(
        pid: pid_t,
        name: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        isApp: Bool,
        isProtected: Bool,
        icon: NSImage?,
        processCount: Int = 1
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.isApp = isApp
        self.isProtected = isProtected
        self.icon = icon
        self.processCount = processCount
    }

    static func == (lhs: ProcessInfoItem, rhs: ProcessInfoItem) -> Bool {
        lhs.pid == rhs.pid
            && lhs.name == rhs.name
            && lhs.cpuPercent == rhs.cpuPercent
            && lhs.memoryBytes == rhs.memoryBytes
            && lhs.isApp == rhs.isApp
            && lhs.isProtected == rhs.isProtected
            && lhs.processCount == rhs.processCount
    }
}

enum ProcessSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    var id: String { rawValue }
}
