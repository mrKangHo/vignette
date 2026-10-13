import CoreGraphics
import Foundation

/// Drives external-display backlights over DDC/CI (VESA Monitor Control
/// Command Set), tunnelled through the private `IOAVService` I2C transport.
///
/// DDC/CI support varies by monitor, cable and any USB-C/dock hub in
/// between, and the underlying macOS symbols are undocumented — treat every
/// call as best-effort. This is why movie mode's dimming always has the
/// software overlay as a guaranteed fallback; hardware brightness is a
/// bonus layered on top when it works.
final class DDCBrightnessController: BrightnessControlling {
    /// VESA MCCS VCP feature code for "Luminance" (brightness).
    private static let brightnessVCPCode: UInt8 = 0x10
    /// 7-bit I2C address DDC/CI hosts use to talk to a display.
    private static let i2cChipAddress: UInt32 = 0x37

    private let bridge = IOAVServiceBridge.shared
    private var externalDisplayIndexByID: [CGDirectDisplayID: Int] = [:]
    /// Whether a real Get-VCP round trip has actually succeeded for this
    /// display. `IOAVServiceCreate`/`CreateWithService` happily hand back a
    /// non-nil handle even for a monitor that never answers DDC/CI (wrong
    /// service matched, cable/hub doesn't forward it, monitor doesn't
    /// support MCCS, …) — so "a service object exists" is not evidence this
    /// monitor's brightness is actually controllable. Only a successful
    /// probe is.
    private var probedSupport: [CGDirectDisplayID: Bool] = [:]

    func supportsBrightnessControl(for displayID: CGDirectDisplayID) -> Bool {
        guard bridge.isAvailable, CGDisplayIsBuiltin(displayID) == 0 else { return false }
        if let cached = probedSupport[displayID] { return cached }
        let supported = probe(displayID)
        probedSupport[displayID] = supported
        return supported
    }

    func brightness(for displayID: CGDirectDisplayID) -> Double? {
        guard supportsBrightnessControl(for: displayID), let service = service(for: displayID) else {
            return nil
        }
        guard let reply = sendGetVCPFeature(Self.brightnessVCPCode, to: service) else { return nil }
        let (current, maximum) = reply
        guard maximum > 0 else { return nil }
        return Double(current) / Double(maximum)
    }

    @discardableResult
    func setBrightness(_ value: Double, for displayID: CGDirectDisplayID) -> Bool {
        guard supportsBrightnessControl(for: displayID), let service = service(for: displayID) else {
            return false
        }
        let clamped = UInt16(min(max(value, 0), 1) * 100)
        return sendSetVCPFeature(Self.brightnessVCPCode, value: clamped, to: service)
    }

    /// Registers the enumeration index (order reported by `NSScreen.screens`
    /// among non-built-in displays) used to pick an `IOAVService` on Apple
    /// Silicon, where there is no public ID-to-service correlation. Clears
    /// the probe cache since a changed index can point at a different
    /// physical monitor.
    func registerExternalDisplayIndex(_ index: Int, for displayID: CGDirectDisplayID) {
        if externalDisplayIndexByID[displayID] != index {
            probedSupport.removeValue(forKey: displayID)
        }
        externalDisplayIndexByID[displayID] = index
    }

    private func probe(_ displayID: CGDirectDisplayID) -> Bool {
        guard let service = service(for: displayID) else { return false }
        return sendGetVCPFeature(Self.brightnessVCPCode, to: service) != nil
    }

    private func service(for displayID: CGDirectDisplayID) -> IOAVServiceBridge.IOAVServiceRef? {
        let index = externalDisplayIndexByID[displayID] ?? 0
        return bridge.service(forExternalDisplayIndex: index)
    }

    // MARK: - VESA DDC/CI packet construction

    private func sendSetVCPFeature(_ vcpCode: UInt8, value: UInt16, to service: IOAVServiceBridge.IOAVServiceRef) -> Bool {
        let highByte = UInt8(value >> 8)
        let lowByte = UInt8(value & 0xFF)
        let payload: [UInt8] = [0x03, vcpCode, highByte, lowByte]
        let packet = ddcPacket(command: payload)
        return bridge.write(service, chipAddress: Self.i2cChipAddress, data: packet)
    }

    private func sendGetVCPFeature(_ vcpCode: UInt8, to service: IOAVServiceBridge.IOAVServiceRef) -> (current: UInt16, maximum: UInt16)? {
        let request = ddcPacket(command: [0x01, vcpCode])
        guard bridge.write(service, chipAddress: Self.i2cChipAddress, data: request) else { return nil }

        // Real hardware needs a short settle time before the reply is ready.
        Thread.sleep(forTimeInterval: 0.045)

        guard let reply = bridge.read(service, chipAddress: Self.i2cChipAddress, length: 11),
              reply.count == 11, reply[1] == 2 else {
            return nil
        }
        let maximum = UInt16(reply[6]) << 8 | UInt16(reply[7])
        let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
        return (current, maximum)
    }

    /// Wraps a DDC/CI command in the VESA host-message envelope:
    /// `[source address, length|0x80, command bytes..., checksum]`, where the
    /// checksum is the running XOR seeded with the display's write address.
    private func ddcPacket(command: [UInt8]) -> [UInt8] {
        let sourceAddress: UInt8 = 0x51
        let lengthByte: UInt8 = UInt8(command.count) | 0x80
        var packet = [sourceAddress, lengthByte] + command

        let writeAddress: UInt8 = UInt8((Self.i2cChipAddress << 1) & 0xFF)
        var checksum = writeAddress
        for byte in packet { checksum ^= byte }
        packet.append(checksum)
        return packet
    }
}
