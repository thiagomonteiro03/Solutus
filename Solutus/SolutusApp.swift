import SwiftUI

@main
struct SolutusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // App roda sem janela — apenas o overlay invisível
        Settings {
            EmptyView()
        }
    }
}
