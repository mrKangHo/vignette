import CoreGraphics

/// A backend capable of reading/driving a real display's backlight.
///
/// macOS has no public, universal "set monitor brightness" API; every
/// implementation of this protocol talks to an undocumented/private
/// mechanism. See `BuiltInBrightnessController` and `DDCBrightnessController`.
protocol BrightnessControlling {
    func supportsBrightnessControl(for displayID: CGDirectDisplayID) -> Bool
    func brightness(for displayID: CGDirectDisplayID) -> Double?
    @discardableResult
    func setBrightness(_ value: Double, for displayID: CGDirectDisplayID) -> Bool
}
