import SwiftUI

struct ChipView: View {
    let metrics: SystemMetrics
    let expanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            metric(symbol: "cpu", label: "CPU", value: String(format: "%.0f%%", metrics.cpuPercent))

            Divider()
                .frame(height: 18)

            memoryMetric

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
            "CPU \(Int(metrics.cpuPercent)) percent, memory \(ByteFormat.string(metrics.memoryUsedBytes)) used of \(ByteFormat.string(metrics.memoryTotalBytes))"
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

    private var memoryMetric: some View {
        HStack(spacing: 5) {
            Image(systemName: "memorychip")
                .foregroundStyle(accentColor)
            Text("RAM")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            MemoryUsageRing(ratio: metrics.memoryUsedRatio, color: accentColor)
            Text(ByteFormat.compactMemoryUsage(
                used: metrics.memoryUsedBytes,
                total: metrics.memoryTotalBytes
            ))
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

private struct MemoryUsageRing: View {
    let ratio: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: min(max(ratio, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 13, height: 13)
        .animation(.easeOut(duration: 0.2), value: ratio)
        .accessibilityHidden(true)
    }
}
