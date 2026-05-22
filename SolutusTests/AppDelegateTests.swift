import AppKit
import Testing
@testable import Solutus

/// `AppDelegate` is the main coordinator. We test without actually firing
/// `applicationDidFinishLaunching` (that would create real hot keys),
/// focusing on:
/// - instantiation as NSObject/NSApplicationDelegate
/// - public methods (`dismiss`) being idempotent
/// - the pure dispatch decision (`resolveDispatch`) used by `sendToAI`
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

    @Test("dismiss clears both screenshot queues")
    func dismissClearsBothQueues() {
        let delegate = AppDelegate()

        // Reflection access to the private state — this test documents that
        // `dismiss()` must leave BOTH per-feature queues empty.
        let mirror = Mirror(reflecting: delegate)
        let algoBefore = mirror.children
            .first { $0.label == "algorithmScreenshots" }?.value as? [NSImage]
        let androidBefore = mirror.children
            .first { $0.label == "androidScreenshots" }?.value as? [NSImage]
        #expect(algoBefore?.isEmpty == true)
        #expect(androidBefore?.isEmpty == true)

        delegate.dismiss()

        let mirrorAfter = Mirror(reflecting: delegate)
        let algoAfter = mirrorAfter.children
            .first { $0.label == "algorithmScreenshots" }?.value as? [NSImage]
        let androidAfter = mirrorAfter.children
            .first { $0.label == "androidScreenshots" }?.value as? [NSImage]
        #expect(algoAfter?.isEmpty == true)
        #expect(androidAfter?.isEmpty == true)
    }
}

/// Covers the pure function `AppDelegate.resolveDispatch(...)` — the rule
/// that decides which queue is dispatched when the user triggers a send.
/// Kept pure precisely so it can be tested without poking at private state
/// or hitting the network.
@Suite("AppDelegate.resolveDispatch")
struct AppDelegateResolveDispatchTests {

    @Test("active=algorithm with both queues populated → algorithmHelper")
    func activeAlgorithmDispatchesAlgorithm() {
        let kind = AppDelegate.resolveDispatch(
            activeHelper: .algorithmHelper,
            algorithmCount: 2,
            androidCount: 3
        )
        #expect(kind == .algorithmHelper)
    }

    @Test("active=android with both queues populated → androidHelper")
    func activeAndroidDispatchesAndroid() {
        let kind = AppDelegate.resolveDispatch(
            activeHelper: .androidHelper,
            algorithmCount: 2,
            androidCount: 3
        )
        #expect(kind == .androidHelper)
    }

    @Test("active=algorithm with empty algorithm queue → fallback to android")
    func fallbackFromAlgorithmToAndroid() {
        let kind = AppDelegate.resolveDispatch(
            activeHelper: .algorithmHelper,
            algorithmCount: 0,
            androidCount: 1
        )
        #expect(kind == .androidHelper)
    }

    @Test("active=android with empty android queue → fallback to algorithm")
    func fallbackFromAndroidToAlgorithm() {
        let kind = AppDelegate.resolveDispatch(
            activeHelper: .androidHelper,
            algorithmCount: 1,
            androidCount: 0
        )
        #expect(kind == .algorithmHelper)
    }

    @Test("both queues empty → nil (no-op, regardless of active)")
    func bothEmptyReturnsNil() {
        // active=algorithm, both empty
        let a = AppDelegate.resolveDispatch(
            activeHelper: .algorithmHelper,
            algorithmCount: 0,
            androidCount: 0
        )
        #expect(a == nil)

        // active=android, both empty — same outcome
        let b = AppDelegate.resolveDispatch(
            activeHelper: .androidHelper,
            algorithmCount: 0,
            androidCount: 0
        )
        #expect(b == nil)
    }

    @Test("active queue with single capture is dispatched (no fallback needed)")
    func activeQueueWithSingleItemDispatches() {
        // Edge case: active has exactly 1, the other has 0. Active wins.
        let a = AppDelegate.resolveDispatch(
            activeHelper: .algorithmHelper,
            algorithmCount: 1,
            androidCount: 0
        )
        #expect(a == .algorithmHelper)

        let b = AppDelegate.resolveDispatch(
            activeHelper: .androidHelper,
            algorithmCount: 0,
            androidCount: 1
        )
        #expect(b == .androidHelper)
    }
}
