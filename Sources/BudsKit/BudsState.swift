import Foundation

public struct BatteryLevel: Equatable, Sendable {
    public var level: Int
    public var charging: Bool
    public init(level: Int, charging: Bool = false) {
        self.level = level
        self.charging = charging
    }
}

public enum NoiseMode: Int, CaseIterable, Identifiable, Codable, Sendable {
    case off = 0
    case anc = 1
    case ambient = 2
    case adaptive = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .off: return "Off"
        case .anc: return "Noise cancellation"
        case .ambient: return "Ambient"
        case .adaptive: return "Adaptive"
        }
    }

    public var shortTitle: String {
        switch self {
        case .off: return "Off"
        case .anc: return "ANC"
        case .ambient: return "Ambient"
        case .adaptive: return "Adaptive"
        }
    }
}

public enum Placement: Int, Codable, Sendable {
    case disconnected = 0
    case wearing = 1
    case idle = 2
    case inCase = 3
    case closedCase = 4
    case charging = 100
}

public enum WearState: Int, Codable, Sendable {
    case none = 0
    case right = 1
    case left = 16
    case both = 17
}

public struct TouchpadState: Equatable, Sendable {
    public var locked: Bool?
    public var singleTap: Bool?
    public var doubleTap: Bool?
    public var tripleTap: Bool?
    public var hold: Bool?
    public var doubleTapDuringCall: Bool?
    public var holdDuringCall: Bool?
    public var swipe: Bool?
    public var doubleTapVolume: Bool?
    public var leftActionRaw: UInt8?
    public var rightActionRaw: UInt8?
    /// Per-side cycle masks reported by the firmware (Buds3+).
    public var cycleBitsLeft: UInt8?
    public var cycleBitsRight: UInt8?
    public init() {}
}

public struct MultipointState: Equatable, Sendable {
    public var revision: Int = 0
    public var supported: Bool = false
    public var haveDevices: Bool = false
    public var audioFocusForeground: Bool = false
    public var streamingMask: UInt8 = 0
}

/// A decoded device state update. Every field is optional because the layout
/// differs per model generation and firmware revision.
public struct BudsState: Equatable, Sendable {
    public var revision: Int = 0
    public var earType: Int = 0
    public var batteryLeft: Int?
    public var batteryRight: Int?
    public var caseBattery: Int?
    public var isCoupled: Bool = false
    public var mainConnection: Int = 0
    public var placementLeft: Placement = .disconnected
    public var placementRight: Placement = .disconnected
    public var wearState: WearState = .none
    public var leftCharging: Bool?
    public var rightCharging: Bool?
    public var caseCharging: Bool?

    public var noiseMode: NoiseMode?
    public var ambientEnabled: Bool?
    public var noiseCancelling: Bool?
    public var ambientVolume: Int?
    public var ancLevel: Int?
    public var ambientCustomEnabled: Bool?
    public var ambientCustomLeft: Int?
    public var ambientCustomRight: Int?
    public var ambientTone: Int?
    public var extraHighAmbient: Bool?
    public var sidetone: Bool?
    public var detectConversations: Bool?
    public var detectConversationsDuration: Int?
    public var ancWithOneEarbud: Bool?
    public var adaptiveVolume: Bool?
    public var sirenDetect: Bool?
    public var autoPause: Bool?
    public var speakSeamlessly: Bool?
    public var extraClearCall: Bool?
    public var autoAdjustSound: Bool?
    public var autoSwitchAudioOutput: Bool?

    public var equalizerMode: Int?
    public var equalizerEnabled: Bool?
    public var equalizerPreset: Int?
    public var adaptiveEQ: Bool?

    public var touchpad = TouchpadState()

    public var voiceWakeUp: Bool?
    public var voiceWakeUpLanguage: Int?
    public var seamlessConnection: Bool?
    public var callPathControl: Bool?
    public var spatialAudio: Bool?
    public var headTracking: Bool?
    public var hearingEnhancements: UInt8?
    public var gameMode: Bool?
    public var hotCommandEnabled: Bool?
    public var hotCommandLanguage: Int?
    public var hotCommandVersion: String?
    public var peqMod: Int?
    public var lighting: Int?
    public var quickLaunch: Int?
    public var adaptSound: Bool?
    public var fmmRevision: Int?
    public var deviceColorLeft: Int?
    public var deviceColorRight: Int?
    public var rawPayload: [UInt8] = []
    public init() {}
}

