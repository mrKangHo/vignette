import SwiftUI

@main
struct VignetteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Vignette", systemImage: "display.2") {
            MenuBarContentView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
