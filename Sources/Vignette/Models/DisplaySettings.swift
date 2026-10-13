import Foundation

/// Per-display preferences, persisted in `UserDefaults` keyed by `Display.uuid`.
struct DisplaySettings: Codable, Equatable {
    /// 0...1 brightness last applied by the app (independent of movie-mode dimming).
    var brightness: Double = 1.0

    static let `default` = DisplaySettings()
}