public enum StatusParser {
    public static func parse(frame: SPPFrame, model: DeviceModel) -> BudsState? {
        if frame.id == MsgID.statusUpdated {
            return parseStatus(frame.payload, model: model)
        }
        if frame.id == MsgID.extendedStatusUpdated {
            return parseExtended(frame.payload, model: model)
        }
        return nil
    }

    public static func parseStatus(_ p: [UInt8], model: DeviceModel) -> BudsState? {
        var s = BudsState()
        s.rawPayload = p
        guard p.count >= 6 else { return nil }
        if model.id == .buds {
            s.earType = Int(p[0])
            s.batteryLeft = Int(p[1])
            s.batteryRight = Int(p[2])
            s.isCoupled = p[3] != 0
            s.mainConnection = Int(p[4])
            s.wearState = WearState(rawValue: Int(p[5])) ?? .none
            applyWear(&s)
            return s
        }
        guard p.count >= 7 else { return nil }
        s.revision = Int(p[0])
        s.batteryLeft = Int(p[1])
        s.batteryRight = Int(p[2])
        s.isCoupled = p[3] != 0
        s.mainConnection = Int(p[4])
        s.placementLeft = Placement(rawValue: Int((p[5] & 0xF0) >> 4)) ?? .disconnected
        s.placementRight = Placement(rawValue: Int(p[5] & 0x0F)) ?? .disconnected
        s.caseBattery = Int(p[6])
        if p.count >= 8, model.supports(.chargingState) {
            let bits = p[7]
            s.leftCharging = (bits & 0x10) != 0
            s.rightCharging = (bits & 0x04) != 0
            s.caseCharging = (bits & 0x01) != 0
        }
        deriveWear(&s)
        return s
    }

    public static func parseExtended(_ p: [UInt8], model: DeviceModel) -> BudsState? {
        guard p.count >= 8 else { return nil }
        var s = BudsState()
        s.rawPayload = p
        s.revision = Int(p[0])
        s.earType = Int(p[1])
        s.batteryLeft = Int(p[2])
        s.batteryRight = Int(p[3])
        s.isCoupled = p[4] != 0
        s.mainConnection = Int(p[5])

        if model.id == .buds {
            guard p.count >= 12 else { return s }
            s.wearState = WearState(rawValue: Int(p[6])) ?? .none
            applyWear(&s)
            s.ambientEnabled = p[7] != 0
            s.ambientVolume = Int(p[9])
            s.equalizerEnabled = p[10] != 0
            s.equalizerPreset = Int(p[11])
            s.equalizerMode = s.equalizerEnabled == true ? (s.equalizerPreset ?? 0) + 1 : 0
            if p.count > 13 {
                s.touchpad.locked = p[12] != 0
                s.touchpad.leftActionRaw = (p[13] & 0xF0) >> 4
                s.touchpad.rightActionRaw = p[13] & 0x0F
                if s.revision >= 3, p.count > 14 { s.seamlessConnection = p[14] == 0 }
            } else if p.count > 12 {
                s.touchpad.locked = (p[12] & 0xF0) != 0
                s.touchpad.leftActionRaw = p[12] & 0x0F
                s.touchpad.rightActionRaw = p[12] & 0x0F
                if s.revision >= 3, p.count > 13 { s.seamlessConnection = p[13] == 0 }
            }
            return s
        }

        guard p.count >= 8 else { return s }
        s.placementLeft = Placement(rawValue: Int((p[6] & 0xF0) >> 4)) ?? .disconnected
        s.placementRight = Placement(rawValue: Int(p[6] & 0x0F)) ?? .disconnected
        s.caseBattery = Int(p[7])
        deriveWear(&s)

        switch model.id {
        case .budsPlus:
            parseBudsPlus(p, &s)
        case .budsLive:
            parseBudsLive(p, &s)
        case .budsPro:
            parseBudsPro(p, &s)
        case .buds2:
            parseBuds2(p, &s)
        case .buds2Pro:
            parseBuds2Pro(p, &s)
        case .budsFe, .budsCore, .buds3Fe:
            parseFeFamily(p, &s, isBuds3Fe: model.id == .buds3Fe)
        case .buds3:
            parseBuds3(p, &s)
        case .buds3Pro:
            parseBuds3Pro(p, &s)
        case .buds4, .buds4Pro:
            parseBuds4(p, &s)
        default:
            break
        }
        return s
    }

