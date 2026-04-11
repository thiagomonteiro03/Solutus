import AppKit
import SwiftUI

/// Janela flutuante que exibe a solução do algoritmo.
/// `sharingType = .none` garante que ela seja INVISÍVEL em compartilhamento de tela.
@MainActor
class OverlayWindowController {

    private var window: NSWindow?

    // MARK: - Show / Hide

    func show(content: OverlayContent) {
        if window == nil { setupWindow() }
        guard let window else { return }

        updateContent(content)

        if !window.isVisible {
            positionWindow()
            window.makeKeyAndOrderFront(nil)
            window.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                window.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard let window, window.isVisible else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    // MARK: - Setup

    private func setupWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.level = .floating
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // ✅ INVISÍVEL ao screen sharing e gravação de tela
        w.sharingType = .none

        self.window = w
    }

    private func positionWindow() {
        guard let window, let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.maxX - 440
        let y = screen.visibleFrame.minY + 20
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateContent(_ content: OverlayContent) {
        guard let window else { return }
        let view = OverlayView(content: content) { [weak self] in
            self?.hide()
        }
        window.contentView = NSHostingView(rootView: view)
    }
}
