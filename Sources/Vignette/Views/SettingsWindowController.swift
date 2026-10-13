import AppKit
import SwiftUI

/// Shows the settings UI in a plain `NSWindow` we manage ourselves.
///
/// SwiftUI's `Settings` scene + the `showSettingsWindow:` selector trick
/// (the usual pre-macOS-14 way to open it from a button) depends on the
/// app having a standard main menu, which `LSUIElement` menu-bar-only apps
/// like this one never get — so that selector has nowhere reliable to
/// route to and the button does nothing. Owning the window directly works
/// regardless of menu bar/Dock presence.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = String(localized: "설정")
        newWindow.contentView = NSHostingView(rootView: SettingsView(appState: appState))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
}
