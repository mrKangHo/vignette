import AppKit
import CoreGraphics

/// A click-through, borderless window that sits above everything on one
/// screen and paints a dark radial gradient over it — the software half of
/// movie mode's dimming (always available, independent of DDC/CI support).
final class DimmingWindow: NSWindow {
    private let gradientLayer = CAGradientLayer()

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let contentView = NSView(frame: screen.frame)
        contentView.wantsLayer = true
        gradientLayer.frame = contentView.bounds
        gradientLayer.type = .radial
        gradientLayer.colors = [
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.withAlphaComponent(0.92).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        contentView.layer?.addSublayer(gradientLayer)
        self.contentView = contentView
    }

    /// 0 = fully transparent, 1 = fully opaque dark vignette.
    func setDimAmount(_ amount: Double) {
        alphaValue = CGFloat(min(max(amount, 0), 1))
    }

    func reposition(to screen: NSScreen) {
        setFrame(screen.frame, display: true)
        gradientLayer.frame = contentView?.bounds ?? screen.frame
    }
}
