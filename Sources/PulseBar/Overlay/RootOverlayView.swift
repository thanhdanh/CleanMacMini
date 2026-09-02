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
                                state.metrics.setFastMode(state.isExpanded)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
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
