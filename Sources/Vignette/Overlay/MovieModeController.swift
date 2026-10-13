import AppKit
import Combine

/// Owns movie mode: pick one display as the "screen playing the movie" and
/// dim every other connected display. Visual dimming itself (the
/// guaranteed-to-work software overlay) is delegated to `OverlayCoordinator`,
/// which also handles the ordinary per-display brightness slider — this
/// class only tracks movie-mode state and, additionally, lowers real
/// backlights for displays where `DisplaySettings.useHardwareBrightness` is
/// on and the hardware backend reports support.
@MainActor
final class MovieModeController: ObservableObject {
    @Published private(set) var isActive = false
    @Published var activeDisplayID: CGDirectDisplayID?
    /// 0...1 strength of the vignette/dim forced onto every non-active display.
    @Published var dimIntensity: Double = 0.85 {
        didSet {
            overlay.movieModeIntensity = dimIntensity
            overlay.refreshAll()
            if isActive { applyHardwareDimming() }
        }
    }

    private var restoreHardwareBrightness: [CGDirectDisplayID: Double] = [:]

    private let brightness: BrightnessCoordinator
    private let overlay: OverlayCoordinator
    private unowned let displayManager: DisplayManager
    /// Reassignable after `AppState.init` completes, since it needs to
    /// capture `self` there, which two-phase class init forbids earlier.
    var settingsProvider: (CGDirectDisplayID) -> DisplaySettings

    init(
        displayManager: DisplayManager,
        brightness: BrightnessCoordinator,
        overlay: OverlayCoordinator,
        settingsProvider: @escaping (CGDirectDisplayID) -> DisplaySettings
    ) {
        self.displayManager = displayManager
        self.brightness = brightness
        self.overlay = overlay
        self.settingsProvider = settingsProvider
    }

    func start(activeDisplayID: CGDirectDisplayID) {
        self.activeDisplayID = activeDisplayID
        isActive = true
        overlay.movieModeActive = true
        overlay.movieModeIntensity = dimIntensity
        overlay.movieModeActiveDisplayID = activeDisplayID
        overlay.refreshAll()
        applyHardwareDimming()
    }

    func stop() {
        isActive = false
        overlay.movieModeActive = false
        overlay.refreshAll()
        restoreHardwareNow()
    }

    func selectActiveDisplay(_ displayID: CGDirectDisplayID) {
        restoreHardwareNow()
        activeDisplayID = displayID
        overlay.movieModeActiveDisplayID = displayID
        overlay.refreshAll()
        applyHardwareDimming()
    }

    /// Call after `DisplayManager.refresh()` so overlays/hardware dimming
    /// follow connect/disconnect and arrangement changes while movie mode
    /// is on.
    func displaysDidChange() {
        overlay.refreshAll()
        if isActive { applyHardwareDimming() }
    }

    private func applyHardwareDimming() {
        guard isActive, let activeDisplayID else { return }
        for display in displayManager.displays where display.id != activeDisplayID {
            guard brightness.supportsHardwareBrightness(for: display) else { continue }
            let settings = settingsProvider(display.id)
            if restoreHardwareBrightness[display.id] == nil {
                restoreHardwareBrightness[display.id] = brightness.controller(for: display).brightness(for: display.id)
            }
            let target = settings.brightness * (1 - dimIntensity)
            brightness.applyHardwareBrightness(target, for: display)
        }
    }

    private func restoreHardwareNow() {
        for (displayID, value) in restoreHardwareBrightness {
            brightness.applyHardwareBrightness(value, for: displayFor(displayID))
        }
        restoreHardwareBrightness.removeAll()
    }

    private func displayFor(_ id: CGDirectDisplayID) -> Display {
        displayManager.displays.first { $0.id == id }
            ?? Display(id: id, uuid: "\(id)", name: "", isBuiltIn: false)
    }
}
