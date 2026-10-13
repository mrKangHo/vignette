import CoreGraphics
import Foundation

/// Picks the right `BrightnessControlling` backend for a given display
/// (built-in panel vs. external DDC/CI) and persists each display's last
/// known brightness/preferences across launches.
final class BrightnessCoordinator {
    private let builtIn = BuiltInBrightnessController()
    private let ddc = DDCBrightnessController()
    private let defaults: UserDefaults
    private let storageKeyPrefix = "display-settings."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Tells the DDC backend which enumeration slot (among external
    /// displays only) each display occupies; call after every
    /// `DisplayManager.refresh()`. See `IOAVServiceBridge` for why this
    /// index-based matching is necessary on Apple Silicon.
    func updateExternalDisplayIndices(_ displays: [Display]) {
        var index = 0
        for display in displays where !display.isBuiltIn {
            ddc.registerExternalDisplayIndex(index, for: display.id)
            index += 1
        }
    }

    func controller(for display: Display) -> BrightnessControlling {
        display.isBuiltIn ? builtIn : ddc
    }

    func supportsHardwareBrightness(for display: Display) -> Bool {
        controller(for: display).supportsBrightnessControl(for: display.id)
    }

    @discardableResult
    func applyHardwareBrightness(_ value: Double, for display: Display) -> Bool {
        controller(for: display).setBrightness(value, for: display.id)
    }

    func settings(for display: Display) -> DisplaySettings {
        guard let data = defaults.data(forKey: storageKeyPrefix + display.uuid),
              let decoded = try? JSONDecoder().decode(DisplaySettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func saveSettings(_ settings: DisplaySettings, for display: Display) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKeyPrefix + display.uuid)
    }
}
