import Foundation

struct DiskItem: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let bytes: UInt64
}

struct DiskCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    var items: [DiskItem]
    var isSelected: Bool

    var bytes: UInt64 {
        items.reduce(0) { $0 + $1.bytes }
    }
}
