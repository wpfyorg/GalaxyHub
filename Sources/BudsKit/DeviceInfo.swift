import Foundation

public struct DeviceInfo: Equatable, Sendable {
    public var skuLeft: String?
    public var skuRight: String?
    public var firmwareLeft: String?
    public var firmwareRight: String?
    public var build: String?
    public var serialLeft: String?
    public var serialRight: String?
    public var cradleSerial: String?
    public var modelName: String?
    public var deviceColor: Int?
    public init() {}
}

public struct CustomEQData: Equatable, Sendable {
    public var presetCount: Int
    public var bandCount: Int
    public var bands: [Int]
}

public struct Acknowledgement: Equatable, Sendable {
    public var command: UInt8
    public var payload: [UInt8]
}

public enum PayloadParser {
    private static func ascii(_ bytes: [UInt8]) -> String {
        String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public static func parseSKU(_ p: [UInt8]) -> (left: String?, right: String?) {
        guard p.count >= 14 else { return (nil, nil) }
        let left = ascii(Array(p[0..<14]))
        let right = p.count >= 28 ? ascii(Array(p[14..<28])) : nil
        return (left.isEmpty ? nil : left, right?.isEmpty == true ? nil : right)
    }

    public static func parseVersionInfo(_ p: [UInt8]) -> (left: String?, right: String?) {
        guard p.count >= 16 else { return (nil, nil) }
        let left = ascii(Array(p[2..<16]))
        let right = p.count >= 30 ? ascii(Array(p[16..<30])) : nil
        return (left.isEmpty ? nil : left, right?.isEmpty == true ? nil : right)
    }

    public static func parseBuildInfo(_ p: [UInt8]) -> String? {
        let text = ascii(p)
        return text.isEmpty ? nil : text
    }

    public static func parseCustomEQ(_ p: [UInt8]) -> CustomEQData? {
        guard p.count >= 2 else { return nil }
        let presetCount = Int(p[0])
        let bandCount = Int(p[1])
        guard bandCount > 0 else { return nil }
        let offset = 2 + max(0, (presetCount - 1)) * bandCount
        guard offset + bandCount <= p.count else { return nil }
        let bands = p[offset..<(offset + bandCount)].map { Int(Int8(bitPattern: $0)) }
        return CustomEQData(presetCount: presetCount, bandCount: bandCount, bands: bands)
    }

    public static func parseMultipoint(_ p: [UInt8]) -> MultipointState? {
        guard p.count >= 5 else { return nil }
        var m = MultipointState()
        m.revision = Int(p[0])
        m.supported = p[1] == 1
        m.haveDevices = p[2] == 0
        m.audioFocusForeground = p[3] == 0
        m.streamingMask = p[4]
        return m
    }

    public static func parseAcknowledgement(_ p: [UInt8]) -> Acknowledgement? {
        guard let command = p.first else { return nil }
        return Acknowledgement(command: command, payload: Array(p.dropFirst()))
    }

    public static func parseFitResult(_ p: [UInt8]) -> (left: Int, right: Int)? {
        guard p.count >= 2 else { return nil }
        return (Int(p[0]), Int(p[1]))
    }

    public static func parseBatteryType(_ p: [UInt8]) -> String? {
        guard !p.isEmpty else { return nil }
        let map = ["Unknown", "AA", "AAA", "Coin"]
        return map.indices.contains(Int(p[0])) ? map[Int(p[0])] : "Type \(p[0])"
    }

    public static func parseChargingStatus(_ byte: UInt8) -> (left: Bool, right: Bool, cradle: Bool) {
        ((byte & 0x10) != 0, (byte & 0x04) != 0, (byte & 0x01) != 0)
    }
}

public enum Commands {
    public static func managerInfo() -> SPPFrame {
        SPPFrame(id: MsgID.managerInfo, payload: [1, 1, 34])
    }

    public static func updateTime() -> SPPFrame {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let offset = Int32(TimeZone.current.secondsFromGMT() * 1000)
        var payload = [UInt8]()
        withUnsafeBytes(of: timestamp.littleEndian) { payload.append(contentsOf: $0) }
        withUnsafeBytes(of: offset.littleEndian) { payload.append(contentsOf: $0) }
        return SPPFrame(id: MsgID.updateTime, payload: payload)
    }

    public static func debugSKU() -> SPPFrame { SPPFrame(id: MsgID.debugSKU, payload: []) }
    public static func debugSerial() -> SPPFrame { SPPFrame(id: MsgID.debugSerialNumber, payload: []) }
    public static func versionInfo() -> SPPFrame { SPPFrame(id: MsgID.versionInfo, payload: []) }
    public static func cradleSerial() -> SPPFrame { SPPFrame(id: MsgID.cradleSerialNumber, payload: []) }
    public static func multipoint() -> SPPFrame { SPPFrame(id: MsgID.multipointInfo, payload: []) }
    public static func customEQQuery() -> SPPFrame { SPPFrame(id: MsgID.customEqualizerRecv, payload: []) }
    public static func batteryType() -> SPPFrame { SPPFrame(id: MsgID.batteryType, payload: []) }

