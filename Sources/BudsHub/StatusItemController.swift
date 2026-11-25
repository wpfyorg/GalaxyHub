import AppKit
import BudsKit
import Combine
import SwiftUI

/// Owns the menu bar item and the custom glass popover. Replacing
/// `MenuBarExtra` lets the panel become the key surface, so the glass renders
/// live, and gives the popover real chrome instead of the standard popover
/// material.
@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let controller: BudsController
    private let statusItem: NSStatusItem
    private let panel: PopoverPanel
    private let hostingView: NSHostingView<MenuView>
    private var cancellables: Set<AnyCancellable> = []
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var isShowing = false

    init(model: AppModel) {
        self.model = model
        self.controller = model.controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.panel = PopoverPanel(contentRect: .zero,
                                  styleMask: [.borderless],
                                  backing: .buffered,
                                  defer: true)
        self.hostingView = NSHostingView(rootView: MenuView(model: model))
        super.init()
        configureStatusItem()
        configurePanel()
        observe()
    }

    deinit {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: Presentation

    func show() {
        guard !isShowing else { return }
        let measured = hostingView.fittingSize.height
        let height = max(160, (measured.isFinite && measured > 0 ? measured : 400).rounded(.up))
        setPanelFrame(height: height)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        isShowing = true
        installEventMonitors()
    }

    func close() {
        guard isShowing else { return }
        panel.orderOut(nil)
        isShowing = false
        removeEventMonitors()
    }

    @objc private func togglePopover() {
        isShowing ? close() : show()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.imagePosition = .imageOnly
        updateIcon()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.frame = NSRect(x: 0, y: 0, width: MenuBarPanelSizer.contentWidth, height: 200)
        installGlass()
        MenuBarPanelSizer.onHeightChange = { [weak self] height in
            DispatchQueue.main.async { self?.resizePanel(to: height) }
        }
    }

    private func installGlass() {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 20
            glass.contentView = hostingView
            panel.contentView = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 20
            effect.layer?.masksToBounds = true
            hostingView.autoresizingMask = [.width, .height]
            effect.addSubview(hostingView)
            panel.contentView = effect
        }
        layoutContent()
    }

    private func layoutContent() {
        let size = panel.frame.size
        guard size.width > 0, size.height > 0 else { return }
        hostingView.frame = NSRect(origin: .zero, size: size)
    }

    private func setPanelFrame(height: CGFloat) {
        guard let button = statusItem.button, let window = button.window else { return }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let width = MenuBarPanelSizer.contentWidth
        let screen = window.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var x = buttonFrame.midX - width / 2
        if visible.width > 0 {
            x = min(max(x, visible.minX + 8), visible.maxX - width - 8)
        }
        var y = buttonFrame.minY - height - 5
        if visible.height > 0 {
            y = max(y, visible.minY + 8)
        }
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        layoutContent()
    }

    private func resizePanel(to height: CGFloat) {
        guard isShowing, height.isFinite, height > 0 else { return }
        let target = height.rounded(.up)
        let frame = panel.frame
        guard abs(frame.height - target) > 0.5 else { return }
        var resized = frame
        resized.origin.y = frame.maxY - target
        resized.size.height = target
        panel.setFrame(resized, display: true)
        layoutContent()
        panel.invalidateShadow()
    }

    // MARK: Dismissal

    private func installEventMonitors() {
        removeEventMonitors()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.handleOutsideClick() }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in self?.close() }
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func removeEventMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func handleOutsideClick() {
        guard isShowing else { return }
        let location = NSEvent.mouseLocation
        guard !panel.frame.contains(location),
              !statusButtonFrame().contains(location) else { return }
        close()
    }

    private func statusButtonFrame() -> NSRect {
        guard let button = statusItem.button, let window = button.window else { return .zero }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    // MARK: Menu bar icon

    private func observe() {
        controller.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateIcon() }
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        let connected = controller.link == .connected
        let level = connected && controller.menuBarBattery ? controller.batteryMin : nil
        let image = MenuBarIcon.image(level: level, connected: connected)
        guard let button = statusItem.button else { return }
        button.image = image
        button.toolTip = level.map { "Buds Hub — \($0)%" } ?? "Buds Hub"
        button.setAccessibilityLabel(image.accessibilityDescription ?? "Buds Hub")
    }
}

private final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
