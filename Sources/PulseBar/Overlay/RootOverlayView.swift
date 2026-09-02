import SwiftUI

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
    @State private var chipWasDragged = false

    var body: some View {
        VStack(spacing: 0) {
            ChipView(metrics: state.metrics.snapshot, expanded: state.isExpanded)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            let distance = hypot(value.translation.width, value.translation.height)
                            if distance >= 3 {
                                chipWasDragged = true
                                onDragChange?()
                            }
                        }
                        .onEnded { _ in
                            if chipWasDragged {
                                onDragEnd?()
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    state.isExpanded.toggle()
                                }
                            }
                            chipWasDragged = false
                        }
                )
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
