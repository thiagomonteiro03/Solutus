import AppKit
import Testing
@testable import Solutus

/// `ScreenCapture` calls `ScreenCaptureKit` directly, which requires Screen
/// Recording permission. In CI or headless xctest, the capture returns `nil`.
/// The tests here validate the defensive contract:
///
/// - `capture()` is `async` and never throws (returns Optional)
/// - returns `nil` without crashing when there's no permission/display
@Suite("ScreenCapture")
struct ScreenCaptureTests {

    @Test("capture() returns Optional<NSImage> without throwing")
    func captureReturnsOptionalWithoutThrowing() async {
        // The signature is `async -> NSImage?` (no throws), so any internal
        // failure is converted to nil. This test ensures that contract is
        // preserved.
        let result: NSImage? = await ScreenCapture.capture()
        // We don't assert non-nil — that depends on the environment. We only
        // ensure the call completes without crashing.
        _ = result
    }

    @Test("capture() is safe when called in parallel")
    func captureIsSafeInParallel() async {
        async let a = ScreenCapture.capture()
        async let b = ScreenCapture.capture()
        async let c = ScreenCapture.capture()
        _ = await (a, b, c)
    }
}
