import AppKit
import BudsKit
import Combine
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let controller = BudsController()
    let shortcuts = ShortcutStore()

    @Published var showHUD: Bool {
        didSet { UserDefaults.standard.set(showHUD, forKey: "showHUD") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            if !LaunchAtLogin.set(launchAtLogin) {
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }
    @Published private(set) var failedShortcuts: Set<ShortcutAction> = []

    private var started = false

    private init() {
        showHUD = UserDefaults.standard.object(forKey: "showHUD") as? Bool ?? true
        launchAtLogin = LaunchAtLogin.isEnabled
        if CommandLine.arguments.contains("--more") {
            UserDefaults.standard.set(true, forKey: "moreExpanded")
        }
    }

    func start() {
        guard !started else { return }
        started = true
        if CommandLine.arguments.contains("--demo") {
            // Demo mode is also the visual-check path: never touch real
            // Bluetooth or trigger the access prompt for a simulated device.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.controller.connectDemo()
            }
        } else {
            controller.start()
        }
        NowPlayingMonitor.shared.start(controller: controller)
        reloadHotkeys()
    }

    func reloadHotkeys() {
        HotKeyCenter.shared.unregisterAll()
        failedShortcuts.removeAll()
        guard UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true else { return }
        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts.shortcut(for: action) else { continue }
            let ok = HotKeyCenter.shared.register(id: UInt32(action.index), shortcut: shortcut) { [weak self] in
                self?.perform(action)
            }
            if !ok { failedShortcuts.insert(action) }
        }
    }

    func perform(_ action: ShortcutAction) {
        guard controller.link == .connected else { return }
        switch action {
        case .cycle:
            controller.cycleNoiseMode()
        case .anc:
            guard controller.availableNoiseModes.contains(.anc) else { return }
            controller.setNoiseMode(.anc)
        case .ambient:
            guard controller.availableNoiseModes.contains(.ambient) else { return }
            controller.setNoiseMode(.ambient)
        case .off:
            controller.setNoiseMode(.off)
        case .adaptive:
            guard controller.availableNoiseModes.contains(.adaptive) else { return }
            controller.setNoiseMode(.adaptive)
        case .find:
            guard controller.has(.findMyBuds), controller.link == .connected else { return }
            controller.setFindMyBuds(active: !controller.findMyBudsActive)
            if showHUD {
                HUD.shared.show(title: controller.findMyBudsActive ? "Finding earbuds" : "Stopped",
                                symbol: "dot.radiowaves.left.and.right",
                                subtitle: controller.findMyBudsActive ? "Playing a sound" : controller.deviceName,
                                battery: controller.batteryMin)
            }
            return
        case .takeAudio:
            guard controller.link == .connected else { return }
            let ok = controller.claimMacAudio()
            if showHUD {
                HUD.shared.show(title: ok ? "Audio on this Mac" : "Could not switch audio",
                                symbol: "hifispeaker.2",
                                subtitle: ok ? controller.deviceName : "Check the output device",
                                battery: controller.batteryMin, tinted: ok)
            }
            return
        }
        guard let mode = controller.noiseMode else { return }
        if showHUD {
            HUD.shared.show(mode: mode,
                            level: controller.has(.ancLevel) ? controller.ancLevelHigh : nil,
                            battery: controller.batteryMin,
                            deviceName: controller.deviceName)
        }
    }
}

extension ShortcutAction {
    var index: Int { ShortcutAction.allCases.firstIndex(of: self) ?? 0 }
}

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var shortcuts: [ShortcutAction: Shortcut] = [:]

    private let key = "shortcuts.v2"
    private let legacyKey = "shortcuts.v1"

    init() {
        let current = UserDefaults.standard.data(forKey: key)
        let legacy = current == nil ? UserDefaults.standard.data(forKey: legacyKey) : nil
        if let data = current ?? legacy,
           let decoded = try? JSONDecoder().decode([String: Shortcut].self, from: data) {
            var loaded: [ShortcutAction: Shortcut] = Dictionary(uniqueKeysWithValues: decoded.compactMap { name, shortcut in
                guard let action = ShortcutAction(rawValue: name) else { return nil }
                return (action, shortcut)
            })
            if current == nil, let newDefault = ShortcutAction.takeAudio.defaultShortcut,
               loaded[.takeAudio] == nil {
                loaded[.takeAudio] = newDefault
            }
            shortcuts = loaded
            persist()
        } else {
            var defaults: [ShortcutAction: Shortcut] = [:]
            for action in ShortcutAction.allCases {
                if let shortcut = action.defaultShortcut { defaults[action] = shortcut }
            }
            shortcuts = defaults
            persist()
        }
    }

    func shortcut(for action: ShortcutAction) -> Shortcut? { shortcuts[action] }

    func set(_ shortcut: Shortcut?, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        persist()
        AppModel.shared.reloadHotkeys()
    }

    private func persist() {
        let encoded = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("BudsHub: launch at login failed: \(error)")
            return false
        }
    }
}
