import Foundation

struct MetricHistoryPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let cpuPercent: Double
    let memoryPercent: Double
}
