import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager?
    private var overlayWindowController: OverlayWindowController?
    private var hubWindowController: HubWindowController?
    private var statusItem: NSStatusItem?

    // Independent queues per feature — captures from one never bleed into the other.
    private var algorithmScreenshots: [NSImage] = []
    private var androidScreenshots:   [NSImage] = []

    /// The last feature the user captured into. `sendToAI()` dispatches this
    /// queue by default. The `.algorithmHelper` default is only a seed; it
    /// gets overwritten as soon as the user takes the first capture.
    private var activeHelper: HelperKind = .algorithmHelper

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayWindowController = OverlayWindowController()
        setupHub()
        setupStatusItem()

        hotKeyManager = HotKeyManager(
            onCaptureAlgorithm: { [weak self] in self?.captureForAlgorithm() },
            onCaptureAndroid:   { [weak self] in self?.captureForAndroid() },
            onSend:             { [weak self] in self?.sendToAI() }
        )
        hotKeyManager?.start()

        print("Solutus started.")
        print("  ⌘+Shift+S     → capture screenshot (Algorithm Helper)")
        print("  ⌘+Shift+A     → capture screenshot (Android Helper)")
        print("  ⌘+Shift+Enter → send the ACTIVE queue to the AI")
    }

    // MARK: - Hub

    /// Builds the hub by injecting each feature's action. Keeps `FeatureRegistry`
    /// pure (no AppKit) and concentrates here the knowledge of which side effect
    /// each button triggers.
    private func setupHub() {
        let features = FeatureRegistry.defaultFeatures(
            showAlgorithmHelperHint: { [weak self] in self?.showAlgorithmHelperHint() },
            showAndroidHelperHint:   { [weak self] in self?.showAndroidHelperHint() },
            showHRMeetingHelperHint: { [weak self] in self?.showHRMeetingHelperHint() }
        )
        hubWindowController = HubWindowController(features: features)
    }

    /// Creates the menu bar icon. It is the only visible entry point of the
    /// app, since `setActivationPolicy(.accessory)` hides the Dock icon.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "square.grid.2x2",
            accessibilityDescription: "Solutus Hub"
        )
        item.button?.target = self
        item.button?.action = #selector(toggleHubFromStatusItem)
        self.statusItem = item
    }

    @objc private func toggleHubFromStatusItem() {
        hubWindowController?.toggle()
    }

    /// Action triggered by the "Algorithm Helper" card in the hub. For now it
    /// only reminds the user of the hotkeys — the feature itself is still
    /// driven by the global shortcuts (⌘+Shift+S, ⌘+Shift+Enter).
    ///
    /// Dispatched async because calling `NSAlert.runModal()` directly from a
    /// SwiftUI Button action enters a modal runloop before the view update
    /// cycle finishes — the alert's buttons only render after the first click.
    /// Bouncing to the next tick + activating the app forces a full layout
    /// before the modal appears.
    private func showAlgorithmHelperHint() {
        presentHintAlert(
            title: "Algorithm Helper",
            body: """
            Atalhos:

              ⌘+Shift+S        captura screenshot
              ⌘+Shift+Enter    envia a fila para a IA

            A solução aparece no overlay flutuante (invisível em screen sharing).
            """
        )
    }

    /// Action triggered by the "Android Helper" card in the hub. Mirrors the
    /// Algorithm Helper hint but advertises this feature's own capture hotkey
    /// (⌘+Shift+A) and makes it explicit that `⌘+Shift+Enter` dispatches the
    /// last feature the user captured into.
    private func showAndroidHelperHint() {
        presentHintAlert(
            title: "Android Helper",
            body: """
            Atalhos:

              ⌘+Shift+A        captura screenshot
              ⌘+Shift+Enter    envia a fila para a IA

            ⌘+Shift+Enter despacha a fila da última feature em que você \
            capturou. Cada feature tem sua fila independente.

            A resposta vem em inglês e aparece no overlay flutuante \
            (invisível em screen sharing).
            """
        )
    }

    /// Action triggered by the "HR Meeting Helper" card in the hub. This is the
    /// scaffolding step: the feature is registered and discoverable, but audio
    /// capture, transcription and the Trello export land in later cards. For now
    /// the alert states what the feature will do and that it isn't wired yet.
    private func showHRMeetingHelperHint() {
        presentHintAlert(
            title: "HR Meeting Helper",
            body: """
            Em construção.

            Esta feature vai ouvir a call de entrevista de RH (sua voz + a voz \
            da recrutadora), transcrever em tempo real e, ao final, gerar um \
            resumo com os pontos da vaga e enviar um card para o Trello.

            Por enquanto só o botão existe — a captura de áudio chega no \
            próximo passo.
            """
        )
    }

    /// Shared helper across the hint alerts so the `DispatchQueue.main.async`
    /// dance and the OK-button configuration live in a single place.
    private func presentHintAlert(title: String, body: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.alertStyle = .informational

            // `keyEquivalent = ""` strips the "default button" status — that's
            // what tints the bezel with the system accent color (blue).
            // `focusRingType = .none` removes the animated focus outline.
            // Trade-off: pressing Return no longer triggers OK; click and Esc
            // still work.
            let okButton = alert.addButton(withTitle: "OK")
            okButton.keyEquivalent = ""
            okButton.focusRingType = .none

            alert.runModal()
        }
    }

    // MARK: - Capture

    private func captureForAlgorithm() {
        captureScreenshot(into: .algorithmHelper)
    }

    private func captureForAndroid() {
        captureScreenshot(into: .androidHelper)
    }

    /// Captures a screenshot and appends it to the queue for the given `kind`.
    /// Updates `activeHelper` so the next `⌘+Shift+Enter` dispatches this queue.
    private func captureScreenshot(into kind: HelperKind) {
        Task {
            guard let image = await ScreenCapture.capture() else {
                overlayWindowController?.show(content: .error("Não foi possível capturar a tela.\nVerifique as permissões em Preferências do Sistema → Privacidade → Gravação de Tela."))
                return
            }

            let count: Int
            switch kind {
            case .algorithmHelper:
                algorithmScreenshots.append(image)
                count = algorithmScreenshots.count
            case .androidHelper:
                androidScreenshots.append(image)
                count = androidScreenshots.count
            }
            activeHelper = kind

            overlayWindowController?.show(content: .captured(count: count))
            print("Screenshot \(count) captured for \(kind.displayName).")
        }
    }

    // MARK: - Send

    private func sendToAI() {
        guard let kind = Self.resolveDispatch(
            activeHelper: activeHelper,
            algorithmCount: algorithmScreenshots.count,
            androidCount: androidScreenshots.count
        ) else {
            // Both queues empty: spec mandates no-op (no overlay, no error).
            print("sendToAI: no queue has captures — no-op.")
            return
        }

        // Refresh the active helper in case dispatch resolved by fallback.
        activeHelper = kind

        let screenshots: [NSImage]
        switch kind {
        case .algorithmHelper:
            screenshots = algorithmScreenshots
            algorithmScreenshots = []
        case .androidHelper:
            screenshots = androidScreenshots
            androidScreenshots = []
        }

        Task {
            overlayWindowController?.show(content: .loading)
            do {
                let solution = try await LLMService.shared.solve(screenshots: screenshots, kind: kind)
                overlayWindowController?.show(content: .solution(text: solution, source: kind))
                print("Solution received (\(kind.displayName)).")
            } catch {
                overlayWindowController?.show(content: .error(error.localizedDescription))
            }
        }
    }

    // MARK: - Dispatch (pure, testable)

    /// Decides which queue to dispatch when the user triggers a send.
    ///
    /// Policy:
    /// 1. If the ACTIVE queue has captures, dispatch the active one.
    /// 2. Otherwise, fall back to the other queue (when it has captures).
    /// 3. If both are empty, return `nil` (no-op).
    ///
    /// Kept `static` and pure so it can be tested without instantiating
    /// AppDelegate or poking at private state via reflection.
    static func resolveDispatch(
        activeHelper: HelperKind,
        algorithmCount: Int,
        androidCount: Int
    ) -> HelperKind? {
        switch activeHelper {
        case .algorithmHelper where algorithmCount > 0: return .algorithmHelper
        case .androidHelper   where androidCount   > 0: return .androidHelper
        default: break
        }
        if algorithmCount > 0 { return .algorithmHelper }
        if androidCount   > 0 { return .androidHelper   }
        return nil
    }

    // MARK: - Dismiss (invoked by the overlay's X button)

    func dismiss() {
        algorithmScreenshots = []
        androidScreenshots   = []
        overlayWindowController?.hide()
    }
}
