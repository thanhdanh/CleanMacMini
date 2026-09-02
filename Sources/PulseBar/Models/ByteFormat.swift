import Foundation

enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        f.allowedUnits = [.useMB, .useGB]
        f.isAdaptive = true
        return f
    }()

    static func string(_ bytes: UInt64) -> String {
        formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    static func shortGB(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 10 {
            return String(format: "%.0f GB", gb)
        }
        return String(format: "%.1f GB", gb)
    }

    static func compactMemoryUsage(used: UInt64, total: UInt64) -> String {
        "\(compactGigabytes(used))/\(compactGigabytes(total))G"
    }

    private static func compactGigabytes(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824
        if gigabytes >= 10 || abs(gigabytes.rounded() - gigabytes) < 0.05 {
            return String(format: "%.0f", gigabytes)
        }
        return String(format: "%.1f", gigabytes)
    }
}
