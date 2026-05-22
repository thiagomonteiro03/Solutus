import AppKit
import Testing
@testable import Solutus

/// `HotKeyManager` depends on Accessibility permission and on the CoreGraphics
/// event tap — both unreachable in unit tests. We focus instead on:
/// - correct initialization (no crash)
/// - start/stop cycle without crashing when permission is missing
/// - distinct identity between instances
/// - the pure `shouldTrigger(keyCode:flags:)` mapping (extracted exactly so it
///   can be tested in isolation from the event tap)
@Suite("HotKeyManager")
@MainActor
struct HotKeyManagerTests {

    // MARK: - Lifecycle

    @Test("init does not crash and creates a valid instance")
    func initDoesNotCrash() {
        let manager = makeManager()
        #expect(type(of: manager) == HotKeyManager.self)
    }

    @Test("stop before start is safe")
    func stopBeforeStartIsSafe() {
        let manager = makeManager()
        manager.stop() // must not crash
    }

    @Test("start without Accessibility permission does not crash")
    func startWithoutAccessibilityDoesNotCrash() {
        // In a test environment (xctest) there's typically NO Accessibility
        // permission. The implementation handles that case with an early
        // return + log, so it must not crash nor allocate the event tap.
        let manager = makeManager()
        manager.start()
        manager.stop()
    }

    @Test("different instances are distinct objects")
    func instancesAreDistinct() {
        let a = makeManager()
        let b = makeManager()
        #expect(a !== b)
    }

    @Test("multiple start/stop cycles do not leak or crash")
    func multipleStartStopCycles() {
        let manager = makeManager()
        for _ in 0..<3 {
            manager.start()
            manager.stop()
        }
    }

    // MARK: - shouldTrigger (pure function)

    @Test("⌘+Shift+S maps to .captureAlgorithm")
    func shiftCmdSMapsToCaptureAlgorithm() {
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 1, // 's'
            flags: [.maskCommand, .maskShift]
        )
        #expect(trigger == .captureAlgorithm)
    }

    @Test("⌘+Shift+A maps to .captureAndroid")
    func shiftCmdAMapsToCaptureAndroid() {
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 0, // 'a'
            flags: [.maskCommand, .maskShift]
        )
        #expect(trigger == .captureAndroid)
    }

    @Test("⌘+Shift+Enter maps to .send")
    func shiftCmdEnterMapsToSend() {
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 36, // Return
            flags: [.maskCommand, .maskShift]
        )
        #expect(trigger == .send)
    }

    @Test("⌘+S without Shift returns nil")
    func cmdSWithoutShiftReturnsNil() {
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 1,
            flags: [.maskCommand]
        )
        #expect(trigger == nil)
    }

    @Test("⌘+Shift+B (irrelevant key) returns nil")
    func irrelevantKeyReturnsNil() {
        // 'b' is keyCode 11. Flags are exactly the target combo, but the
        // key isn't one of the three mapped keys.
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 11,
            flags: [.maskCommand, .maskShift]
        )
        #expect(trigger == nil)
    }

    @Test("⌘+Shift+Alt+S returns nil (extra modifier disqualifies)")
    func extraModifierReturnsNil() {
        // Extra modifier (Alt) means the user is going for a different
        // shortcut — must not consume the event.
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 1,
            flags: [.maskCommand, .maskShift, .maskAlternate]
        )
        #expect(trigger == nil)
    }

    @Test("⌘+Shift+Ctrl+Enter returns nil (Control disqualifies)")
    func extraControlReturnsNil() {
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 36,
            flags: [.maskCommand, .maskShift, .maskControl]
        )
        #expect(trigger == nil)
    }

    @Test("only Shift (no Cmd) returns nil")
    func onlyShiftReturnsNil() {
        let trigger = HotKeyManager.shouldTrigger(
            keyCode: 1,
            flags: [.maskShift]
        )
        #expect(trigger == nil)
    }

    // MARK: - Helpers

    /// Keeps tests readable: builds the manager with empty closures, since
    /// none of the cases here actually exercise dispatch (the pure function
    /// `shouldTrigger` covers the mapping).
    private func makeManager() -> HotKeyManager {
        HotKeyManager(
            onCaptureAlgorithm: {},
            onCaptureAndroid:   {},
            onSend:             {}
        )
    }
}
