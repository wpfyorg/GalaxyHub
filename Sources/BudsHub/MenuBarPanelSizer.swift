import AppKit

/// The `MenuBarExtra` window only sizes its panel when the popover opens, so
/// collapsing the "More" section otherwise leaves the old height behind as
/// dead space. This keeps the panel height equal to the measured content
/// height, with the top edge pinned under the menu bar.
enum MenuBarPanelSizer {
    static let contentWidth: CGFloat = 300

    static func syncHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        // Let the current layout pass finish before touching the window.
        DispatchQueue.main.async {
            guard let panel = hostingPanel() else { return }
            let target = height.rounded(.up)
            let frame = panel.frame
            guard abs(frame.height - target) > 0.5 else { return }
            var resized = frame
            resized.origin.y = frame.maxY - target
            resized.size.height = target
            panel.setFrame(resized, display: true)
        }
    }

    /// The menu bar popover is a borderless `NSPanel` as wide as the SwiftUI
    /// content, anchored to the top of the screen. Titled windows (Settings,
    /// preview) and the bottom-of-screen HUD panel are never touched.
    private static func hostingPanel() -> NSPanel? {
        NSApp.windows.compactMap { $0 as? NSPanel }.first { panel in
            guard panel.isVisible,
                  panel.title.isEmpty,
                  !panel.styleMask.contains(.titled),
                  abs(panel.frame.width - contentWidth) < 2 else { return false }
            if let screen = panel.screen ?? NSScreen.main {
                // A tall popover can reach past the middle of the screen, but
                // its top edge always sits under the menu bar.
                return panel.frame.maxY > screen.frame.midY
            }
            return true
        }
    }
}
