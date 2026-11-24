import Foundation

/// SPP message IDs used by the Galaxy Buds protocol.
public enum MsgID {
    public static let acknowledgement: UInt8 = 0x42
    public static let statusUpdated: UInt8 = 0x60
    public static let extendedStatusUpdated: UInt8 = 0x61
    public static let versionInfo: UInt8 = 0x63
    public static let versionInfoLong: UInt8 = 0x68
    public static let customEqualizerRecv: UInt8 = 0x69
    public static let debugSKU: UInt8 = 0x22
    public static let debugBuildInfo: UInt8 = 0x28
    public static let debugSerialNumber: UInt8 = 0x29
    public static let debugGetAllData: UInt8 = 0x26
    public static let multipointInfo: UInt8 = 0x76
    public static let managerInfo: UInt8 = 0x88
    public static let noiseControls: UInt8 = 0x78
    public static let noiseControlsUpdate: UInt8 = 0x77
    public static let noiseReductionLevel: UInt8 = 0x83
    public static let setNoiseReduction: UInt8 = 0x98
    public static let setAmbientMode: UInt8 = 0x80
    public static let ambientModeUpdated: UInt8 = 0x81
    public static let customizeAmbient: UInt8 = 0x82
    public static let ambientVolume: UInt8 = 0x84
    public static let adjustSoundSync: UInt8 = 0x85
    public static let equalizer: UInt8 = 0x86
    public static let gameMode: UInt8 = 0x87
    public static let customEqualizerSend: UInt8 = 0x89
    public static let setInBandRingtone: UInt8 = 0x8A
    public static let setSidetone: UInt8 = 0x8B
    public static let setHearingEnhancements: UInt8 = 0x8F
    public static let lockTouchpad: UInt8 = 0x90
    public static let touchUpdated: UInt8 = 0x91
    public static let setTouchpadOption: UInt8 = 0x92
    public static let setTouchpadOtherOption: UInt8 = 0x93
    public static let batteryType: UInt8 = 0x94
    public static let outsideDoubleTap: UInt8 = 0x95
    public static let extraHighAmbient: UInt8 = 0x96
    public static let findMyEarbudsStart: UInt8 = 0xA0
    public static let findMyEarbudsStop: UInt8 = 0xA1
    public static let findMyEarbudsOnWearingStart: UInt8 = 0xA6
    public static let updateTime: UInt8 = 0xA7
    public static let setDetectConversations: UInt8 = 0x7A
    public static let setDetectConversationsDuration: UInt8 = 0x7B
    public static let setSpatialAudio: UInt8 = 0x7C
    public static let setSpeakSeamlessly: UInt8 = 0x7D
    public static let setAncWithOneEarbud: UInt8 = 0x6F
    public static let pauseMediaWhenOneBudRemoved: UInt8 = 0x6C
    public static let setCallPathControl: UInt8 = 0x6E
    public static let setSeamlessConnection: UInt8 = 0xAF
    public static let adaptiveEQVolume: UInt8 = 0xD9
    public static let adaptiveEQControl: UInt8 = 0xDA
    public static let adaptiveEQStatus: UInt8 = 0xDB
    public static let sirenDetect: UInt8 = 0xDE
    public static let getPersonalName: UInt8 = 0xD3
    public static let cradleSerialNumber: UInt8 = 0xCD
    public static let checkFit: UInt8 = 0x9D
    public static let fitResult: UInt8 = 0x9E
    public static let selfTest: UInt8 = 0xAB
    public static let reset: UInt8 = 0x50
    public static let reboot: UInt8 = 0x52
    public static let pairingMode: UInt8 = 0x72
    public static let lightingSync: UInt8 = 0x8E
    public static let setHotCommand: UInt8 = 0x64
    public static let usageReport: UInt8 = 0x40
    public static let usageReportV2: UInt8 = 0x47
    public static let spatialAudioData: UInt8 = 0xC2
    public static let spatialAudioControl: UInt8 = 0xC3
    public static let bondedDevices: UInt8 = 0xD6

    public static func name(_ id: UInt8) -> String {
        switch id {
        case acknowledgement: return "ACK"
        case statusUpdated: return "STATUS_UPDATED"
        case extendedStatusUpdated: return "EXTENDED_STATUS"
        case versionInfo: return "VERSION_INFO"
        case versionInfoLong: return "VERSION_INFO_LONG"
        case customEqualizerRecv: return "CUSTOM_EQ_RECV"
        case debugSKU: return "DEBUG_SKU"
        case debugBuildInfo: return "BUILD_INFO"
        case debugSerialNumber: return "SERIAL"
        case debugGetAllData: return "DEBUG_ALL"
        case multipointInfo: return "MULTIPOINT"
        case managerInfo: return "MANAGER_INFO"
        case noiseControls: return "NOISE_CONTROLS"
        case noiseControlsUpdate: return "NOISE_UPDATE"
        case noiseReductionLevel: return "ANC_LEVEL"
        case customizeAmbient: return "CUSTOM_AMBIENT"
        case ambientVolume: return "AMBIENT_VOLUME"
        case equalizer: return "EQUALIZER"
        case gameMode: return "GAME_MODE"
        case customEqualizerSend: return "CUSTOM_EQ_SEND"
        case setSidetone: return "SIDETONE"
        case lockTouchpad: return "LOCK_TOUCHPAD"
        case setTouchpadOption: return "TOUCH_OPTION"
        case batteryType: return "BATTERY_TYPE"
        case outsideDoubleTap: return "DOUBLE_TAP_VOLUME"
        case extraHighAmbient: return "EXTRA_HIGH_AMBIENT"
        case findMyEarbudsStart: return "FIND_START"
        case findMyEarbudsStop: return "FIND_STOP"
        case findMyEarbudsOnWearingStart: return "FIND_WEARING"
        case updateTime: return "UPDATE_TIME"
        case setDetectConversations: return "VOICE_DETECT"
        case setDetectConversationsDuration: return "VOICE_DETECT_TIME"
        case setSpatialAudio: return "SPATIAL_AUDIO"
        case setSpeakSeamlessly: return "SPEAK_SEAMLESSLY"
        case setAncWithOneEarbud: return "ANC_ONE_BUD"
        case pauseMediaWhenOneBudRemoved: return "AUTO_PAUSE"
        case setCallPathControl: return "CALL_PATH"
        case setSeamlessConnection: return "SEAMLESS"
        case adaptiveEQVolume: return "ADAPTIVE_VOLUME"
        case sirenDetect: return "SIREN_DETECT"
        case getPersonalName: return "PERSONAL_NAME"
        case cradleSerialNumber: return "CRADLE_SERIAL"
        case checkFit: return "FIT_TEST"
        case fitResult: return "FIT_RESULT"
        case selfTest: return "SELF_TEST"
        case reset: return "RESET"
        case reboot: return "REBOOT"
        case pairingMode: return "PAIRING_MODE"
        case lightingSync: return "LIGHTING"
        case setHotCommand: return "HOT_COMMAND"
        case usageReport: return "USAGE"
        case usageReportV2: return "USAGE_V2"
        case spatialAudioData: return "SPATIAL_DATA"
        case spatialAudioControl: return "SPATIAL_CONTROL"
        case bondedDevices: return "BONDED_DEVICES"
        default: return String(format: "0x%02X", id)
        }
    }
}
