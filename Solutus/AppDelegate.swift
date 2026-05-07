import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager?
    private var overlayWindowController: OverlayWindowController?
    private var hubWindowController: HubWindowController?
    private var statusItem: NSStatusItem?

    // Fila de screenshots aguardando envio
    private var capturedScreenshots: [NSImage] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayWindowController = OverlayWindowController()
        setupHub()
        setupStatusItem()

        hotKeyManager = HotKeyManager(
            onCapture: { [weak self] in self?.captureScreenshot() },
            onSend:    { [weak self] in self?.sendToAI() }
        )
        hotKeyManager?.start()

        print("Solutus iniciado.")
        print("  ⌘+Shift+S     → captura screenshot")
        print("  ⌘+Shift+Enter → envia para a IA")
    }

    // MARK: - Hub

    /// Builds the hub by injecting each feature's action. Keeps `FeatureRegistry`
    /// pure (no AppKit) and concentrates here the knowledge of which side effect
    /// each button triggers.
    private func setupHub() {
        let features = FeatureRegistry.defaultFeatures(
            showAlgorithmHelperHint: { [weak self] in self?.showAlgorithmHelperHint() }
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
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Algorithm Helper"
            alert.informativeText = """
            Atalhos:

              ⌘+Shift+S        captura screenshot
              ⌘+Shift+Enter    envia capturas para a IA

            A solução aparece no overlay flutuante (invisível em screen sharing).
            """
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

    // MARK: - Captura

    private func captureScreenshot() {
        Task {
            guard let image = await ScreenCapture.capture() else {
                overlayWindowController?.show(content: .error("Não foi possível capturar a tela.\nVerifique as permissões em Preferências do Sistema → Privacidade → Gravação de Tela."))
                return
            }

            capturedScreenshots.append(image)
            let count = capturedScreenshots.count
            overlayWindowController?.show(content: .captured(count: count))
            print("Screenshot \(count) capturado.")
        }
    }

    // MARK: - Envio

    private func sendToAI() {
        guard !capturedScreenshots.isEmpty else {
            overlayWindowController?.show(content: .error("Nenhum screenshot capturado.\nUse ⌘+Shift+S primeiro."))
            return
        }

        let screenshots = capturedScreenshots
        capturedScreenshots = [] // limpa a fila

        Task {
            overlayWindowController?.show(content: .loading)
            do {
                let solution = try await LLMService.shared.solve(screenshots: screenshots)
                overlayWindowController?.show(content: .solution(solution))
                print("Solução recebida.")
            } catch {
                overlayWindowController?.show(content: .error(error.localizedDescription))
            }
        }
    }

    // MARK: - Dismiss (chamado pelo botão X do overlay)

    func dismiss() {
        capturedScreenshots = []
        overlayWindowController?.hide()
    }
}
