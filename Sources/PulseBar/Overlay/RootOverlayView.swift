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
        .background {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.blue.opacity(0.20), location: 0),
                                .init(color: Color.indigo.opacity(0.16), location: 0.42),
                                .init(color: Color.purple.opacity(0.14), location: 0.68),
                                .init(color: Color.orange.opacity(0.10), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
        }
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
