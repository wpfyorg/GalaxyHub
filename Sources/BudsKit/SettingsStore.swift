import Foundation

public struct SavedDeviceSettings: Codable, Equatable {
    public var modelOverride: String?
    public var detectedModel: String?
    public var noiseMode: Int?
    public var ancLevelHigh: Bool?
    public var ambientVolume: Int?
    public var eqEnabled: Bool?
    public var eqPreset: Int?
    public var customEQBands: [Int]?
    public var touchpadLocked: Bool?
    public var touchSingle: Bool?
    public var touchDouble: Bool?
    public var touchTriple: Bool?
    public var touchHold: Bool?
    public var touchSwipe: Bool?
    public var touchDoubleDuringCall: Bool?
    public var touchHoldDuringCall: Bool?
    public var doubleTapVolume: Bool?
    public var detectConversations: Bool?
    public var adaptiveVolume: Bool?
    public var sirenDetect: Bool?
    public var autoPause: Bool?
    public var sidetone: Bool?
    public var extraHighAmbient: Bool?
    public var ambientCustomEnabled: Bool?
    public var ambientCustomLeft: Int?
    public var ambientCustomRight: Int?
    public var ambientTone: Int?
    public var seamlessConnection: Bool?
    public var ancWithOneEarbud: Bool?

    public init() {}
}

public final class SettingsStore {
    public static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastAddress = "lastAddress"
        static let autoReconnect = "autoReconnect"
        static let rememberSettings = "rememberSettings"
        static let launchAtLogin = "launchAtLogin"
        static let menuBarBattery = "menuBarBattery"
        static let autoClaimAudio = "autoClaimAudio"
        static let deviceStates = "deviceStates"
        static let seenIntro = "seenIntro"
        static let showPacketLog = "showPacketLog"
        static let hotkeyEnabled = "hotkeyEnabled"
    }

    public var lastAddress: String? {
        get { defaults.string(forKey: Keys.lastAddress) }
        set { defaults.set(newValue, forKey: Keys.lastAddress) }
    }

    public var autoReconnect: Bool {
        get { defaults.object(forKey: Keys.autoReconnect) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoReconnect) }
    }

    public var rememberSettings: Bool {
        get { defaults.object(forKey: Keys.rememberSettings) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.rememberSettings) }
    }

    public var launchAtLogin: Bool {
        get { defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    public var menuBarBattery: Bool {
        get { defaults.object(forKey: Keys.menuBarBattery) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.menuBarBattery) }
    }

    public var autoClaimAudio: Bool {
        get { defaults.object(forKey: Keys.autoClaimAudio) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.autoClaimAudio) }
    }

    public var hasSeenIntro: Bool {
        get { defaults.bool(forKey: Keys.seenIntro) }
        set { defaults.set(newValue, forKey: Keys.seenIntro) }
    }

    public var showPacketLog: Bool {
        get { defaults.bool(forKey: Keys.showPacketLog) }
        set { defaults.set(newValue, forKey: Keys.showPacketLog) }
    }

    public var hotkeyEnabled: Bool {
        get { defaults.object(forKey: Keys.hotkeyEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.hotkeyEnabled) }
    }

    private var allStates: [String: SavedDeviceSettings] {
        get {
            guard let data = defaults.data(forKey: Keys.deviceStates),
                  let decoded = try? JSONDecoder().decode([String: SavedDeviceSettings].self, from: data) else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.deviceStates)
            }
        }
    }

    public func state(for address: String) -> SavedDeviceSettings {
        allStates[normalize(address)] ?? SavedDeviceSettings()
    }

    public func update(for address: String, _ mutate: (inout SavedDeviceSettings) -> Void) {
        var states = allStates
        var state = states[normalize(address)] ?? SavedDeviceSettings()
        mutate(&state)
        states[normalize(address)] = state
        allStates = states
    }

    public func forget(address: String) {
        var states = allStates
        states.removeValue(forKey: normalize(address))
        allStates = states
        if normalize(lastAddress ?? "") == normalize(address) {
            lastAddress = nil
        }
    }

    private func normalize(_ address: String) -> String {
        address.lowercased().replacingOccurrences(of: ":", with: "-")
    }
}
