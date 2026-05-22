import AppKit
import Testing
@testable import Solutus

/// Tests the lifecycle of the floating window. Since the window requires a
/// graphical session, the tests run under `@MainActor` and avoid animations.
@Suite("OverlayWindowController")
@MainActor
struct OverlayWindowControllerTests {

    @Test("show creates the window and makes it visible")
    func showCreatesWindow() {
        let controller = OverlayWindowController()
        controller.show(content: .loading)

        // Reach into the NSWindow via reflection since it's private.
        let mirror = Mirror(reflecting: controller)
        let window = mirror.children.first { $0.label == "window" }?.value as? NSWindow
        #expect(window != nil)
        #expect(window?.isVisible == true)

        controller.hide()
    }

    @Test("calling show twice reuses the same window")
    func showReusesWindow() {
        let controller = OverlayWindowController()
        controller.show(content: .loading)
        let mirror1 = Mirror(reflecting: controller)
        let window1 = mirror1.children.first { $0.label == "window" }?.value as? NSWindow

        controller.show(content: .solution(text: "another content", source: .algorithmHelper))
        let mirror2 = Mirror(reflecting: controller)
        let window2 = mirror2.children.first { $0.label == "window" }?.value as? NSWindow

        #expect(window1 === window2)
        controller.hide()
    }

    @Test("window is invisible to screen recording")
    func windowIsScreenRecordingInvisible() {
        let controller = OverlayWindowController()
        controller.show(content: .loading)

        let mirror = Mirror(reflecting: controller)
        let window = mirror.children.first { $0.label == "window" }?.value as? NSWindow

        // Core product property: the window MUST NOT appear in screen sharing
        // or recording. If anyone removes that line, this test breaks
        // immediately.
        #expect(window?.sharingType.rawValue == 0)
        #expect(window?.level == .floating)
        #expect(window?.isOpaque == false)
        #expect(window?.hasShadow == false)

        controller.hide()
    }

    @Test("hide is safe when window was never shown")
    func hideWithoutShowIsSafe() {
        let controller = OverlayWindowController()
        controller.hide() // must not throw nor crash
    }

    @Test("show accepts all content types sequentially")
    func showAcceptsAllContentTypes() {
        let controller = OverlayWindowController()
        let states: [OverlayContent] = [
            .captured(count: 1),
            .captured(count: 3),
            .loading,
            .solution(text: "x = 42", source: .algorithmHelper),
            .solution(text: "lifecycle answer", source: .androidHelper),
            .error("boom")
        ]
        for state in states {
            controller.show(content: state)
        }
        controller.hide()
    }
}
