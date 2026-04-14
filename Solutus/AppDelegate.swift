import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager?
    private var overlayWindowController: OverlayWindowController?

    // Fila de screenshots aguardando envio
    private var capturedScreenshots: [NSImage] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayWindowController = OverlayWindowController()

        hotKeyManager = HotKeyManager(
            onCapture: { [weak self] in self?.captureScreenshot() },
            onSend:    { [weak self] in self?.sendToAI() }
        )
        hotKeyManager?.start()

        print("Solutus iniciado.")
        print("  ⌘+Shift+S     → captura screenshot")
        print("  ⌘+Shift+Enter → envia para a IA")
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
