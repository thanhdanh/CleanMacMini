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

    var body: some View {
        VStack(spacing: 0) {
            ChipView(metrics: state.metrics.snapshot, expanded: state.isExpanded)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        state.isExpanded.toggle()
                    }
                    state.metrics.setFastMode(state.isExpanded)
                }
                .contextMenu {
                    Toggle("Open at Login", isOn: Binding(
                        get: { state.loginItem.isEnabled },
                        set: { _ in state.loginItem.toggle() }
                    ))
                    Button("Reset position") {
                        state.userMovedOverlay = false
                        AppDelegate.shared?.applicationDidFinishLaunching(Notification(name: Notification.Name("reset")))
                    }
                    Divider()
                    Button("Quit PulseBar") {
                        NSApplication.shared.terminate(nil)
                    }
                }

            if state.isExpanded {
                ExpandedPanelView(state: state)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { size in
            onSizeChange?(size)
        }
        .padding(2)
    }
}
