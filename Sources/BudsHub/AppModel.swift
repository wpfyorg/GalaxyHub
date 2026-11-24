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
        controller.start()
        reloadHotkeys()
        if CommandLine.arguments.contains("--demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.controller.connectDemo()
            }
        }
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
            HUD.shared.show(title: controller.findMyBudsActive ? "Finding earbuds" : "Stopped",
                            symbol: "dot.radiowaves.left.and.right",
                            subtitle: controller.findMyBudsActive ? "Playing a sound" : controller.deviceName,
                            battery: controller.batteryMin)
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

    private let key = "shortcuts.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Shortcut].self, from: data) {
            shortcuts = Dictionary(uniqueKeysWithValues: decoded.compactMap { name, shortcut in
                guard let action = ShortcutAction(rawValue: name) else { return nil }
                return (action, shortcut)
            })
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
