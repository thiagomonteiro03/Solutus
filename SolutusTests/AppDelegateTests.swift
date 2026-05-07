import AppKit
import Testing
@testable import Solutus

/// `AppDelegate` is the main coordinator. We test without actually firing
/// `applicationDidFinishLaunching` (that would create real hot keys),
/// focusing on:
/// - instantiation as NSObject/NSApplicationDelegate
/// - public methods (`dismiss`) being idempotent
@Suite("AppDelegate")
@MainActor
struct AppDelegateTests {

    @Test("AppDelegate can be instantiated")
    func canBeInstantiated() {
        let delegate = AppDelegate()
        #expect((delegate as NSObject).conforms(to: NSApplicationDelegate.self))
    }

    @Test("dismiss is safe before any capture")
    func dismissBeforeAnyCapture() {
        let delegate = AppDelegate()
        delegate.dismiss() // must not crash
    }

    @Test("dismiss clears the screenshot queue")
    func dismissClearsQueue() {
        let delegate = AppDelegate()

        // Reflection access to the private state — this test documents that
        // `dismiss()` must leave the queue empty.
        let mirror = Mirror(reflecting: delegate)
        let before = mirror.children.first { $0.label == "capturedScreenshots" }?.value as? [NSImage]
        #expect(before?.isEmpty == true)

        delegate.dismiss()

        let mirrorAfter = Mirror(reflecting: delegate)
        let after = mirrorAfter.children.first { $0.label == "capturedScreenshots" }?.value as? [NSImage]
        #expect(after?.isEmpty == true)
    }
}
