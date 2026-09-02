import Foundation

enum AppVersion {
    private static let fallback = "1.0.0"

    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallback
    }

    static var display: String {
        "v\(current)"
    }
}
