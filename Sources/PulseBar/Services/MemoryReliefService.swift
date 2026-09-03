import AppKit
import Combine
import Foundation

@MainActor
final class MemoryReliefService: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var lastMessage: String?
    @Published private(set) var lastFreedBytes: UInt64 = 0

    func freeUp(metrics: SystemMetrics) async {
        guard !isWorking else { return }
        isWorking = true
        lastMessage = nil
        lastFreedBytes = 0
        let before = metrics.memoryUsedBytes

        URLCache.shared.removeAllCachedResponses()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 700_000_000)

        let purged = await Self.runPurgeIfAvailable()
        try? await Task.sleep(nanoseconds: 400_000_000)

        let afterSampler = MetricsSampler()
        let after = await afterSampler.sample()
        let freed = before > after.memoryUsedBytes ? before - after.memoryUsedBytes : 0
        lastFreedBytes = freed

        if purged {
            lastMessage = freed > 0
                ? "Freed about \(ByteFormat.string(freed)). macOS may reuse some of it for helpful caches."
                : "Memory was optimized. The used total may stay similar while macOS keeps helpful caches."
        } else {
            lastMessage = freed > 0
                ? "Freed about \(ByteFormat.string(freed)) without quitting apps."
                : "Memory cleanup was cancelled or isn't available on this Mac."
        }
        isWorking = false
    }

    private static func runPurgeIfAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let purge = "/usr/sbin/purge"
                let path = FileManager.default.fileExists(atPath: purge) ? purge : "/usr/bin/purge"
                guard FileManager.default.fileExists(atPath: path) else {
                    continuation.resume(returning: false)
                    return
                }
                let script = """
                do shell script quoted form of "\(path)" with administrator privileges
                """
                var error: NSDictionary?
                let apple = NSAppleScript(source: script)
                _ = apple?.executeAndReturnError(&error)
                continuation.resume(returning: error == nil)
            }
        }
    }
}
