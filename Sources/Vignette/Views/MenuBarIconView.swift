import SwiftUI

/// Menu bar glyph: two overlapping displays, echoing the app icon. The back
/// display fades further while Movie Mode is active, miming the real
/// dimming effect at a glance; SwiftUI re-renders this independently
/// whenever `movieMode.isActive` changes, the same `@ObservedObject`
/// pattern `MenuBarContentView` uses.
struct MenuBarIconView: View {
    @ObservedObject var movieMode: MovieModeController

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                .frame(width: 11, height: 8)
                .foregroundStyle(.primary.opacity(movieMode.isActive ? 0.22 : 0.55))
                .offset(x: -3, y: -2.75)

            RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                .frame(width: 11, height: 8)
                .foregroundStyle(.primary)
                .offset(x: 3, y: 2.75)
        }
        .frame(width: 18, height: 16)
    }
}
