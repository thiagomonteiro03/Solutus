import AppKit
import SwiftUI
import Testing
@testable import Solutus

/// Covers the lifecycle of the hub window: lazy creation, show/hide/toggle,
/// reuse of the same `NSWindow`, and chrome configuration (titled window vs.
/// the borderless floating panel used by the overlay).
@Suite("HubWindowController")
@MainActor
struct HubWindowControllerTests {

    // MARK: - Helpers

    private func makeController(features: [Feature] = []) -> HubWindowController {
        HubWindowController(features: features)
    }

    /// Reaches into the controller's private `window` via reflection. Same
    /// pattern used in `OverlayWindowControllerTests`.
    private func extractWindow(from controller: HubWindowController) -> NSWindow? {
        let mirror = Mirror(reflecting: controller)
        return mirror.children.first { $0.label == "window" }?.value as? NSWindow
    }

    // MARK: - Lifecycle

    @Test("init does not create the NSWindow (setup is lazy until first show)")
    func initIsLazy() {
        let controller = makeController()

        #expect(extractWindow(from: controller) == nil)
    }

    @Test("show creates the window and makes it visible")
    func showCreatesAndDisplays() {
        let controller = makeController()
        controller.show()
        defer { controller.hide() }

        let window = extractWindow(from: controller)
        #expect(window != nil)
        #expect(window?.isVisible == true)
    }

    @Test("hide without a previous show is safe")
    func hideWithoutShowIsSafe() {
        let controller = makeController()

        // Must not crash or throw.
        controller.hide()
        #expect(extractWindow(from: controller) == nil)
    }

    @Test("show called twice reuses the same NSWindow")
    func showReusesSameWindow() {
        let controller = makeController()
        controller.show()
        let first = extractWindow(from: controller)

        controller.show()
        let second = extractWindow(from: controller)
        defer { controller.hide() }

        #expect(first === second)
    }

    @Test("toggle alternates between visible and hidden")
    func toggleAlternatesVisibility() {
        let controller = makeController()

        controller.toggle()
        #expect(extractWindow(from: controller)?.isVisible == true)

        controller.toggle()
        #expect(extractWindow(from: controller)?.isVisible == false)
    }

    // MARK: - Window configuration

    @Test("window is titled and closable (standard macOS chrome)")
    func windowHasStandardChrome() {
        let controller = makeController()
        controller.show()
        defer { controller.hide() }

        let window = extractWindow(from: controller)
        // Unlike OverlayWindowController (a borderless panel that's invisible
        // in screen sharing), the hub window is a regular titled window.
        #expect(window?.styleMask.contains(.titled) == true)
        #expect(window?.styleMask.contains(.closable) == true)
        #expect(window?.styleMask.contains(.resizable) == true)
        #expect(window?.title == "Solutus Hub")
    }

    @Test("contentView hosts HubView via NSHostingView")
    func contentViewHostsHubView() {
        let controller = makeController()
        controller.show()
        defer { controller.hide() }

        let window = extractWindow(from: controller)
        #expect(window?.contentView is NSHostingView<HubView>)
    }

    @Test("isReleasedWhenClosed = false (controller keeps the window alive)")
    func windowSurvivesClose() {
        let controller = makeController()
        controller.show()
        defer { controller.hide() }

        // Important: if isReleasedWhenClosed were true, the user closing the
        // window would deallocate the NSWindow, and the next show() would
        // crash trying to reuse the dangling reference.
        #expect(extractWindow(from: controller)?.isReleasedWhenClosed == false)
    }
}
