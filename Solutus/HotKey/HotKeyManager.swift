import AppKit
import ApplicationServices

/// Manages three global shortcuts:
/// - ⌘ + Shift + S      → capture a screenshot into the Algorithm Helper queue
/// - ⌘ + Shift + A      → capture a screenshot into the Android Helper queue
/// - ⌘ + Shift + Enter  → send the ACTIVE queue (the last feature captured)
final class HotKeyManager: Sendable {

    // ⌘ + Shift + S  (keycode 1 = 's')
    private nonisolated(unsafe) let captureAlgorithmKeyCode: CGKeyCode = 1
    // ⌘ + Shift + A  (keycode 0 = 'a')
    private nonisolated(unsafe) let captureAndroidKeyCode: CGKeyCode = 0
    // ⌘ + Shift + Enter  (keycode 36 = Return)
    private nonisolated(unsafe) let sendKeyCode: CGKeyCode = 36

    private nonisolated(unsafe) var eventTap: CFMachPort?

    private let onCaptureAlgorithm: @MainActor @Sendable () -> Void
    private let onCaptureAndroid:   @MainActor @Sendable () -> Void
    private let onSend:             @MainActor @Sendable () -> Void

    init(
        onCaptureAlgorithm: @escaping @MainActor @Sendable () -> Void,
        onCaptureAndroid:   @escaping @MainActor @Sendable () -> Void,
        onSend:             @escaping @MainActor @Sendable () -> Void
    ) {
        self.onCaptureAlgorithm = onCaptureAlgorithm
        self.onCaptureAndroid   = onCaptureAndroid
        self.onSend             = onSend
    }

    // MARK: - Trigger (pure, testable)

    /// Trigger derived from a (keyCode, flags) pair.
    ///
    /// Kept outside the dispatch method so unit tests can cover the mapping
    /// without spinning up a CGEventTap (which requires Accessibility permission).
    enum Trigger: Equatable {
        case captureAlgorithm
        case captureAndroid
        case send
    }

    /// Decides which `Trigger` corresponds to a (keyCode, flags) pair, or
    /// `nil` if the event should be ignored.
    ///
    /// Rules: flags must be exactly ⌘+Shift (no Alt/Ctrl), and the keyCode
    /// must be one of the three mapped keys. Any extra modifier (Alt or
    /// Control) disqualifies the event — this avoids stealing native
    /// shortcuts like ⌘+Shift+Alt+S.
    nonisolated static func shouldTrigger(
        keyCode: CGKeyCode,
        flags: CGEventFlags
    ) -> Trigger? {
        let target: CGEventFlags = [.maskCommand, .maskShift]
        let masked = flags.intersection(
            [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        )
        guard masked == target else { return nil }

        switch keyCode {
        case 1:  return .captureAlgorithm  // S
        case 0:  return .captureAndroid    // A
        case 36: return .send              // Return
        default: return nil
        }
    }

    // MARK: - Start / Stop

    func start() {
        requestAccessibilityIfNeeded()

        guard AXIsProcessTrusted() else {
            print("HotKeyManager: Accessibility permission has not been granted yet.")
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("HotKeyManager: failed to create CGEventTap.")
            Unmanaged<HotKeyManager>.fromOpaque(selfPtr).release()
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("HotKeyManager: shortcuts ⌘+Shift+S, ⌘+Shift+A and ⌘+Shift+Enter are active.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = nil
    }

    // MARK: - Event handling

    nonisolated private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        guard let trigger = Self.shouldTrigger(keyCode: keyCode, flags: flags) else {
            return Unmanaged.passRetained(event)
        }

        switch trigger {
        case .captureAlgorithm:
            let cb = onCaptureAlgorithm
            Task { @MainActor in cb() }
        case .captureAndroid:
            let cb = onCaptureAndroid
            Task { @MainActor in cb() }
        case .send:
            let cb = onSend
            Task { @MainActor in cb() }
        }
        return nil
    }

    // MARK: - Permission

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
