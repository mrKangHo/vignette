import Combine
import CoreGraphics
import Foundation

/// Root object wiring `DisplayManager`, `BrightnessCoordinator`,
/// `OverlayCoordinator` and `MovieModeController` together for the views.
@MainActor
final class AppState: ObservableObject {
    let displayManager: DisplayManager
    let movieMode: MovieModeController
    let settingsWindowController = SettingsWindowController()
    private let brightness: BrightnessCoordinator
    private let overlay: OverlayCoordinator

    @Published private(set) var displaySettings: [CGDirectDisplayID: DisplaySettings] = [:]

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let displayManager = DisplayManager()
        let brightness = BrightnessCoordinator()
        let overlay = OverlayCoordinator(displayManager: displayManager)
        self.displayManager = displayManager
        self.brightness = brightness
        self.overlay = overlay
        self.movieMode = MovieModeController(
            displayManager: displayManager,
            brightness: brightness,
            overlay: overlay,
            settingsProvider: { _ in .default }
        )

        displayManager.$displays
            .sink { [weak self] displays in
                self?.handleDisplaysChanged(displays)
            }
            .store(in: &cancellables)

        handleDisplaysChanged(displayManager.displays)

        movieMode.settingsProvider = { [weak self] displayID in
            guard let self, let display = self.displayManager.displays.first(where: { $0.id == displayID }) else {
                return .default
            }
            return self.settings(for: display)
        }

        overlay.baseDimProvider = { [weak self] displayID in
            guard let self, let display = self.displayManager.displays.first(where: { $0.id == displayID }) else {
                return 0
            }
            return self.baseDim(for: display)
        }

        overlay.refreshAll()
    }

    func settings(for display: Display) -> DisplaySettings {
        displaySettings[display.id] ?? brightness.settings(for: display)
    }

    func updateSettings(_ settings: DisplaySettings, for display: Display) {
        displaySettings[display.id] = settings
        brightness.saveSettings(settings, for: display)
        overlay.refreshAll()
    }

    func supportsHardwareBrightness(for display: Display) -> Bool {
        brightness.supportsHardwareBrightness(for: display)
    }

    /// Applies a brightness slider change to the real backlight immediately,
    /// outside of movie mode (movie mode manages hardware brightness itself
    /// while active, via `MovieModeController`).
    func applyHardwareBrightnessNow(_ value: Double, for display: Display) {
        guard !movieMode.isActive else { return }
        brightness.applyHardwareBrightness(value, for: display)
    }

    func toggleMovieMode(activeDisplay: Display) {
        if movieMode.isActive {
            movieMode.stop()
        } else {
            movieMode.start(activeDisplayID: activeDisplay.id)
        }
    }

    /// The software-overlay dim fraction a display needs *outside* of movie
    /// mode: 0 if its real backlight is being driven (hardware brightness is
    /// used automatically whenever a display supports it — no need to also
    /// paint a vignette over an already-dimmed screen), otherwise
    /// `1 - brightness` so the slider visibly does something on displays
    /// without hardware support.
    private func baseDim(for display: Display) -> Double {
        if brightness.supportsHardwareBrightness(for: display) {
            return 0
        }
        return 1 - settings(for: display).brightness
    }

    private func handleDisplaysChanged(_ displays: [Display]) {
        brightness.updateExternalDisplayIndices(displays)
        for display in displays where displaySettings[display.id] == nil {
            displaySettings[display.id] = brightness.settings(for: display)
        }
        movieMode.displaysDidChange()
        overlay.refreshAll()
    }
}
