import SwiftUI

/// Menu bar glyph: two overlapping displays, echoing the app icon. Backed
/// by template image assets (`MenuBarIconOff`/`MenuBarIconOn`) rather than
/// live SwiftUI shapes -- raw `Shape`/`Color` content doesn't reliably
/// render through `MenuBarExtra`'s custom-label snapshot path, while
/// `Image` always has. The back display's alpha is baked into the "on"
/// asset so it reads dimmer while Movie Mode is active.
struct MenuBarIconView: View {
    @ObservedObject var movieMode: MovieModeController

    var body: some View {
        Image(movieMode.isActive ? "MenuBarIconOn" : "MenuBarIconOff")
            .renderingMode(.template)
    }
}
