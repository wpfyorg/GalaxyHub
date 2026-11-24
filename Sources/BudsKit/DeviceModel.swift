import Foundation

public enum DeviceFeature: String, Codable, CaseIterable, Sendable {
    case noiseControl, adaptiveMode, ancLevel, ambientSound, ambientVolume, ambientCustomize, sidetone, extraHighAmbient
    case detectConversations, ancWithOneEarbud, adaptiveVolume, sirenDetect, autoPause, speakSeamlessly
    case equalizer, customEqualizer
    case touchLock, advancedTouch, callGestures, swipeGesture, doubleTapVolume, noiseControlCycle
    case findMyBuds, findWhileWearing
    case caseBattery, chargingState
    case multipoint, spatialAudio, headTracking, fitTest, rename, cradleSerial, usageReport, hotCommand, lighting
    case firmwareUpdates, batteryType, buildInfo, pairingMode, seamlessConnection

    public var title: String {
        switch self {
        case .noiseControl: return "Noise control"
        case .adaptiveMode: return "Adaptive noise control"
        case .ancLevel: return "Noise cancellation level"
        case .ambientSound: return "Ambient sound"
        case .ambientVolume: return "Ambient volume"
        case .ambientCustomize: return "Custom ambient sound"
        case .sidetone: return "Sidetone"
        case .extraHighAmbient: return "Extra-high ambient"
        case .detectConversations: return "Detect conversations"
        case .ancWithOneEarbud: return "Noise control with one earbud"
        case .adaptiveVolume: return "Adaptive volume"
        case .sirenDetect: return "Siren detect"
        case .autoPause: return "Pause when one earbud is removed"
        case .speakSeamlessly: return "Speak seamlessly"
        case .equalizer: return "Equalizer"
        case .customEqualizer: return "Custom equalizer"
        case .touchLock: return "Touchpad lock"
        case .advancedTouch: return "Advanced touch controls"
        case .callGestures: return "Gestures during calls"
        case .swipeGesture: return "Volume swipe"
        case .doubleTapVolume: return "Double-tap the side to change volume"
        case .noiseControlCycle: return "Noise control cycle"
        case .findMyBuds: return "Find my earbuds"
        case .findWhileWearing: return "Find while wearing"
        case .caseBattery: return "Case battery"
        case .chargingState: return "Charging state"
        case .multipoint: return "Multipoint"
        case .spatialAudio: return "Spatial audio"
        case .headTracking: return "Head tracking"
        case .fitTest: return "Fit test"
        case .rename: return "Rename"
        case .cradleSerial: return "Cradle serial"
        case .usageReport: return "Usage report"
        case .hotCommand: return "Voice wake-up"
        case .lighting: return "Blade lights"
        case .firmwareUpdates: return "Firmware information"
        case .batteryType: return "Battery type"
        case .buildInfo: return "Build information"
        case .pairingMode: return "Pairing mode"
        case .seamlessConnection: return "Seamless connection"
        }
    }
}

public enum TouchAction: Int, Codable, CaseIterable, Sendable {
    case voiceAssistant
    case quickAmbient
    case volume
    case ambient
    case anc
    case noiseControl
    case spotify

    public var title: String {
        switch self {
        case .voiceAssistant: return "Voice assistant"
        case .quickAmbient: return "Quick ambient"
        case .volume: return "Volume"
        case .ambient: return "Ambient sound"
        case .anc: return "Noise cancellation"
        case .noiseControl: return "Noise control"
        case .spotify: return "Spotify"
        }
    }
}

public enum DeviceModelID: String, Codable, CaseIterable, Sendable {
    case buds, budsPlus, budsLive, budsPro, buds2, buds2Pro, budsFe, budsCore
    case buds3, buds3Pro, buds3Fe, buds4, buds4Pro
}

public struct DeviceModel: Identifiable, Equatable, Sendable {
    public let id: DeviceModelID
    public let displayName: String
    public let buildPrefix: String
    public let productIDs: Set<Int>
    public let serviceUUIDs: [String]
    public let frameStyle: FrameStyle
    public let features: Set<DeviceFeature>
    public let ambientVolumeMax: Int
    public let touchMap: [TouchAction: UInt8]

    public var customEQBands: Int { features.contains(.customEqualizer) ? 9 : 0 }
    public var eqPresetCount: Int { 5 }
    public var legacy: Bool { frameStyle == .legacy }

    public var availableTouchActions: [TouchAction] {
        touchMap.keys.sorted { $0.rawValue < $1.rawValue }
    }

    public func supports(_ feature: DeviceFeature) -> Bool { features.contains(feature) }
}

