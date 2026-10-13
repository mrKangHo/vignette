import CoreGraphics
import Foundation

/// Drives the brightness of the built-in panel via the private
/// `DisplayServices` framework — the same mechanism macOS's own Control
/// Center / keyboard brightness keys use. There is no public API for this;
/// `CGDisplayIOServicePort`-based `IODisplaySetFloatParameter` only reaches
/// external DDC-less panels on Intel Macs and does not work on Apple
/// Silicon, so this app intentionally uses the same private framework the
/// system itself relies on. Resolved via `dlopen`/`dlsym` so a future macOS
/// that removes these symbols degrades to "unsupported" instead of crashing.
final class BuiltInBrightnessController: BrightnessControlling {
    /// `int32_t DisplayServicesGetBrightness(CGDirectDisplayID, float *)` —
    /// takes an out-pointer and returns a status code, it does not return
    /// the brightness by value.
    private typealias GetterFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetterFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getter: GetterFn?
    private let setter: SetterFn?
    /// Whether a real call to `getter` has actually succeeded for this
    /// display — the symbols resolving via `dlsym` only proves the private
    /// framework loaded, not that this particular Mac's backlight responds.
    private var probedSupport: [CGDirectDisplayID: Bool] = [:]

    init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        ) else {
            getter = nil
            setter = nil
            return
        }

        if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            getter = unsafeBitCast(sym, to: GetterFn.self)
        } else {
            getter = nil
        }

        if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
            setter = unsafeBitCast(sym, to: SetterFn.self)
        } else {
            setter = nil
        }
    }

    func supportsBrightnessControl(for displayID: CGDirectDisplayID) -> Bool {
        guard CGDisplayIsBuiltin(displayID) != 0, getter != nil, setter != nil else { return false }
        if let cached = probedSupport[displayID] { return cached }
        let supported = rawBrightness(for: displayID) != nil
        probedSupport[displayID] = supported
        return supported
    }

    func brightness(for displayID: CGDirectDisplayID) -> Double? {
        guard supportsBrightnessControl(for: displayID) else { return nil }
        return rawBrightness(for: displayID)
    }

    private func rawBrightness(for displayID: CGDirectDisplayID) -> Double? {
        guard let getter else { return nil }
        var value: Float = 0
        let result = getter(displayID, &value)
        return result == 0 ? Double(value) : nil
    }

    @discardableResult
    func setBrightness(_ value: Double, for displayID: CGDirectDisplayID) -> Bool {
        guard supportsBrightnessControl(for: displayID), let setter else { return false }
        let clamped = Float(min(max(value, 0), 1))
        return setter(displayID, clamped) == 0
    }
}
