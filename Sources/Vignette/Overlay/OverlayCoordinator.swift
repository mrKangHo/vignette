import AppKit

/// Owns the one `DimmingWindow` per display and decides how dark it should
/// be. Two independent things can ask for dimming:
///
/// - The per-display brightness slider, via `baseDimProvider` (0 when that
///   display's real backlight is already being driven in hardware, so the
///   overlay doesn't double-dim it; `1 - brightness` otherwise — this is
///   the fallback that makes the slider visibly do something on displays
///   without working hardware brightness control).
/// - Movie mode, which forces every non-active display to at least
///   `movieModeIntensity` on top of its own base dim.
@MainActor
final class OverlayCoordinator {
    /// Dim fraction (0...1) to apply before movie mode's own forcing,
    /// supplied by `AppState` since it alone knows both the slider value and
    /// whether hardware brightness is already covering this display.
    var baseDimProvider: (CGDirectDisplayID) -> Double = { _ in 0 }

    var movieModeActive = false
    var movieModeIntensity: Double = 0
    var movieModeActiveDisplayID: CGDirectDisplayID?

    private var windows: [CGDirectDisplayID: DimmingWindow] = [:]
    private unowned let displayManager: DisplayManager

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    /// Re-applies dimming to every connected display; call whenever any
    /// input changes (brightness/hardware-toggle settings, movie mode
    /// state, or the set of connected displays).
    func refreshAll() {
        let currentDisplays = displayManager.displays
        let currentIDs = Set(currentDisplays.map(\.id))

        for staleID in windows.keys where !currentIDs.contains(staleID) {
            windows[staleID]?.orderOut(nil)
            windows.removeValue(forKey: staleID)
        }

        for display in currentDisplays {
            apply(to: display.id)
        }
    }

    private func apply(to displayID: CGDirectDisplayID) {
        guard let screen = DisplayManager.screen(for: displayID) else { return }

        let base = baseDimProvider(displayID)
        let effective: Double
        if movieModeActive, displayID != movieModeActiveDisplayID {
            effective = max(base, movieModeIntensity)
        } else {
            effective = base
        }

        let window = windows[displayID] ?? {
            let created = DimmingWindow(screen: screen)
            windows[displayID] = created
            return created
        }()
        window.reposition(to: screen)
        window.setDimAmount(effective)

        if effective > 0.001 {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }
}
