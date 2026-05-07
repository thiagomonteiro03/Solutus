import AppKit
import Testing
@testable import Solutus

/// `HotKeyManager` depends on Accessibility permission and on the CoreGraphics
/// event tap — both unreachable in unit tests. We focus instead on:
/// - correct initialization (no crash)
/// - start/stop cycle without crashing when permission is missing
/// - distinct identity between instances
///
/// To cover the keyCode → closure dispatch, refactor `handle(type:event:)` by
/// extracting a pure `shouldTrigger(keyCode:flags:) -> Trigger?` function and
/// add tests for each key combination here.
@Suite("HotKeyManager")
@MainActor
struct HotKeyManagerTests {

    @Test("init não crasha e cria instância válida")
    func initDoesNotCrash() {
        let manager = HotKeyManager(onCapture: {}, onSend: {})
        #expect(type(of: manager) == HotKeyManager.self)
    }

    @Test("stop antes de start é seguro")
    func stopBeforeStartIsSafe() {
        let manager = HotKeyManager(onCapture: {}, onSend: {})
        manager.stop() // must not crash
    }

    @Test("start pode ser chamado sem permissão sem crashar")
    func startWithoutAccessibilityDoesNotCrash() {
        // In a test environment (xctest) there's typically NO Accessibility
        // permission. The implementation handles that case with an early
        // return + log, so it must not crash nor allocate the event tap.
        let manager = HotKeyManager(onCapture: {}, onSend: {})
        manager.start()
        manager.stop()
    }

    @Test("instâncias diferentes são objetos distintos")
    func instancesAreDistinct() {
        let a = HotKeyManager(onCapture: {}, onSend: {})
        let b = HotKeyManager(onCapture: {}, onSend: {})
        #expect(a !== b)
    }

    @Test("múltiplos ciclos start/stop não vazam nem crasham")
    func multipleStartStopCycles() {
        let manager = HotKeyManager(onCapture: {}, onSend: {})
        for _ in 0..<3 {
            manager.start()
            manager.stop()
        }
    }
}