    private static func parseBudsPlus(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 15 else { return }
        s.ambientEnabled = p[8] != 0
        s.ambientVolume = Int(p[9])
        s.autoAdjustSound = p[10] == 1 // adjust sound sync
        s.equalizerMode = Int(p[11])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        s.touchpad.locked = p[12] != 0
        s.touchpad.leftActionRaw = (p[13] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[13] & 0x0F
        s.touchpad.doubleTapVolume = p[14] == 1
        if p.count >= 19 {
            s.deviceColorLeft = Int(p[15]) | (Int(p[16]) << 8)
            s.deviceColorRight = Int(p[17]) | (Int(p[18]) << 8)
        }
        if s.revision >= 8, p.count > 19 { s.sidetone = p[19] == 1 }
        if s.revision >= 9, p.count > 20 { s.extraHighAmbient = p[20] == 1 }
        if s.revision >= 11, p.count > 21 { s.seamlessConnection = p[21] == 0 }
        if s.revision >= 12, p.count > 22 { s.fmmRevision = Int(p[22]) }
        if s.revision >= 13, p.count > 23 { s.callPathControl = p[23] == 0 }
    }

    private static func parseBudsLive(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 21 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        s.touchpad.locked = p[10] == 1
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseCancelling = p[12] == 1
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        if s.revision >= 5, p.count > 21 { s.ambientEnabled = p[21] == 1 }
        if s.revision >= 7, p.count > 22 { s.hearingEnhancements = p[22] }
        if s.revision >= 8, p.count > 23 { s.callPathControl = p[23] == 0 }
        if s.revision >= 9, p.count > 24 { s.spatialAudio = p[24] == 1 }
    }

    private static func parseBudsPro(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 25 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        s.touchpad.locked = p[10] == 1
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        let bits = p[21]
        s.touchpad.cycleBitsLeft = bits
        s.touchpad.cycleBitsRight = bits
        s.touchpad.singleTap = true
        s.touchpad.doubleTap = true
        s.touchpad.tripleTap = true
        s.touchpad.hold = true
        if s.revision < 3 { s.extraHighAmbient = p[22] == 1 } else { s.speakSeamlessly = p[22] == 1 }
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        if p.count >= 26 { s.autoSwitchAudioOutput = p[25] == 1 }
        if p.count >= 27 { s.detectConversations = p[26] == 1 }
        if p.count >= 28 { s.detectConversationsDuration = min(Int(p[27]), 2) }
        if s.revision > 1, p.count >= 29 { s.spatialAudio = p[28] == 1 }
        if s.revision >= 5, p.count >= 30 { s.hearingEnhancements = p[29] }
        if s.revision >= 6, p.count >= 31 { s.extraHighAmbient = p[30] == 1 }
        if s.revision >= 7, p.count >= 32 { s.touchpad.doubleTapVolume = p[31] == 1 }
        if s.revision >= 8, p.count >= 36 {
            s.ancWithOneEarbud = p[32] == 1
            s.ambientCustomEnabled = p[33] == 1
            s.ambientCustomLeft = Int((p[34] & 0xF0) >> 4)
            s.ambientCustomRight = Int(p[34] & 0x0F)
            s.ambientTone = Int(p[35])
        }
        if s.revision >= 9, p.count >= 37 { s.sidetone = p[36] == 1 }
        if s.revision >= 10, p.count >= 38 { s.callPathControl = p[37] == 0 }
    }

    private static func parseBuds2(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 27 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        parseAdvancedTouch(p[10], &s)
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        let bits = p[21]
        s.touchpad.cycleBitsLeft = bits
        s.touchpad.cycleBitsRight = bits
        s.speakSeamlessly = p[22] == 1
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        s.hearingEnhancements = p[25]
        s.extraHighAmbient = p[26] == 1
        if s.revision >= 2, p.count >= 28 { s.touchpad.doubleTapVolume = p[27] == 1 }
        if s.revision >= 3, p.count >= 29 { s.ancWithOneEarbud = p[28] == 1 }
        if s.revision >= 5, p.count >= 33 {
            s.ambientCustomEnabled = p[29] == 1
            s.ambientCustomLeft = Int((p[30] & 0xF0) >> 4)
            s.ambientCustomRight = Int(p[30] & 0x0F)
            s.ambientTone = Int(p[31])
            s.touchpad.doubleTapVolume = p[32] == 1
        }
        if s.revision >= 6, p.count >= 34 { s.sidetone = p[33] == 1 }
        if s.revision >= 7, p.count >= 35 { s.callPathControl = p[34] == 0 }
        if s.revision >= 8, p.count >= 36 { s.spatialAudio = p[35] == 1 }
        if s.revision >= 10, p.count >= 37 {
            s.leftCharging = (p[36] & 0x10) != 0
            s.rightCharging = (p[36] & 0x04) != 0
            s.caseCharging = (p[36] & 0x01) != 0
        }
    }

    private static func parseBuds2Pro(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 34 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        parseAdvancedTouch(p[10], &s, forCalls: true)
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        s.touchpad.cycleBitsLeft = p[21]
        s.touchpad.cycleBitsRight = p[21]
        s.speakSeamlessly = p[22] == 1
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        s.hearingEnhancements = p[25]
        s.detectConversations = p[26] == 1
        s.detectConversationsDuration = min(Int(p[27]), 2)
        s.ancWithOneEarbud = p[28] == 1
        s.ambientCustomEnabled = p[29] == 1
        s.ambientCustomLeft = Int((p[30] & 0xF0) >> 4)
        s.ambientCustomRight = Int(p[30] & 0x0F)
        s.ambientTone = Int(p[31])
        s.touchpad.doubleTapVolume = p[32] == 1
        s.sidetone = p[33] == 1
        var i = 34
        func byte() -> UInt8? { guard i < p.count else { return nil }; defer { i += 1 }; return p[i] }
        if s.revision >= 1 {
            if let v = byte() { s.callPathControl = v == 0 }
            if let v = byte() { s.spatialAudio = v != 0 }
            _ = byte() // customize conversation boost
            _ = byte() // customize noise reduction level
            _ = byte() // neck stretch calibration
            _ = byte() // bixby keyword
            if let v = byte() { s.hearingEnhancements = v } // hearing test value / amplify
        }
        if s.revision >= 3 { s.autoAdjustSound = (byte() ?? 0) != 0 }
        if s.revision >= 8 { if let v = byte() { s.headTracking = v != 0 } }
        if s.revision >= 11, let v = byte() {
            s.leftCharging = (v & 0x10) != 0
            s.rightCharging = (v & 0x04) != 0
            s.caseCharging = (v & 0x01) != 0
        }
        if s.revision >= 13 {
            if let v = byte() { s.extraClearCall = v != 0 }
            if i < p.count, let v = byte() { s.extraHighAmbient = v != 0 }
        }
    }

    private static func parseFeFamily(_ p: [UInt8], _ s: inout BudsState, isBuds3Fe: Bool) {
        guard p.count >= 34 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        parseAdvancedTouch(p[10], &s, forCalls: true)
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        s.touchpad.cycleBitsLeft = p[21]
        s.touchpad.cycleBitsRight = p[21]
        s.speakSeamlessly = p[22] == 1
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        s.hearingEnhancements = p[25]
        s.detectConversations = p[26] == 1
        s.detectConversationsDuration = min(Int(p[27]), 2)
        s.ancWithOneEarbud = p[28] == 1
        s.ambientCustomEnabled = p[29] == 1
        s.ambientCustomLeft = Int((p[30] & 0xF0) >> 4)
        s.ambientCustomRight = Int(p[30] & 0x0F)
        s.ambientTone = Int(p[31])
        s.touchpad.doubleTapVolume = p[32] == 1
        s.sidetone = p[33] == 1
        var i = 34
        func byte() -> UInt8? { guard i < p.count else { return nil }; defer { i += 1 }; return p[i] }
        if let v = byte() { s.callPathControl = v == 0 }
        if let v = byte() { s.spatialAudio = v != 0 }
        _ = byte(); _ = byte(); _ = byte(); _ = byte()
        if let v = byte() { s.hearingEnhancements = v }
        if isBuds3Fe { return }
        _ = byte()
        if let v = byte() { s.headTracking = v != 0 }
        if let v = byte() {
            s.leftCharging = (v & 0x10) != 0
            s.rightCharging = (v & 0x04) != 0
            s.caseCharging = (v & 0x01) != 0
        }
    }

    private static func parseBuds3(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 25 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        parseAdvancedTouch(p[10], &s, forCalls: true, swipe: true)
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        parseAdaptiveTouchBits(p[21], &s)
        s.speakSeamlessly = p[22] == 1
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        if p.count >= 26 { s.hearingEnhancements = p[25] }
        if p.count >= 27 { s.detectConversations = p[26] == 1 }
        if p.count >= 28 { s.detectConversationsDuration = min(Int(p[27]), 2) }
        if p.count >= 29 { s.ancWithOneEarbud = p[28] == 1 }
        if p.count >= 34 {
            s.ambientCustomEnabled = p[29] == 1
            s.ambientCustomLeft = Int((p[30] & 0xF0) >> 4)
            s.ambientCustomRight = Int(p[30] & 0x0F)
            s.ambientTone = Int(p[31])
            s.touchpad.doubleTapVolume = p[32] == 1
            s.sidetone = p[33] == 1
        }
        var i = 34
        func byte() -> UInt8? { guard i < p.count else { return nil }; defer { i += 1 }; return p[i] }
        // Common 7-byte FE-family block.
        if let v = byte() { s.callPathControl = v == 0 }      // 34
        if let v = byte() { s.spatialAudio = v != 0 }          // 35
        _ = byte(); _ = byte(); _ = byte(); _ = byte()         // 36-39
        if let v = byte() { s.hearingEnhancements = v }        // 40
        // Buds3 tail starts at 41.
        if let v = byte() { s.headTracking = v != 0 }          // 41
        if let v = byte() {                                   // 42
            s.leftCharging = (v & 0x10) != 0
            s.rightCharging = (v & 0x04) != 0
            s.caseCharging = (v & 0x01) != 0
        }
        if let v = byte() { s.extraClearCall = v != 0 }        // 43
        if let v = byte() { s.extraHighAmbient = v != 0 }      // 44
        if let v = byte() { s.autoPause = v != 0 }             // 45
        if let v = byte() { s.hotCommandEnabled = v != 0 }     // 46
        if let v = byte() { s.hotCommandLanguage = Int(v) }    // 47
        if let v = byte() { s.peqMod = Int(v) }                // 48
        if let v = byte() { s.adaptiveVolume = v != 0 }        // 49
        if let v = byte() { s.adaptSound = v != 0 }            // 50?
        if p.count >= 54 {
            s.hotCommandVersion = "\(p.count > 51 ? p[51] : 0).\(p.count > 52 ? p[52] : 0).\(p.count > 53 ? p[53] : 0)"
        }
    }

    private static func parseBuds3Pro(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 25 else { return }
        s.autoAdjustSound = p[8] == 1
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        parseAdvancedTouch(p[10], &s, forCalls: true, swipe: true)
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        parseAdaptiveTouchBits(p[21], &s)
        s.speakSeamlessly = p[22] == 1
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        if p.count >= 26 { s.hearingEnhancements = p[25] }
        if p.count >= 27 { s.detectConversations = p[26] == 1 }
        if p.count >= 28 { s.detectConversationsDuration = min(Int(p[27]), 2) }
        if p.count >= 29 { s.ancWithOneEarbud = p[28] == 1 }
        if p.count >= 34 {
            s.ambientCustomEnabled = p[29] == 1
            s.ambientCustomLeft = Int((p[30] & 0xF0) >> 4)
            s.ambientCustomRight = Int(p[30] & 0x0F)
            s.ambientTone = Int(p[31])
            s.touchpad.doubleTapVolume = p[32] == 1
            s.sidetone = p[33] == 1
        }
        var i = 34
        func byte() -> UInt8? { guard i < p.count else { return nil }; defer { i += 1 }; return p[i] }
        if let v = byte() { s.callPathControl = v == 0 }       // 34
        if let v = byte() { s.spatialAudio = v != 0 }           // 35
        _ = byte(); _ = byte(); _ = byte(); _ = byte()          // 36-39
        if let v = byte() { s.hearingEnhancements = v }         // 40
        // Buds3 Pro tail starts at 41 (verified against a live R630 capture).
        if let v = byte() { s.headTracking = v != 0 }           // 41
        if let v = byte() {                                    // 42
            s.leftCharging = (v & 0x10) != 0
            s.rightCharging = (v & 0x04) != 0
            s.caseCharging = (v & 0x01) != 0
        }
        if let v = byte() { s.extraClearCall = v != 0 }         // 43
        if let v = byte() { s.extraHighAmbient = v != 0 }       // 44
        if let v = byte() { s.autoPause = v != 0 }              // 45
        if let v = byte() { s.hotCommandEnabled = v != 0 }      // 46
        if let v = byte() { s.hotCommandLanguage = Int(v) }     // 47
        if let v = byte() { s.peqMod = Int(v) }                 // 48
        if let v = byte() { s.adaptiveVolume = v != 0 }         // 49
        if let v = byte() { s.lighting = Int(v) }               // 50
        if let v = byte() { s.quickLaunch = Int(v) }            // 51
        if let v = byte() { s.sirenDetect = v != 0 }            // 52
        if let v = byte() { s.adaptSound = v != 0 }             // 53
        if p.count >= 57 {
            s.hotCommandVersion = "\(p[54]).\(p[55]).\(p[56])"
        }
    }

    private static func parseBuds4(_ p: [UInt8], _ s: inout BudsState) {
        guard p.count >= 25 else { return }
        s.equalizerMode = Int(p[9])
        s.equalizerPreset = s.equalizerMode.map { max(0, $0 - 1) }
        // Buds4 bit order: bit3 single, bit2 double, bit1 triple, bit0 hold,
        // bit6 swipe, bit4/5 call gestures. No lock flag.
        let b = p[10]
        s.touchpad.locked = false
        s.touchpad.singleTap = (b & (1 << 3)) != 0
        s.touchpad.doubleTap = (b & (1 << 2)) != 0
        s.touchpad.tripleTap = (b & (1 << 1)) != 0
        s.touchpad.hold = (b & (1 << 0)) != 0
        s.touchpad.swipe = (b & (1 << 6)) != 0
        s.touchpad.doubleTapDuringCall = (b & (1 << 4)) != 0
        s.touchpad.holdDuringCall = (b & (1 << 5)) != 0
        s.touchpad.leftActionRaw = (p[11] & 0xF0) >> 4
        s.touchpad.rightActionRaw = p[11] & 0x0F
        s.noiseMode = NoiseMode(rawValue: Int(p[12]))
        s.voiceWakeUp = p[13] == 1
        s.deviceColorLeft = Int(p[14]) | (Int(p[15]) << 8)
        s.deviceColorRight = Int(p[16]) | (Int(p[17]) << 8)
        s.voiceWakeUpLanguage = Int(p[18])
        s.seamlessConnection = p[19] == 0
        s.fmmRevision = Int(p[20])
        parseAdaptiveTouchBits(p[21], &s)
        s.speakSeamlessly = p[22] == 1
        s.ambientVolume = Int(p[23])
        s.ancLevel = Int(p[24])
        if p.count >= 26 { s.hearingEnhancements = p[25] }
        if p.count >= 27 { s.detectConversations = p[26] == 1 }
        if p.count >= 28 { s.detectConversationsDuration = min(Int(p[27]), 2) }
        if p.count >= 29 { s.ancWithOneEarbud = p[28] == 1 }
        if p.count >= 34 {
            s.ambientCustomEnabled = p[29] == 1
            s.ambientCustomLeft = Int((p[30] & 0xF0) >> 4)
            s.ambientCustomRight = Int(p[30] & 0x0F)
            s.ambientTone = Int(p[31])
            s.touchpad.doubleTapVolume = p[32] == 1
            s.sidetone = p[33] == 1
        }
        var i = 34
        func byte() -> UInt8? { guard i < p.count else { return nil }; defer { i += 1 }; return p[i] }
        if let v = byte() { s.callPathControl = v == 0 }       // 34
        if let v = byte() { s.spatialAudio = v != 0 }           // 35
        _ = byte(); _ = byte(); _ = byte(); _ = byte()          // 36-39
        if let v = byte() { s.hearingEnhancements = v }         // 40
        if let v = byte() { s.autoAdjustSound = v != 0 }        // 41
        if let v = byte() { s.headTracking = v != 0 }           // 42
        if let v = byte() {                                    // 43
            s.leftCharging = (v & 0x10) != 0
            s.rightCharging = (v & 0x04) != 0
            s.caseCharging = (v & 0x01) != 0
        }
        if let v = byte() { s.extraClearCall = v != 0 }         // 44
        if let v = byte() { s.extraHighAmbient = v != 0 }       // 45
        if let v = byte() { s.autoPause = v != 0 }              // 46
        if let v = byte() { s.hotCommandEnabled = v != 0 }      // 47
        if let v = byte() { s.hotCommandLanguage = Int(v) }     // 48
        if let v = byte() { s.adaptiveEQ = v != 0 }             // 49
        if let v = byte() { s.adaptiveVolume = v != 0 }         // 50
        if let v = byte() { s.quickLaunch = Int(v) }            // 51
        if let v = byte() { s.sirenDetect = v != 0 }            // 52
        if let v = byte() { s.adaptSound = v != 0 }             // 53
        if p.count >= 57 { s.hotCommandVersion = "\(p[54]).\(p[55]).\(p[56])" }
    }

    private static func parseAdvancedTouch(_ b: UInt8, _ s: inout BudsState, forCalls: Bool = false, swipe: Bool = false) {
        // < Buds4 bit layout, verified against GalaxyBudsClient.
        s.touchpad.hold = (b & 0x01) != 0
        s.touchpad.tripleTap = (b & 0x02) != 0
        s.touchpad.doubleTap = (b & 0x04) != 0
        s.touchpad.singleTap = (b & 0x08) != 0
        s.touchpad.locked = (b & 0x80) == 0
        if forCalls {
            s.touchpad.holdDuringCall = (b & 0x20) != 0
            s.touchpad.doubleTapDuringCall = (b & 0x10) != 0
        }
        if swipe { s.touchpad.swipe = (b & 0x40) != 0 }
    }

    private static func parseAdaptiveTouchBits(_ b: UInt8, _ s: inout BudsState) {
        // Cycle mask only. Gesture enable flags come from the touch bitfield in
        // payload[10] and must not be overwritten here.
        s.touchpad.cycleBitsRight = b
        s.touchpad.cycleBitsLeft = b
    }

    private static func deriveWear(_ s: inout BudsState) {
        if s.placementLeft == .wearing && s.placementRight == .wearing { s.wearState = .both }
        else if s.placementLeft == .wearing { s.wearState = .left }
        else if s.placementRight == .wearing { s.wearState = .right }
        else { s.wearState = .none }
        if s.leftCharging == true { s.placementLeft = .charging }
        if s.rightCharging == true { s.placementRight = .charging }
    }

    private static func applyWear(_ s: inout BudsState) {
        switch s.wearState {
        case .both:
            s.placementLeft = .wearing; s.placementRight = .wearing
        case .left:
            s.placementLeft = .wearing; s.placementRight = .idle
        case .right:
            s.placementLeft = .idle; s.placementRight = .wearing
        case .none:
            s.placementLeft = .idle; s.placementRight = .idle
        }
    }
}

