import AppKit
import ApplicationServices

/// Registra um atalho global (⌘ + Shift + S) via CGEventTap.
/// Não precisa de Sandbox — funciona com permissão de Acessibilidade.
final class HotKeyManager: Sendable {

    // ⌘ + Shift + S  (keycode 1 = 's')
    private nonisolated(unsafe) let targetKeyCode: CGKeyCode = 1
    private nonisolated(unsafe) let targetFlags: CGEventFlags = [.maskCommand, .maskShift]

    private nonisolated(unsafe) var eventTap: CFMachPort?
    private let callback: @MainActor @Sendable () -> Void

    init(callback: @escaping @MainActor @Sendable () -> Void) {
        self.callback = callback
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
        print("HotKeyManager: atalho ⌘+Shift+S ativo.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = nil
        print("HotKeyManager: parado.")
    }

    // MARK: - Evento (chamado pelo C callback — precisa ser nonisolated)

    nonisolated private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        if keyCode == targetKeyCode && flags == targetFlags {
            let cb = callback
            Task { @MainActor in cb() }
            return nil // consome o evento
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Permissão de Acessibilidade

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
