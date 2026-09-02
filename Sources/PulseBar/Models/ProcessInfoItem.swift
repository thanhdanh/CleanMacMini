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

    static func == (lhs: ProcessInfoItem, rhs: ProcessInfoItem) -> Bool {
        lhs.pid == rhs.pid
            && lhs.name == rhs.name
            && lhs.cpuPercent == rhs.cpuPercent
            && lhs.memoryBytes == rhs.memoryBytes
            && lhs.isApp == rhs.isApp
            && lhs.isProtected == rhs.isProtected
    }
}

enum ProcessSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    var id: String { rawValue }
}
