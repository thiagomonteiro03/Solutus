import AppKit
import SwiftUI

/// Main window of the hub.
///
/// Unlike `OverlayWindowController` (a borderless floating panel that's
/// invisible during screen sharing), the hub is a regular window with the
/// standard macOS chrome — the user interacts with it directly, it's not a
/// passive display surface.
///
/// Receives features by DI; does not know about the registry.
@MainActor
final class HubWindowController {

    private let features: [Feature]
    private var window: NSWindow?

    init(features: [Feature]) {
        self.features = features
    }

    // MARK: - Show / Hide

    func toggle() {
        guard let window, window.isVisible else {
            show()
            return
        }
        hide()
    }

    func show() {
        if window == nil { setupWindow() }
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    // MARK: - Setup

    private func setupWindow() {
        let hub = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        hub.title = "Solutus Hub"
        hub.center()
        hub.isReleasedWhenClosed = false
        hub.contentView = NSHostingView(rootView: HubView(features: features))
        self.window = hub
    }
}
