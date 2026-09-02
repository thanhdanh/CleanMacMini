import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayPanelController: NSObject {
    private let state: AppState
    private let panel: OverlayPanel
    private let hosting: NSHostingView<RootOverlayView>
    private var dragStartOrigin: NSPoint?
    private var isProgrammaticMove = false

    init(state: AppState) {
        self.state = state
        let root = RootOverlayView(state: state)
        hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 44)

        panel = OverlayPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        hosting.rootView = RootOverlayView(
            state: state,
            onSizeChange: { [weak self] size in
                self?.applyContentSize(size)
            },
            onDragChange: { [weak self] translation in
                self?.movePanel(by: translation)
            },
            onDragEnd: { [weak self] in
                self?.dragStartOrigin = nil
            },
            onResetPosition: { [weak self] in
                guard let self else { return }
                self.dragStartOrigin = nil
                self.state.userMovedOverlay = false
                self.pinToTopRightIfNeeded()
            }
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.contentView = hosting
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
    }

    func show() {
        applyContentSize(NSSize(width: 320, height: 44))
        pinToTopRightIfNeeded()
        panel.orderFrontRegardless()
    }

    func pinToTopRightIfNeeded() {
        guard !state.userMovedOverlay else { return }
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - 14,
            y: visible.maxY - size.height - 10
        )
        performProgrammaticMove {
            panel.setFrameOrigin(origin)
        }
    }

    private func applyContentSize(_ size: NSSize) {
        let padded = NSSize(width: max(280, ceil(size.width)), height: max(40, ceil(size.height)))
        var frame = panel.frame
        let top = frame.maxY
        let right = frame.maxX
        frame.size = padded
        if state.userMovedOverlay {
            frame.origin = NSPoint(x: right - padded.width, y: top - padded.height)
        } else if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin = NSPoint(
                x: visible.maxX - padded.width - 14,
                y: visible.maxY - padded.height - 10
            )
        }
        performProgrammaticMove {
            panel.setFrame(frame, display: true)
        }
    }

    private func movePanel(by translation: CGSize) {
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
        }
        guard let start = dragStartOrigin else { return }
        state.userMovedOverlay = true
        panel.setFrameOrigin(
            NSPoint(
                x: start.x + translation.width,
                y: start.y - translation.height
            )
        )
    }

    private func performProgrammaticMove(_ action: () -> Void) {
        isProgrammaticMove = true
        action()
        DispatchQueue.main.async { [weak self] in
            self?.isProgrammaticMove = false
        }
    }
}

extension OverlayPanelController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard !isProgrammaticMove else { return }
        state.userMovedOverlay = true
    }
}
