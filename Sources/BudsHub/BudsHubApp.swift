import AppKit
import SwiftUI
import BudsKit

@main
struct BudsHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            MenuBarLabel(controller: model.controller)
        }
        .menuBarExtraStyle(.window)

        Window("Buds Hub Settings", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 600, height: 620)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.start()
        if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.showPreview() }
        }
    }

    @MainActor
    private func showPreview() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 324, height: 820),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Buds Hub Preview"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: MenuView(model: AppModel.shared))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewWindow = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var controller: BudsController
    @AppStorage("menuBarBattery") private var showBattery = true

    var body: some View {
        Image(nsImage: MenuBarIcon.image(
            level: controller.link == .connected && showBattery ? controller.batteryMin : nil,
            connected: controller.link == .connected
        ))
    }
}
