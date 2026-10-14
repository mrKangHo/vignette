import SwiftUI

@main
struct VignetteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(appState: appState)
        } label: {
            MenuBarIconView(movieMode: appState.movieMode)
        }
        .menuBarExtraStyle(.window)
    }
}
