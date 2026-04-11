import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager?
    private var overlayWindowController: OverlayWindowController?
    private var isActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Roda como app acessório — sem ícone no Dock
        NSApp.setActivationPolicy(.accessory)

        overlayWindowController = OverlayWindowController()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.toggle()
        }
        hotKeyManager?.start()

        print("Solutus iniciado. Pressione ⌘+Shift+S para ativar.")
    }

    // MARK: - Toggle

    private func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    private func activate() {
        isActive = true
        Task {
            await captureAndSolve()
        }
    }

    private func deactivate() {
        isActive = false
        overlayWindowController?.hide()
        print("Solutus desativado.")
    }

    // MARK: - Fluxo principal

    private func captureAndSolve() async {
        overlayWindowController?.show(content: .loading)

        guard let image = await ScreenCapture.capture() else {
            overlayWindowController?.show(content: .error("Não foi possível capturar a tela.\nVerifique as permissões em Preferências do Sistema > Privacidade > Gravação de Tela."))
            return
        }

        do {
            let solution = try await LLMService.shared.solve(screenshot: image)
            overlayWindowController?.show(content: .solution(solution))
        } catch {
            overlayWindowController?.show(content: .error(error.localizedDescription))
        }
    }
}