public enum DeviceCatalog {
    public static let all: [DeviceModel] = [
        DeviceModel(
            id: .buds,
            displayName: "Galaxy Buds",
            buildPrefix: "R170",
            productIDs: [257, 14336],
            serviceUUIDs: ["00001102-0000-1000-8000-00805f9b34fd"],
            frameStyle: .legacy,
            features: [.ambientSound, .ambientVolume, .touchLock, .caseBattery, .batteryType, .buildInfo,
                       .pairingMode, .usageReport, .seamlessConnection],
            ambientVolumeMax: 4,
            touchMap: [.voiceAssistant: 0, .quickAmbient: 1, .volume: 2, .ambient: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .budsPlus,
            displayName: "Galaxy Buds+",
            buildPrefix: "R175",
            productIDs: Set(258...266),
            serviceUUIDs: ["00001101-0000-1000-8000-00805f9b34fb"],
            frameStyle: .modern,
            features: [.ambientSound, .ambientVolume, .extraHighAmbient, .sidetone, .touchLock, .advancedTouch,
                       .doubleTapVolume, .noiseControlCycle, .caseBattery, .findMyBuds, .findWhileWearing,
                       .multipoint, .batteryType, .buildInfo, .pairingMode, .usageReport, .seamlessConnection,
                       .firmwareUpdates],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .ambient: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .budsLive,
            displayName: "Galaxy Buds Live",
            buildPrefix: "R180",
            productIDs: Set(278...284),
            serviceUUIDs: ["00001101-0000-1000-8000-00805f9b34fb"],
            frameStyle: .modern,
            features: [.touchLock, .advancedTouch, .noiseControlCycle, .caseBattery,
                       .findMyBuds, .findWhileWearing, .multipoint, .spatialAudio, .fitTest, .batteryType,
                       .buildInfo, .pairingMode, .usageReport, .seamlessConnection, .firmwareUpdates],
            ambientVolumeMax: 0,
            touchMap: [.voiceAssistant: 1, .anc: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .budsPro,
            displayName: "Galaxy Buds Pro",
            buildPrefix: "R190",
            productIDs: Set(298...301),
            serviceUUIDs: ["00001101-0000-1000-8000-00805f9b34fb"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .extraHighAmbient, .detectConversations, .ancWithOneEarbud, .touchLock, .advancedTouch,
                       .callGestures, .noiseControlCycle, .doubleTapVolume, .caseBattery, .findMyBuds,
                       .findWhileWearing, .multipoint, .spatialAudio, .fitTest, .batteryType, .buildInfo,
                       .pairingMode, .usageReport, .seamlessConnection, .firmwareUpdates],
            ambientVolumeMax: 3,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds2,
            displayName: "Galaxy Buds2",
            buildPrefix: "R177",
            productIDs: Set(313...321),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .extraHighAmbient, .ancWithOneEarbud, .touchLock, .advancedTouch, .callGestures,
                       .noiseControlCycle, .doubleTapVolume, .caseBattery, .chargingState, .findMyBuds,
                       .findWhileWearing, .multipoint, .spatialAudio, .fitTest, .rename, .usageReport,
                       .seamlessConnection, .firmwareUpdates],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds2Pro,
            displayName: "Galaxy Buds2 Pro",
            buildPrefix: "R510",
            productIDs: Set(325...328),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .extraHighAmbient, .detectConversations, .ancWithOneEarbud, .touchLock, .advancedTouch,
                       .callGestures, .noiseControlCycle, .doubleTapVolume, .caseBattery, .chargingState,
                       .findMyBuds, .findWhileWearing, .multipoint, .spatialAudio, .headTracking, .fitTest,
                       .rename, .cradleSerial, .usageReport, .seamlessConnection, .firmwareUpdates],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .budsFe,
            displayName: "Galaxy Buds FE",
            buildPrefix: "R400",
            productIDs: Set(330...331),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .ancWithOneEarbud, .touchLock, .advancedTouch, .callGestures, .noiseControlCycle,
                       .doubleTapVolume, .caseBattery, .chargingState, .findMyBuds, .findWhileWearing,
                       .multipoint, .fitTest, .rename, .usageReport, .seamlessConnection, .firmwareUpdates],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .budsCore,
            displayName: "Galaxy Buds Core",
            buildPrefix: "R410",
            productIDs: Set(322...323),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .ancWithOneEarbud, .touchLock, .advancedTouch, .callGestures, .noiseControlCycle,
                       .doubleTapVolume, .caseBattery, .chargingState, .findMyBuds, .findWhileWearing,
                       .multipoint, .fitTest, .rename, .usageReport, .seamlessConnection, .firmwareUpdates],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds3,
            displayName: "Galaxy Buds3",
            buildPrefix: "R530",
            productIDs: Set(333...334),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .ancWithOneEarbud, .adaptiveVolume, .autoPause, .touchLock, .advancedTouch, .callGestures,
                       .swipeGesture, .noiseControlCycle, .doubleTapVolume, .caseBattery, .chargingState,
                       .findMyBuds, .findWhileWearing, .multipoint, .spatialAudio, .fitTest, .rename,
                       .usageReport, .seamlessConnection, .firmwareUpdates, .hotCommand, .equalizer,
                       .customEqualizer],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds3Pro,
            displayName: "Galaxy Buds3 Pro",
            buildPrefix: "R630",
            productIDs: Set(340...341),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize,
                       .sidetone, .extraHighAmbient, .detectConversations, .ancWithOneEarbud, .adaptiveVolume,
                       .sirenDetect, .autoPause, .speakSeamlessly, .touchLock, .advancedTouch, .callGestures,
                       .swipeGesture, .noiseControlCycle, .doubleTapVolume, .caseBattery, .chargingState,
                       .findMyBuds, .findWhileWearing, .multipoint, .spatialAudio, .headTracking, .fitTest,
                       .rename, .cradleSerial, .usageReport, .seamlessConnection, .firmwareUpdates, .hotCommand,
                       .lighting, .equalizer, .customEqualizer],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds3Fe,
            displayName: "Galaxy Buds3 FE",
            buildPrefix: "R420",
            productIDs: Set(347...348),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize, .sidetone,
                       .ancWithOneEarbud, .touchLock, .advancedTouch, .callGestures, .noiseControlCycle,
                       .doubleTapVolume, .caseBattery, .chargingState, .findMyBuds, .findWhileWearing,
                       .multipoint, .fitTest, .rename, .usageReport, .seamlessConnection, .firmwareUpdates,
                       .hotCommand, .equalizer, .customEqualizer],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds4,
            displayName: "Galaxy Buds4",
            buildPrefix: "R540",
            productIDs: Set(355...356),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .adaptiveMode, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize,
                       .sidetone, .adaptiveVolume, .sirenDetect, .autoPause, .touchLock, .advancedTouch,
                       .callGestures, .swipeGesture, .noiseControlCycle, .doubleTapVolume, .caseBattery,
                       .chargingState, .findMyBuds, .findWhileWearing, .multipoint, .spatialAudio, .fitTest,
                       .rename, .usageReport, .seamlessConnection, .firmwareUpdates, .hotCommand, .equalizer,
                       .customEqualizer],
            ambientVolumeMax: 2,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        ),
        DeviceModel(
            id: .buds4Pro,
            displayName: "Galaxy Buds4 Pro",
            buildPrefix: "R640",
            productIDs: Set(359...361),
            serviceUUIDs: ["2e73a4ad-332d-41fc-90e2-16bef06523f2"],
            frameStyle: .modern,
            features: [.noiseControl, .adaptiveMode, .ancLevel, .ambientSound, .ambientVolume, .ambientCustomize,
                       .sidetone, .detectConversations, .ancWithOneEarbud, .adaptiveVolume, .sirenDetect,
                       .autoPause, .touchLock, .advancedTouch, .callGestures, .swipeGesture, .noiseControlCycle,
                       .doubleTapVolume, .caseBattery, .chargingState, .findMyBuds, .findWhileWearing,
                       .multipoint, .spatialAudio, .headTracking, .fitTest, .rename, .cradleSerial,
                       .usageReport, .seamlessConnection, .firmwareUpdates, .hotCommand, .equalizer,
                       .customEqualizer],
            ambientVolumeMax: 4,
            touchMap: [.voiceAssistant: 1, .noiseControl: 2, .volume: 3, .spotify: 4]
        )
    ]

    public static func model(for id: DeviceModelID) -> DeviceModel {
        all.first { $0.id == id } ?? all[0]
    }

    public static func model(productID: Int) -> DeviceModel? {
        all.first { $0.productIDs.contains(productID) }
    }

    public static func model(skuOrFirmware string: String) -> DeviceModel? {
        let upper = string.uppercased()
        // Longest/most specific build prefix first so R400N wins over R400 and
        // R630 wins over R63x style false positives.
        let sorted = all.sorted { $0.buildPrefix.count > $1.buildPrefix.count }
        return sorted.first { upper.contains($0.buildPrefix) }
    }

    public static func model(deviceName: String) -> DeviceModel? {
        let name = deviceName.lowercased()
        // Most specific names first.
        let ordered: [DeviceModelID] = [.buds4Pro, .buds4, .buds3Pro, .buds3Fe, .buds3, .buds2Pro, .buds2,
                                        .budsLive, .budsPro, .budsPlus, .budsFe, .budsCore, .buds]
        for id in ordered {
            let model = model(for: id)
            let needles = [model.displayName.lowercased(), model.buildPrefix.lowercased(),
                           model.displayName.replacingOccurrences(of: "Galaxy ", with: "").lowercased()]
            if needles.contains(where: { name.contains($0) }) { return model }
        }
        return nil
    }

    /// Extracts the Samsung product ID from the vendor-specific SPP service UUID
    /// (`d908aab5-7a90-4cbe-8641-86a553dbXXXXXXXX`).
    public static func productID(fromServiceUUID uuid: String) -> Int? {
        let compact = uuid.replacingOccurrences(of: "-", with: "").lowercased()
        let prefix = "d908aab57a904cbe864186a553db"
        guard compact.hasPrefix(prefix), compact.count >= prefix.count + 8 else { return nil }
        let suffix = String(compact.suffix(8))
        return Int(suffix, radix: 16)
    }
}
