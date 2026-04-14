import AppKit
import ApplicationServices

/// Gerencia dois atalhos globais:
/// - ⌘ + Shift + S     → captura um screenshot e adiciona à fila
/// - ⌘ + Shift + Enter → envia todos os screenshots capturados para a IA
final class HotKeyManager: Sendable {

    // ⌘ + Shift + S  (keycode 1 = 's')
    private nonisolated(unsafe) let captureKeyCode: CGKeyCode = 1
    // ⌘ + Shift + Enter  (keycode 36 = Return)
    private nonisolated(unsafe) let sendKeyCode: CGKeyCode = 36
    private nonisolated(unsafe) let targetFlags: CGEventFlags = [.maskCommand, .maskShift]

    private nonisolated(unsafe) var eventTap: CFMachPort?

    private let onCapture: @MainActor @Sendable () -> Void
    private let onSend: @MainActor @Sendable () -> Void

    init(
        onCapture: @escaping @MainActor @Sendable () -> Void,
        onSend: @escaping @MainActor @Sendable () -> Void
    ) {
        self.onCapture = onCapture
        self.onSend = onSend
    }

    // MARK: - Start / Stop

    func start() {
        requestAccessibilityIfNeeded()

        guard AXIsProcessTrusted() else {
            print("HotKeyManager: permissão de Acessibilidade não concedida ainda.")
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
            print("HotKeyManager: falha ao criar CGEventTap.")
            Unmanaged<HotKeyManager>.fromOpaque(selfPtr).release()
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("HotKeyManager: atalhos ⌘+Shift+S e ⌘+Shift+Enter ativos.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = nil
    }

    // MARK: - Evento

    nonisolated private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        guard flags == targetFlags else { return Unmanaged.passRetained(event) }

        if keyCode == captureKeyCode {
            let cb = onCapture
            Task { @MainActor in cb() }
            return nil
        }

        if keyCode == sendKeyCode {
            let cb = onSend
            Task { @MainActor in cb() }
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Permissão

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
