import CoreGraphics
import Foundation

/// A single connected display, resolved from `NSScreen`/`CGDirectDisplayID`.
struct Display: Identifiable, Equatable {
    let id: CGDirectDisplayID
    /// Stable identifier across reboots and port changes; used as the persistence key.
    let uuid: String
    var name: String
    let isBuiltIn: Bool

    static func == (lhs: Display, rhs: Display) -> Bool {
        lhs.id == rhs.id
    }
}
