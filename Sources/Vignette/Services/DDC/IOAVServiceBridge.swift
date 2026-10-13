import CoreGraphics
import Foundation
import IOKit

/// Thin `dlopen`/`dlsym` bridge to the undocumented `IOAVService` I2C
/// transport that macOS itself uses to send DDC/CI commands to external
/// displays (this is the same private mechanism community tools such as
/// MonitorControl/Lunar rely on — Apple has never published a DDC/CI API).
///
/// Because every symbol here is private, a future macOS release can remove
/// or change them without notice; every call site must treat failure as
/// "hardware brightness unavailable," never as a crash.
final class IOAVServiceBridge {
    typealias IOAVServiceRef = Unmanaged<AnyObject>

    // Every one of these takes a leading CFAllocator (unused, pass nil) and
    // passes the service as the raw `Unmanaged` reference itself — not
    // `.takeUnretainedValue()` — since at the C ABI boundary `Unmanaged<T>`
    // *is* the pointer; unwrapping it first silently passes the wrong
    // register and crashes identically to a missing/extra parameter would.
    private typealias CreateFn = @convention(c) (CFAllocator?) -> IOAVServiceRef?
    private typealias CreateWithServiceFn = @convention(c) (CFAllocator?, io_service_t) -> IOAVServiceRef?
    private typealias WriteI2CFn = @convention(c) (IOAVServiceRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
    private typealias ReadI2CFn = @convention(c) (IOAVServiceRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

    static let shared = IOAVServiceBridge()

    private let createFn: CreateFn?
    private let createWithServiceFn: CreateWithServiceFn?
    private let writeFn: WriteI2CFn?
    private let readFn: ReadI2CFn?

    private(set) var isAvailable: Bool

    private init() {
        guard let handle = dlopen(nil, RTLD_NOW) else {
            createFn = nil
            createWithServiceFn = nil
            writeFn = nil
            readFn = nil
            isAvailable = false
            return
        }

        func load<T>(_ name: String, as type: T.Type) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        createFn = load("IOAVServiceCreate", as: CreateFn.self)
        createWithServiceFn = load("IOAVServiceCreateWithService", as: CreateWithServiceFn.self)
        writeFn = load("IOAVServiceWriteI2C", as: WriteI2CFn.self)
        readFn = load("IOAVServiceReadI2C", as: ReadI2CFn.self)
        isAvailable = (createFn != nil || createWithServiceFn != nil) && writeFn != nil && readFn != nil
    }

    /// Best-effort match of a `CGDirectDisplayID` to an `IOAVService`.
    ///
    /// On Apple Silicon each external display is exposed as its own
    /// `DCPAVServiceProxy` IORegistry entry; there, services are matched to
    /// displays by enumeration order as a fallback since there is no public
    /// way to correlate an AVService with a `CGDirectDisplayID`/EDID without
    /// deeper (and equally undocumented) IORegistry graph walking. On Intel,
    /// `IOAVServiceCreate()` returns a single service shared by the I2C bus.
    func service(forExternalDisplayIndex index: Int) -> IOAVServiceRef? {
        if let createWithServiceFn {
            for candidate in matchingAVServices() {
                defer { IOObjectRelease(candidate.service) }
                if candidate.index == index {
                    return createWithServiceFn(nil, candidate.service)
                }
            }
        }
        return createFn?(nil)
    }

    private struct IndexedService {
        let index: Int
        let service: io_service_t
    }

    private func matchingAVServices() -> [IndexedService] {
        var result: [IndexedService] = []
        guard let matching = IOServiceMatching("DCPAVServiceProxy") else { return result }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return result
        }
        defer { IOObjectRelease(iterator) }

        var index = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            result.append(IndexedService(index: index, service: service))
            index += 1
            service = IOIteratorNext(iterator)
        }
        return result
    }

    @discardableResult
    func write(_ service: IOAVServiceRef, chipAddress: UInt32, data: [UInt8]) -> Bool {
        guard let writeFn else { return false }
        var buffer = data
        let result = buffer.withUnsafeMutableBytes { ptr -> IOReturn in
            guard let base = ptr.baseAddress else { return -1 }
            return writeFn(service, chipAddress, 0x51, base, UInt32(data.count))
        }
        return result == 0
    }

    func read(_ service: IOAVServiceRef, chipAddress: UInt32, length: Int) -> [UInt8]? {
        guard let readFn else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        let result = buffer.withUnsafeMutableBytes { ptr -> IOReturn in
            guard let base = ptr.baseAddress else { return -1 }
            return readFn(service, chipAddress, 0x51, base, UInt32(length))
        }
        return result == 0 ? buffer : nil
    }
}
