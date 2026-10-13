import AppKit
import Combine

/// Tracks the set of connected displays and keeps it current across
/// connect/disconnect/arrangement changes.
@MainActor
final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [Display] = []

    private var reconfigObserver: NSObjectProtocol?

    init() {
        refresh()
        reconfigObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let reconfigObserver {
            NotificationCenter.default.removeObserver(reconfigObserver)
        }
    }

    func refresh() {
        displays = NSScreen.screens.compactMap(Self.display(from:))
    }

    /// Finds the live `NSScreen` backing a `CGDirectDisplayID`, e.g. to size an
    /// overlay window.
    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screenNumber(of: $0) == displayID }
    }

    private static func display(from screen: NSScreen) -> Display? {
        let displayID = screenNumber(of: screen)
        guard displayID != 0 else { return nil }
        return Display(
            id: displayID,
            uuid: uuidString(for: displayID) ?? "\(displayID)",
            name: screen.localizedName,
            isBuiltIn: CGDisplayIsBuiltin(displayID) != 0
        )
    }

    private static func screenNumber(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return 0 }
        return CGDirectDisplayID(number.uint32Value)
    }

    /// A UUID that survives reboots/port changes, used to persist settings per display.
    private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let ref = CGDisplayCreateUUIDFromDisplayID(displayID) else { return nil }
        let cfUUID = ref.takeRetainedValue()
        return CFUUIDCreateString(nil, cfUUID) as String?
    }
}