    public static func noiseMode(_ mode: NoiseMode) -> SPPFrame {
        SPPFrame(id: MsgID.noiseControls, payload: [UInt8(mode.rawValue)])
    }

    public static func legacyAmbient(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setAmbientMode, payload: [enabled ? 1 : 0])
    }

    public static func legacyANC(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setNoiseReduction, payload: [enabled ? 1 : 0])
    }

    public static func ancLevel(_ high: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.noiseReductionLevel, payload: [high ? 1 : 0])
    }

    public static func ambientVolume(_ value: Int) -> SPPFrame {
        SPPFrame(id: MsgID.ambientVolume, payload: [UInt8(clamping: value)])
    }

    public static func customAmbient(enabled: Bool, left: Int, right: Int, tone: Int) -> SPPFrame {
        SPPFrame(id: MsgID.customizeAmbient,
                 payload: [enabled ? 1 : 0, UInt8(clamping: left), UInt8(clamping: right), UInt8(clamping: tone)])
    }

    public static func sidetone(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setSidetone, payload: [enabled ? 1 : 0])
    }

    public static func extraHighAmbient(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.extraHighAmbient, payload: [enabled ? 1 : 0])
    }

    public static func doubleTapVolume(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.outsideDoubleTap, payload: [enabled ? 1 : 0])
    }

    public static func detectConversations(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setDetectConversations, payload: [enabled ? 1 : 0])
    }

    public static func detectConversationsDuration(_ seconds: Int) -> SPPFrame {
        // 0 = 5 s, 1 = 10 s, 2 = 15 s
        SPPFrame(id: MsgID.setDetectConversationsDuration, payload: [UInt8(clamping: max(0, min(2, seconds)))])
    }

    public static func ancWithOneEarbud(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setAncWithOneEarbud, payload: [enabled ? 1 : 0])
    }

    public static func adaptiveVolume(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.adaptiveEQVolume, payload: [enabled ? 1 : 0])
    }

    public static func sirenDetect(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.sirenDetect, payload: [enabled ? 1 : 0])
    }

    public static func autoPause(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.pauseMediaWhenOneBudRemoved, payload: [enabled ? 1 : 0])
    }

    public static func speakSeamlessly(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setSpeakSeamlessly, payload: [enabled ? 1 : 0])
    }

    public static func seamlessConnection(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setSeamlessConnection, payload: [enabled ? 0 : 1])
    }

    public static func callPathControl(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setCallPathControl, payload: [enabled ? 0 : 1])
    }

    public static func equalizer(enabled: Bool, preset: Int) -> SPPFrame {
        // Modern devices: 0 = off, preset + 1 = enabled preset.
        SPPFrame(id: MsgID.equalizer, payload: [enabled ? UInt8(clamping: preset + 1) : 0])
    }

    public static func legacyEqualizer(enabled: Bool, preset: Int) -> SPPFrame {
        var raw = preset
        raw += 5 // non-Dolby presets
        return SPPFrame(id: MsgID.equalizer, payload: [enabled ? 1 : 0, UInt8(clamping: raw)])
    }

    public static func customEqualizer(bands: [Int]) -> SPPFrame {
        let clamped = bands.prefix(9).map { UInt8(bitPattern: Int8(clamping: max(-10, min(10, $0)))) }
        return SPPFrame(id: MsgID.customEqualizerSend, payload: [UInt8(clamped.count)] + clamped)
    }

    public static func gameMode(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.gameMode, payload: [enabled ? 1 : 0])
    }

    public static func findMyEarbuds(active: Bool) -> SPPFrame {
        SPPFrame(id: active ? MsgID.findMyEarbudsStart : MsgID.findMyEarbudsStop, payload: [])
    }

    public static func findMyEarbudsWhileWearing(active: Bool) -> SPPFrame {
        SPPFrame(id: active ? MsgID.findMyEarbudsOnWearingStart : MsgID.findMyEarbudsStop, payload: [])
    }

    public static func touchOptions(left: UInt8, right: UInt8) -> SPPFrame {
        SPPFrame(id: MsgID.setTouchpadOption, payload: [left, right])
    }

    public static func lockTouchpad(locked: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.lockTouchpad, payload: [locked ? 1 : 0])
    }

    public static func noiseControlCycle(bitsLeft: UInt8, bitsRight: UInt8) -> SPPFrame {
        SPPFrame(id: MsgID.setTouchpadOtherOption, payload: [bitsLeft, bitsRight])
    }

    public static func spatialAudio(_ enabled: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.setSpatialAudio, payload: [enabled ? 1 : 0])
    }

    public static func headTracking(_ enabled: Bool) -> SPPFrame {
        // Same command, second byte selects head tracking on supported firmware.
        SPPFrame(id: MsgID.setSpatialAudio, payload: [1, enabled ? 1 : 0])
    }

    public static func fitTest(_ active: Bool) -> SPPFrame {
        SPPFrame(id: MsgID.checkFit, payload: [active ? 1 : 0])
    }

    public static func raw(id: UInt8, payload: [UInt8]) -> SPPFrame {
        SPPFrame(id: id, payload: payload)
    }
}
