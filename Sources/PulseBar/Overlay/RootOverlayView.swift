import SwiftUI

enum OverlayMotion {
    static let resize = Animation.easeInOut(duration: 0.22)
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct RootOverlayView: View {
    @ObservedObject var state: AppState
    var onSizeChange: ((CGSize) -> Void)?
    var onDragChange: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onResetPosition: (() -> Void)?

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            LiveChipView(service: state.metrics, expanded: state.isExpanded)
                .contentShape(Rectangle())
                .simultaneousGesture(headerDragGesture)
                .onTapGesture(count: 2, perform: toggleExpanded)
                .help("Double-click to \(state.isExpanded ? "collapse" : "expand"). Drag to move PulseBar.")
                .contextMenu {
                    Toggle("Open at Login", isOn: Binding(
                        get: { state.loginItem.isEnabled },
                        set: { _ in state.loginItem.toggle() }
                    ))
                    Button("Reset position") {
                        onResetPosition?()
                    }
                    Divider()
                    Button("Quit PulseBar") {
                        NSApplication.shared.terminate(nil)
                    }
                }

            if state.isExpanded {
                ExpandedPanelView(
                    state: state,
                    onDragChange: onDragChange,
                    onDragEnd: onDragEnd
                )
                    .transition(.identity)
            }
        }
        .padding(8)
        .background { PanelBackground(preferences: state.preferences) }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.32), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { size in
            onSizeChange?(size)
        }
        .animation(OverlayMotion.resize, value: state.isExpanded)
    }

    private var headerDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { _ in onDragChange?() }
            .onEnded { _ in onDragEnd?() }
    }

    private func toggleExpanded() {
        withAnimation(OverlayMotion.resize) {
            state.isExpanded.toggle()
        }
    }

}

private struct LiveChipView: View {
    @ObservedObject var service: MetricsService
    let expanded: Bool

    var body: some View {
        ChipView(metrics: service.snapshot, expanded: expanded)
    }
}

private struct PanelBackground: View {
    @ObservedObject var preferences: PreferencesService

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(preferences.tintStrength)
                )
            }
    }

    private var gradientColors: [Color] {
        switch preferences.appearance {
        case .ocean:
            [.blue, .indigo, .purple, .orange.opacity(0.7)]
        case .aurora:
            [.green, .teal, .blue, .purple]
        case .sunset:
            [.orange, .pink, .purple, .indigo]
        case .graphite:
            [.gray, .black, .gray.opacity(0.7)]
        }
    }
}
