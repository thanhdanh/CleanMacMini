import Combine
import Foundation

@MainActor
final class DiskCleanerService: ObservableObject {
    @Published private(set) var categories: [DiskCategory] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var diskFreeBytes: UInt64 = 0
    @Published private(set) var diskTotalBytes: UInt64 = 0
    @Published private(set) var lastMessage: String?
    @Published var largeFileThresholdMB: Int = 100

    private var scanTask: Task<Void, Never>?

    var selectedBytes: UInt64 {
        categories.filter(\.isSelected).reduce(0) { $0 + $1.bytes }
    }

    func refreshVolumeStats() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        if let free = values?.volumeAvailableCapacityForImportantUsage {
            diskFreeBytes = UInt64(free)
        }
        if let total = values?.volumeTotalCapacity {
            diskTotalBytes = UInt64(total)
        }
    }

    func scan() {
        scanTask?.cancel()
        isScanning = true
        lastMessage = nil
        refreshVolumeStats()
        let threshold = UInt64(max(20, largeFileThresholdMB)) * 1_048_576
        scanTask = Task.detached(priority: .utility) { [weak self] in
            let result = DiskScanner.scan(largeFileMinBytes: threshold)
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.categories = result
                self.isScanning = false
            }
        }
    }

    func toggleCategory(_ id: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[index].isSelected.toggle()
    }

    func cleanSelected() async {
        guard !isCleaning else { return }
        let toDelete = categories.filter(\.isSelected)
        guard !toDelete.isEmpty else { return }
        isCleaning = true
        lastMessage = nil
        let bytes = selectedBytes

        await Task.detached(priority: .utility) {
            for category in toDelete {
                for item in category.items {
                    try? FileManager.default.removeItem(at: item.url)
                }
            }
        }.value

        refreshVolumeStats()
        lastMessage = "Removed \(ByteFormat.string(bytes))."
        isCleaning = false
        scan()
    }
}

enum DiskScanner {
    static func scan(largeFileMinBytes: UInt64) -> [DiskCategory] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let caches = home.appendingPathComponent("Library/Caches")
        let logs = home.appendingPathComponent("Library/Logs")
        let trash = home.appendingPathComponent(".Trash")
        let derived = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")

        var categories: [DiskCategory] = []
        categories.append(folderCategory(id: "caches", title: "User caches", subtitle: "~/Library/Caches", symbol: "internaldrive", url: caches))
        categories.append(folderCategory(id: "logs", title: "Logs", subtitle: "~/Library/Logs", symbol: "doc.text", url: logs))
        categories.append(folderCategory(id: "trash", title: "Trash", subtitle: "Move items out of Trash permanently", symbol: "trash", url: trash, selected: false))

        if FileManager.default.fileExists(atPath: derived.path) {
            var derivedCat = folderCategory(id: "derived", title: "Xcode DerivedData", subtitle: "Optional developer junk", symbol: "hammer", url: derived, selected: false)
            categories.append(derivedCat)
        }

        let large = largeFiles(home: home, minBytes: largeFileMinBytes)
        categories.append(
            DiskCategory(
                id: "large",
                title: "Large files",
                subtitle: "In Desktop, Documents, Downloads, Movies",
                symbol: "doc.badge.ellipsis",
                items: large,
                isSelected: false
            )
        )
        return categories.filter { !$0.items.isEmpty || $0.id == "large" }
    }

    private static func folderCategory(id: String, title: String, subtitle: String, symbol: String, url: URL, selected: Bool = true) -> DiskCategory {
        let children = topLevelSized(url)
        return DiskCategory(id: id, title: title, subtitle: subtitle, symbol: symbol, items: children, isSelected: selected && !children.isEmpty)
    }

    private static func topLevelSized(_ url: URL) -> [DiskItem] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        return names.compactMap { child in
            let bytes = allocatedSize(at: child, budget: 8_000)
            guard bytes > 4096 else { return nil }
            return DiskItem(id: child.path, title: child.lastPathComponent, url: child, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }
    }

    private static func largeFiles(home: URL, minBytes: UInt64) -> [DiskItem] {
        let roots = ["Desktop", "Documents", "Downloads", "Movies"].map { home.appendingPathComponent($0) }
        var found: [DiskItem] = []
        var visits = 0
        let fm = FileManager.default

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let item = enumerator.nextObject() as? URL {
                visits += 1
                if visits > 25_000 || found.count >= 80 { break }
                let name = item.lastPathComponent
                if name == "node_modules" || name == ".git" {
                    enumerator.skipDescendants()
                    continue
                }
                let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                guard values?.isRegularFile == true else { continue }
                let bytes = UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                if bytes >= minBytes {
                    found.append(DiskItem(id: item.path, title: item.lastPathComponent, url: item, bytes: bytes))
                }
            }
        }
        return found.sorted { $0.bytes > $1.bytes }
    }

    private static func allocatedSize(at url: URL, budget: Int) -> UInt64 {
        var total: UInt64 = 0
        var visits = 0
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            let values = try? url.resourceValues(forKeys: keys)
            return UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        while let item = enumerator.nextObject() as? URL {
            visits += 1
            if visits > budget {
                enumerator.skipDescendants()
                break
            }
            if item.lastPathComponent == "node_modules" || item.lastPathComponent == ".git" {
                enumerator.skipDescendants()
                continue
            }
            let values = try? item.resourceValues(forKeys: keys)
            if values?.isRegularFile == true {
                total += UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            }
        }
        if total == 0 {
            let values = try? url.resourceValues(forKeys: keys)
            total = UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}
