import AppKit

@MainActor
enum SettingsWindow {
    /// Set by `StatusItemController` so opening Settings can dismiss the
    /// popover before the window takes focus.
    static weak var popover: StatusItemController?

    static func open() {
        popover?.close()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        DispatchQueue.main.async {
            for window in NSApp.windows where window.title.contains("Settings") {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
