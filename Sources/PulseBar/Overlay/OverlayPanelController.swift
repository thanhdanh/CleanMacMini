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
    private var dragStartMouseLocation: NSPoint?
    private var isUserDragging = false
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
            onDragChange: { [weak self] in
                self?.movePanelToMouse()
            },
            onDragEnd: { [weak self] in
                self?.endPanelDrag()
            },
            onResetPosition: { [weak self] in
                guard let self else { return }
                self.dragStartOrigin = nil
                self.dragStartMouseLocation = nil
                self.isUserDragging = false
                self.state.userMovedOverlay = false
                self.pinToDefaultPositionIfNeeded()
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
        pinToDefaultPositionIfNeeded()
        panel.orderFrontRegardless()
    }

    func pinToDefaultPositionIfNeeded() {
        guard !state.userMovedOverlay else { return }
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.minX + 14,
            y: visible.minY + 10
        )
        performProgrammaticMove {
            panel.setFrameOrigin(origin)
        }
    }

    private func applyContentSize(_ size: NSSize) {
        let padded = NSSize(width: max(320, ceil(size.width)), height: max(40, ceil(size.height)))
        var frame = panel.frame
        frame.size = padded
        if !state.userMovedOverlay, let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin = NSPoint(
                x: visible.minX + 14,
                y: visible.minY + 10
            )
        }
        performProgrammaticMove {
            panel.setFrame(frame, display: true)
        }
    }

    private func movePanelToMouse() {
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouseLocation = NSEvent.mouseLocation
            isUserDragging = true
        }
        guard let start = dragStartOrigin,
              let mouseStart = dragStartMouseLocation else { return }
        let mouseNow = NSEvent.mouseLocation
        panel.setFrameOrigin(
            NSPoint(
                x: start.x + mouseNow.x - mouseStart.x,
                y: start.y + mouseNow.y - mouseStart.y
            )
        )
    }

    private func endPanelDrag() {
        dragStartOrigin = nil
        dragStartMouseLocation = nil
        isUserDragging = false
        if !state.userMovedOverlay {
            state.userMovedOverlay = true
        }
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
        guard !isProgrammaticMove, !isUserDragging else { return }
        if !state.userMovedOverlay {
            state.userMovedOverlay = true
        }
    }
}
