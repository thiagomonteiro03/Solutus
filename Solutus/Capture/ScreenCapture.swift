import AppKit
import ScreenCaptureKit

/// Captura um screenshot de todos os monitores usando ScreenCaptureKit (macOS 14+).
/// Na primeira chamada, o sistema exibe o diálogo de permissão de Gravação de Tela.
enum ScreenCapture {

    static func capture() async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            guard let display = content.displays.first else {
                print("ScreenCapture: nenhum display encontrado.")
                return nil
            }

            let filter = SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: []
            )

            let config = SCStreamConfiguration()
            config.width = display.width * 2   // Retina
            config.height = display.height * 2
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: display.width, height: display.height)
            )

        } catch {
            print("ScreenCapture erro: \(error.localizedDescription)")
            return nil
        }
    }
}
