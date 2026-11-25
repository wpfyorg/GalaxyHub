import AppKit

/// The popover content reports its measured height here. The status item
/// controller owns the panel and resizes it with the top edge pinned under the
/// menu bar, so collapsing "More" does not leave dead space behind.
@MainActor
enum MenuBarPanelSizer {
    static let contentWidth: CGFloat = 300
    static var onHeightChange: ((CGFloat) -> Void)?

    static func syncHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        onHeightChange?(height)
    }
}
