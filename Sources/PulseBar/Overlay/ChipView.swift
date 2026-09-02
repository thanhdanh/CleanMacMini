import SwiftUI

struct ChipView: View {
    let metrics: SystemMetrics
    let expanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            metric(symbol: "cpu", label: "CPU", value: String(format: "%.0f%%", metrics.cpuPercent))

            Divider()
                .frame(height: 18)

            metric(
                symbol: "memorychip",
                label: "RAM",
                value: ByteFormat.shortGB(metrics.memoryUsedBytes)
            )

            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .padding(.horizontal, 8)
        .frame(height: 28)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "CPU \(Int(metrics.cpuPercent)) percent, memory \(ByteFormat.string(metrics.memoryUsedBytes)) used"
        )
    }

    private func metric(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(accentColor)
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
        }
    }

    private var accentColor: Color {
        switch metrics.pressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}
