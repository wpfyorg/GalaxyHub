import Foundation
import Combine

public enum EQSelection: Hashable, Sendable {
    case off
    case preset(Int)
    case custom
}

@MainActor
public final class BudsController: ObservableObject {
    public enum Link: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)

        public var isConnected: Bool { self == .connected }
        public var isBusy: Bool { self == .connecting }
    }

    // MARK: Published state

    @Published public private(set) var link: Link = .idle
    @Published public private(set) var lastError: String?
    @Published public private(set) var deviceName = "Galaxy Buds"
    @Published public private(set) var address: String?
    @Published public private(set) var model: DeviceModel?
    @Published public private(set) var detectedModel: DeviceModel?
    @Published public private(set) var serviceName = ""
    @Published public private(set) var isDemo = false

    @Published public private(set) var leftBattery: BatteryLevel?
    @Published public private(set) var rightBattery: BatteryLevel?
    @Published public private(set) var caseBattery: BatteryLevel?
    @Published public private(set) var placementLeft: Placement = .disconnected
    @Published public private(set) var placementRight: Placement = .disconnected
    @Published public private(set) var wearState: WearState = .none
    @Published public private(set) var coupled = false

    @Published public private(set) var noiseMode: NoiseMode?
    @Published public private(set) var ancLevelHigh = false
    @Published public private(set) var ambientVolume = 0
    @Published public private(set) var ambientCustomEnabled = false
    @Published public private(set) var ambientCustomLeft = 0
    @Published public private(set) var ambientCustomRight = 0
    @Published public private(set) var ambientTone = 0
    @Published public private(set) var sidetone = false
    @Published public private(set) var extraHighAmbient = false
    @Published public private(set) var detectConversations = false
    @Published public private(set) var detectConversationsDuration = 1
    @Published public private(set) var ancWithOneEarbud = true
    @Published public private(set) var adaptiveVolume = false
    @Published public private(set) var sirenDetect = false
    @Published public private(set) var autoPause = true
    @Published public private(set) var speakSeamlessly = false
    @Published public private(set) var seamlessConnection = true
    @Published public private(set) var spatialAudio = false
    @Published public private(set) var headTracking = false
    @Published public private(set) var gameMode = false

    @Published public private(set) var eqSelection: EQSelection = .off
    @Published public private(set) var customEQBands: [Int] = Array(repeating: 0, count: 9)
    @Published public private(set) var customEQBandsFromDevice = false
    @Published public private(set) var hotCommandEnabled = false
    @Published public private(set) var hotCommandLanguage = 0
    @Published public private(set) var hotCommandVersion: String?
    @Published public private(set) var lightingStyle = 0
    @Published public private(set) var quickLaunch = 0
    @Published public private(set) var revision = 0

    @Published public private(set) var touchLocked = false
    @Published public private(set) var touchSingleTap = true
    @Published public private(set) var touchDoubleTap = true
    @Published public private(set) var touchTripleTap = true
    @Published public private(set) var touchHold = true
    @Published public private(set) var touchDoubleTapDuringCall = true
    @Published public private(set) var touchHoldDuringCall = true
    @Published public private(set) var touchSwipe = false
    @Published public private(set) var doubleTapVolume = false
    @Published public private(set) var touchLeftAction: TouchAction = .noiseControl
    @Published public private(set) var touchRightAction: TouchAction = .noiseControl
    @Published public private(set) var cycleBitsLeft: UInt8 = 0
    @Published public private(set) var cycleBitsRight: UInt8 = 0

    @Published public private(set) var findMyBudsActive = false
    @Published public private(set) var multipoint: MultipointState?
    @Published public private(set) var deviceInfo = DeviceInfo()
    @Published public private(set) var fitResult: (left: Int, right: Int)?
    @Published public private(set) var batteryType: String?

    @Published public private(set) var packetLog: [PacketLogEntry] = []
    @Published public private(set) var lastPacketAt: Date?

    @Published public var autoReconnect: Bool {
        didSet { SettingsStore.shared.autoReconnect = autoReconnect; configureReconnectTimer() }
    }
    @Published public var rememberSettings: Bool {
        didSet { SettingsStore.shared.rememberSettings = rememberSettings }
    }
    @Published public var menuBarBattery: Bool {
        didSet { SettingsStore.shared.menuBarBattery = menuBarBattery }
    }
    @Published public var autoClaimAudio: Bool {
        didSet { SettingsStore.shared.autoClaimAudio = autoClaimAudio }
    }

    // MARK: Internals

    public static let presetNames = ["Bass boost", "Soft", "Dynamic", "Clear", "Treble boost"]
    public static let customPresetIndex = 6

    private var transport: BudsLink?
    private lazy var bluetoothTransport = IOBluetoothTransport()
    private var frameBuffer: [UInt8] = []
    private let store = SettingsStore.shared
    private var reconnectTimer: Timer?
    private var userDisconnected = false
    private var didHandshake = false
    private var didApplySaved = false
    private var connectWatchdog: DispatchWorkItem?
    private var pendingConnectAddress: String?
    private var pendingModelOverride: DeviceModel?
    private var packetCount = 0
    private var framesSinceConnect = 0
    private var sawStatusSinceConnect = false
    private var connectionGeneration = 0
    private var fitTestGeneration = 0

    public init() {
        autoReconnect = store.autoReconnect
        rememberSettings = store.rememberSettings
        menuBarBattery = store.menuBarBattery
        autoClaimAudio = store.autoClaimAudio
    }

    deinit {
        reconnectTimer?.invalidate()
        connectWatchdog?.cancel()
    }

    // MARK: Capabilities

    public var supports: (DeviceFeature) -> Bool {
        { [weak self] feature in self?.model?.supports(feature) ?? false }
    }

    public func has(_ feature: DeviceFeature) -> Bool { model?.supports(feature) ?? false }

    public var availableNoiseModes: [NoiseMode] {
        guard let model else { return [] }
        if model.supports(.noiseControl) {
            var modes: [NoiseMode] = [.off, .anc, .ambient]
            if model.supports(.adaptiveMode) { modes.append(.adaptive) }
            return modes
        }
        if model.supports(.ambientSound) { return [.off, .ambient] }
        if model.supports(.ancLevel) || model.id == .budsLive { return [.off, .anc] }
        return []
    }

    public var eqSelectedPresetIndex: Int? {
        if case .preset(let index) = eqSelection { return index }
        return nil
    }

    public var isCustomEQSelected: Bool { eqSelection == .custom }
    public var isEQOff: Bool { eqSelection == .off }

    public var frameStyle: FrameStyle { model?.frameStyle ?? .modern }

    public var batteryMin: Int? {
        [leftBattery?.level, rightBattery?.level].compactMap { $0 }.min()
    }

    public var needsModelDetection: Bool { detectedModel == nil }

    // MARK: Connection

    public func start() {
        configureReconnectTimer()
        guard autoReconnect, let last = store.lastAddress, transport == nil, link == .idle else { return }
        connect(address: last, demo: false)
    }

    public func connect(address: String, demo: Bool = false, modelOverride: DeviceModel? = nil) {
        if link == .connecting { return }
        if !demo, bluetoothTransport.isBusy {
            lastError = "Bluetooth is still opening the previous connection. Wait a moment and try again."
            return
        }
        userDisconnected = false
        lastError = nil
        link = .connecting
        didHandshake = false
        didApplySaved = false
        frameBuffer.removeAll()
        framesSinceConnect = 0
        sawStatusSinceConnect = false
        connectionGeneration += 1
        let generation = connectionGeneration
        pendingConnectAddress = address
        pendingModelOverride = modelOverride
        isDemo = demo
        self.address = address
        if !demo { store.lastAddress = address }
        resetSessionState()

        let saved = store.state(for: address)
        let preferred: DeviceModel? = modelOverride
            ?? saved.modelOverride.flatMap(DeviceModelID.init(rawValue:)).map(DeviceCatalog.model(for:))
            ?? saved.detectedModel.flatMap(DeviceModelID.init(rawValue:)).map(DeviceCatalog.model(for:))
        model = preferred

        let newTransport: BudsLink
        if demo {
            newTransport = DemoTransport()
        } else {
            newTransport = bluetoothTransport
        }
        transport?.onData = nil
        transport?.onClosed = nil
        transport?.onLog = nil
        transport?.disconnect()
        transport = newTransport
        wire(newTransport)
        addLog(.init(direction: .info, name: "Connecting", summary: address))

        let watchdog = DispatchWorkItem { [weak self] in
            guard let self, self.link == .connecting else { return }
            self.lastError = "Connection timed out. Make sure the earbuds are nearby and paired."
            self.link = .failed("Connection timed out")
            self.addLog(.init(direction: .info, name: "Timeout", summary: "No RFCOMM channel after 15 s"))
        }
        connectWatchdog?.cancel()
        connectWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: watchdog)

        newTransport.connect(address: address, preferredModel: preferred) { [weak self] result in
            guard let self, generation == self.connectionGeneration else { return }
            watchdog.cancel()
            switch result {
            case .success(let info):
                self.finishConnect(info)
            case .failure(let error):
                self.link = .failed(error.localizedDescription)
                self.lastError = error.localizedDescription
                self.addLog(.init(direction: .info, name: "Connect failed", summary: error.localizedDescription))
            }
        }
    }

    public func connectDemo() {
        connectWatchdog?.cancel()
        connectionGeneration += 1
        transport?.onData = nil
        transport?.onClosed = nil
        transport?.onLog = nil
        transport?.disconnect()
        transport = nil
        link = .idle
        pendingConnectAddress = nil
        connect(address: "DE:MO:00:00:00:01", demo: true, modelOverride: DeviceCatalog.model(for: .buds3Pro))
    }

    public func disconnect() {
        let wasDemo = isDemo
        userDisconnected = true
        connectionGeneration += 1
        connectWatchdog?.cancel()
        transport?.onData = nil
        transport?.onClosed = nil
        transport?.onLog = nil
        transport?.disconnect()
        transport = nil
        link = .idle
        findMyBudsActive = false
        pendingConnectAddress = nil
        if wasDemo {
            isDemo = false
            address = nil
            deviceName = "Galaxy Buds"
        }
        addLog(.init(direction: .info, name: "Disconnected"))
    }

    /// Selects the buds as the Mac's default output and opens a short silent
    /// A2DP stream, which makes the firmware take audio focus from the phone.
    @discardableResult
    public func claimMacAudio() -> Bool {
        guard link == .connected else { return false }
        let name = deviceName.isEmpty ? (model?.displayName ?? "Buds") : deviceName
        let ok = MacAudioRouter.claim(address: address, deviceName: name)
        addLog(.init(direction: .info, name: ok ? "Audio claimed" : "Audio claim failed",
                     summary: ok ? name : "No matching output device"))
        return ok
    }

    public func reconnect() {
        if isDemo {
            connectDemo()
            return
        }
        guard let target = address ?? store.lastAddress else { return }
        connect(address: target)
    }

    private func finishConnect(_ info: ConnectedDevice) {
        address = info.address
        deviceName = info.name
        serviceName = info.serviceName
        let savedOverride = store.state(for: info.address).modelOverride.flatMap(DeviceModelID.init(rawValue:)).map(DeviceCatalog.model(for:))
        let resolved = savedOverride ?? pendingModelOverride ?? info.model
        detectedModel = info.model
        if let detected = info.model {
            store.update(for: info.address) { $0.detectedModel = detected.id.rawValue }
        }
        if let resolved {
            model = resolved
        } else if info.serviceUUID.contains("1102") {
            model = DeviceCatalog.model(for: .buds)
            detectedModel = model
        }
        pendingConnectAddress = nil
        pendingModelOverride = nil
        link = .connected
        lastError = nil
        addLog(.init(direction: .info, name: "Connected",
                      summary: "\(info.name) · \(info.serviceName)"))
        handshake()
        restoreSavedValuesIfNeeded()
        configureReconnectTimer()
        let generation = connectionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.verifyLinkAlive(generation: generation)
        }
    }

    /// A stale Samsung RFCOMM channel can report "connected" while the earbuds
    /// still hold the previous client. If nothing arrives after the handshake,
    /// drop it and let the reconnect timer try again.
    private func verifyLinkAlive(generation: Int) {
        guard generation == connectionGeneration, link == .connected, framesSinceConnect == 0 else { return }
        addLog(.init(direction: .info, name: "No response",
                     summary: "Earbuds did not answer after connect; retrying"))
        lastError = "The earbuds did not answer. Retrying…"
        transport?.disconnect()
        transport = nil
        link = .failed("No response from earbuds")
    }

    private func wire(_ transport: BudsLink) {
        transport.onData = { [weak self] bytes in self?.receive(bytes) }
        transport.onClosed = { [weak self] reason in
            guard let self else { return }
            self.link = .idle
            self.lastError = reason
            self.findMyBudsActive = false
            self.addLog(.init(direction: .info, name: "Connection closed", summary: reason))
        }
        transport.onLog = { [weak self] message in
            self?.addLog(.init(direction: .info, name: "Bluetooth", summary: message))
        }
    }

    private func handshake() {
        guard !didHandshake else { return }
        didHandshake = true
        send(Commands.managerInfo())
        send(Commands.updateTime())
        send(Commands.debugSKU())
        send(Commands.versionInfo())
        send(Commands.multipoint())
        if has(.customEqualizer) { send(Commands.customEQQuery()) }
        if has(.batteryType) { send(Commands.batteryType()) }
    }

    private func restoreSavedValuesIfNeeded() {
        guard rememberSettings, !didApplySaved, sawStatusSinceConnect,
              link == .connected, model != nil, let address else { return }
        let saved = store.state(for: address)
        if let raw = saved.noiseMode, let mode = NoiseMode(rawValue: raw), mode != noiseMode, availableNoiseModes.contains(mode) {
            setNoiseMode(mode, persist: false)
        }
        if let high = saved.ancLevelHigh, high != ancLevelHigh, has(.ancLevel) {
            setANCLevelHigh(high, persist: false)
        }
        if let volume = saved.ambientVolume, volume != ambientVolume, has(.ambientVolume) {
            setAmbientVolume(volume, persist: false)
        }
        if saved.eqEnabled == true, saved.eqPreset == Self.customPresetIndex,
           has(.customEqualizer), let bands = saved.customEQBands, bands.count == 9 {
            // Re-push the custom table first; never send a built-in preset in
            // between, which would be briefly audible.
            send(Commands.customEqualizer(bands: bands))
            send(Commands.equalizer(enabled: true, preset: Self.customPresetIndex))
            customEQBands = bands
            eqSelection = .custom
        } else if let enabled = saved.eqEnabled {
            if enabled, let preset = saved.eqPreset, preset != Self.customPresetIndex {
                selectEQPreset(preset, persist: false)
            } else if !enabled {
                setEQOff(persist: false)
            }
        }
        didApplySaved = true
    }

    /// Clears the per-device snapshot at a session boundary so a new model never
    /// inherits the previous earbuds' battery, gestures or metadata.
    private func resetSessionState() {
        leftBattery = nil; rightBattery = nil; caseBattery = nil
        placementLeft = .disconnected; placementRight = .disconnected
        wearState = .none; coupled = false
        noiseMode = nil; ancLevelHigh = false; ambientVolume = 0
        ambientCustomEnabled = false; ambientCustomLeft = 0; ambientCustomRight = 0; ambientTone = 0
        sidetone = false; extraHighAmbient = false
        detectConversations = false; detectConversationsDuration = 1; ancWithOneEarbud = true
        adaptiveVolume = false; sirenDetect = false; autoPause = true; speakSeamlessly = false
        seamlessConnection = true; spatialAudio = false; headTracking = false; gameMode = false
        eqSelection = .off; customEQBands = Array(repeating: 0, count: 9); customEQBandsFromDevice = false
        hotCommandEnabled = false; hotCommandLanguage = 0; hotCommandVersion = nil
        lightingStyle = 0; quickLaunch = 0; revision = 0
        touchLocked = false; touchSingleTap = true; touchDoubleTap = true; touchTripleTap = true
        touchHold = true; touchDoubleTapDuringCall = true; touchHoldDuringCall = true
        touchSwipe = false; doubleTapVolume = false
        touchLeftAction = .noiseControl; touchRightAction = .noiseControl
        cycleBitsLeft = 0; cycleBitsRight = 0
        findMyBudsActive = false; multipoint = nil; fitResult = nil; batteryType = nil
        deviceInfo = DeviceInfo()
        model = nil; detectedModel = nil; serviceName = ""
    }

    private func configureReconnectTimer() {
        reconnectTimer?.invalidate()
        guard autoReconnect else { return }
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reconnectTick() }
        }
    }

    private func reconnectTick() {
        guard autoReconnect, !userDisconnected, !isDemo else { return }
        if let io = transport as? IOBluetoothTransport, io.isBusy { return }
        switch link {
        case .idle, .failed: break
        case .connecting, .connected: return
        }
        guard let address = store.lastAddress else { return }
        connect(address: address)
    }

    // MARK: Frame handling

    private func receive(_ bytes: [UInt8]) {
        lastPacketAt = Date()
        frameBuffer.append(contentsOf: bytes)
        let style: FrameStyle = model?.frameStyle
            ?? (bytes.contains(0xFE) && !bytes.contains(0xFD) ? .legacy : .modern)
        let frames = SPPCodec.extractFrames(from: &frameBuffer, style: style)
        if !frames.isEmpty { framesSinceConnect += frames.count }
        for frame in frames { handle(frame) }
    }

    private func handle(_ frame: SPPFrame) {
        packetCount += 1
        addLog(.init(direction: .received, name: MsgID.name(frame.id), hex: frame.raw.hexString,
                     summary: summary(for: frame)))

        switch frame.id {
        case MsgID.extendedStatusUpdated, MsgID.statusUpdated:
            if let state = StatusParser.parse(frame: frame, model: model ?? DeviceCatalog.model(for: .buds3Pro)) {
                sawStatusSinceConnect = true
                apply(state)
                if !didHandshake { handshake() }
                restoreSavedValuesIfNeeded()
            }
        case MsgID.acknowledgement:
            if let ack = PayloadParser.parseAcknowledgement(frame.payload) { apply(ack) }
        case MsgID.debugSKU:
            let sku = PayloadParser.parseSKU(frame.payload)
            deviceInfo.skuLeft = sku.left
            deviceInfo.skuRight = sku.right
            if let text = sku.left, let detected = DeviceCatalog.model(skuOrFirmware: text) {
                detectedModel = detected
                if let address { store.update(for: address) { $0.detectedModel = detected.id.rawValue } }
                let override = store.state(for: address ?? "").modelOverride.flatMap(DeviceModelID.init(rawValue:)).map(DeviceCatalog.model(for:))
                if override == nil { model = detected }
                restoreSavedValuesIfNeeded()
            }
        case MsgID.versionInfo:
            let version = PayloadParser.parseVersionInfo(frame.payload)
            deviceInfo.firmwareLeft = version.left
            deviceInfo.firmwareRight = version.right
            if detectedModel == nil, let text = version.left, let detected = DeviceCatalog.model(skuOrFirmware: text) {
                detectedModel = detected
                if let address { store.update(for: address) { $0.detectedModel = detected.id.rawValue } }
                if store.state(for: address ?? "").modelOverride == nil { model = detected }
            }
        case MsgID.versionInfoLong:
            if frame.payload.count >= 30 {
                func str(_ range: Range<Int>) -> String? {
                    let bytes = Array(frame.payload[range]).prefix { $0 != 0 }
                    let text = String(bytes: bytes, encoding: .utf8) ?? ""
                    return text.isEmpty ? nil : text
                }
                deviceInfo.firmwareLeft = str(2..<16)
                deviceInfo.firmwareRight = str(16..<30)
                if detectedModel == nil, let text = deviceInfo.firmwareLeft, let detected = DeviceCatalog.model(skuOrFirmware: text) {
                    detectedModel = detected
                    if let address { store.update(for: address) { $0.detectedModel = detected.id.rawValue } }
                    if store.state(for: address ?? "").modelOverride == nil { model = detected }
                }
            }
        case MsgID.cradleSerialNumber:
            let text = PayloadParser.parseBuildInfo(frame.payload)
            if let text {
                if text.contains(".") {
                    deviceInfo.build = text
                } else {
                    deviceInfo.cradleSerial = text
                }
            }
        case MsgID.debugBuildInfo, MsgID.debugSerialNumber:
            if let text = PayloadParser.parseBuildInfo(frame.payload) {
                if frame.id == MsgID.debugSerialNumber {
                    deviceInfo.serialLeft = text
                } else {
                    deviceInfo.build = text
                }
            }
        case MsgID.customEqualizerRecv:
            if let data = PayloadParser.parseCustomEQ(frame.payload) {
                customEQBands = data.bands
                customEQBandsFromDevice = true
            }
        case MsgID.multipointInfo:
            multipoint = PayloadParser.parseMultipoint(frame.payload)
        case MsgID.fitResult:
            fitResult = PayloadParser.parseFitResult(frame.payload)
        case MsgID.findMyEarbudsStop:
            findMyBudsActive = false
        case MsgID.batteryType:
            batteryType = PayloadParser.parseBatteryType(frame.payload)
        case MsgID.noiseControlsUpdate:
            if let value = frame.payload.first, let mode = NoiseMode(rawValue: Int(value)) {
                noiseMode = mode
            }
        case MsgID.setAmbientMode, MsgID.ambientModeUpdated:
            if let value = frame.payload.first {
                noiseMode = value != 0 ? .ambient : .off
            }
        case MsgID.setNoiseReduction:
            if let value = frame.payload.first {
                noiseMode = value != 0 ? .anc : .off
            }
        default:
            break
        }
    }

    private func summary(for frame: SPPFrame) -> String {
        switch frame.id {
        case MsgID.extendedStatusUpdated, MsgID.statusUpdated:
            let state = StatusParser.parse(frame: frame, model: model ?? DeviceCatalog.model(for: .buds3Pro))
            if let l = state?.batteryLeft, let r = state?.batteryRight {
                return "L \(l)% · R \(r)% · rev \(state?.revision ?? 0)"
            }
        case MsgID.acknowledgement:
            if let ack = PayloadParser.parseAcknowledgement(frame.payload) {
                return "\(MsgID.name(ack.command)) \(ack.payload.map { String(format: "%02x", $0) }.joined(separator: " "))"
            }
        case MsgID.debugSKU:
            return PayloadParser.parseSKU(frame.payload).left ?? ""
        case MsgID.versionInfoLong:
            return PayloadParser.parseVersionInfo(frame.payload).left ?? ""
        case MsgID.customEqualizerRecv:
            if let data = PayloadParser.parseCustomEQ(frame.payload) {
                return "\(data.presetCount) presets · \(data.bandCount) bands"
            }
        default:
            break
        }
        return frame.payload.isEmpty ? "" : "\(frame.payload.count) bytes"
    }

    private func apply(_ state: BudsState) {
        revision = state.revision
        coupled = state.isCoupled
        if let level = state.batteryLeft { leftBattery = BatteryLevel(level: level, charging: state.leftCharging ?? leftBattery?.charging ?? false) }
        if let level = state.batteryRight { rightBattery = BatteryLevel(level: level, charging: state.rightCharging ?? rightBattery?.charging ?? false) }
        if let level = state.caseBattery, level <= 100, model?.supports(.caseBattery) == true {
            caseBattery = BatteryLevel(level: level, charging: state.caseCharging ?? caseBattery?.charging ?? false)
        }
        placementLeft = state.placementLeft
        placementRight = state.placementRight
        wearState = state.wearState

        if let mode = state.noiseMode {
            noiseMode = mode
        } else if let cancelling = state.noiseCancelling {
            noiseMode = cancelling ? .anc : .off
        } else if let ambient = state.ambientEnabled {
            noiseMode = ambient ? .ambient : .off
        }
        if let high = state.ancLevel { ancLevelHigh = high != 0 }
        if let volume = state.ambientVolume { ambientVolume = min(volume, model?.ambientVolumeMax ?? volume) }
        if let value = state.ambientCustomEnabled { ambientCustomEnabled = value }
        if let value = state.ambientCustomLeft { ambientCustomLeft = value }
        if let value = state.ambientCustomRight { ambientCustomRight = value }
        if let value = state.ambientTone { ambientTone = value }
        if let value = state.sidetone { sidetone = value }
        if let value = state.extraHighAmbient { extraHighAmbient = value }
        if let value = state.detectConversations { detectConversations = value }
        if let value = state.detectConversationsDuration { detectConversationsDuration = value }
        if let value = state.ancWithOneEarbud { ancWithOneEarbud = value }
        if let value = state.adaptiveVolume { adaptiveVolume = value }
        if let value = state.sirenDetect { sirenDetect = value }
        if let value = state.autoPause { autoPause = value }
        if let value = state.speakSeamlessly { speakSeamlessly = value }
        if let value = state.seamlessConnection { seamlessConnection = value }
        if let value = state.spatialAudio { spatialAudio = value }
        if let value = state.headTracking { headTracking = value }
        if let value = state.gameMode { gameMode = value }
        if let value = state.hotCommandEnabled { hotCommandEnabled = value }
        if let value = state.hotCommandLanguage { hotCommandLanguage = value }
        if let value = state.hotCommandVersion { hotCommandVersion = value }
        if let value = state.lighting { lightingStyle = value }
        if let value = state.quickLaunch { quickLaunch = value }

        if let raw = state.equalizerMode {
            switch raw {
            case 0: eqSelection = .off
            case 1...5: eqSelection = .preset(raw - 1)
            default: eqSelection = .custom
            }
        } else if let enabled = state.equalizerEnabled {
            eqSelection = enabled ? .preset(state.equalizerPreset ?? 0) : .off
        }

        if let value = state.touchpad.locked { touchLocked = value }
        if let value = state.touchpad.singleTap { touchSingleTap = value }
        if let value = state.touchpad.doubleTap { touchDoubleTap = value }
        if let value = state.touchpad.tripleTap { touchTripleTap = value }
        if let value = state.touchpad.hold { touchHold = value }
        if let value = state.touchpad.doubleTapDuringCall { touchDoubleTapDuringCall = value }
        if let value = state.touchpad.holdDuringCall { touchHoldDuringCall = value }
        if let value = state.touchpad.swipe { touchSwipe = value }
        if let value = state.touchpad.doubleTapVolume { doubleTapVolume = value }
        if let left = state.touchpad.leftActionRaw, let action = action(forRaw: left) { touchLeftAction = action }
        if let right = state.touchpad.rightActionRaw, let action = action(forRaw: right) { touchRightAction = action }
        if let bits = state.touchpad.cycleBitsLeft { cycleBitsLeft = bits }
        if let bits = state.touchpad.cycleBitsRight { cycleBitsRight = bits }
    }

    private func action(forRaw raw: UInt8) -> TouchAction? {
        guard let model else { return nil }
        return model.touchMap.first { $0.value == raw }?.key
    }

    private func apply(_ ack: Acknowledgement) {
        guard let value = ack.payload.first else { return }
        switch ack.command {
        case MsgID.noiseControls:
            if let mode = NoiseMode(rawValue: Int(value)) { noiseMode = mode }
        case MsgID.setAmbientMode:
            noiseMode = value != 0 ? .ambient : .off
        case MsgID.setNoiseReduction:
            noiseMode = value != 0 ? .anc : .off
        case MsgID.noiseReductionLevel:
            ancLevelHigh = value != 0
        case MsgID.ambientVolume:
            ambientVolume = Int(value)
        case MsgID.equalizer:
            if value == 0 {
                eqSelection = .off
            } else if value <= 5 {
                eqSelection = .preset(Int(value) - 1)
            } else {
                eqSelection = .custom
            }
        case MsgID.setSidetone:
            sidetone = value != 0
        case MsgID.extraHighAmbient:
            extraHighAmbient = value != 0
        case MsgID.setDetectConversations:
            detectConversations = value != 0
        case MsgID.setDetectConversationsDuration:
            detectConversationsDuration = Int(value)
        case MsgID.setAncWithOneEarbud:
            ancWithOneEarbud = value != 0
        case MsgID.adaptiveEQVolume:
            adaptiveVolume = value != 0
        case MsgID.sirenDetect:
            sirenDetect = value != 0
        case MsgID.pauseMediaWhenOneBudRemoved:
            autoPause = value != 0
        case MsgID.setSpeakSeamlessly:
            speakSeamlessly = value != 0
        case MsgID.outsideDoubleTap:
            doubleTapVolume = value != 0
        case MsgID.setSeamlessConnection:
            seamlessConnection = value != 0
        case MsgID.findMyEarbudsStart, MsgID.findMyEarbudsOnWearingStart:
            findMyBudsActive = true
        case MsgID.findMyEarbudsStop:
            findMyBudsActive = false
        case MsgID.setTouchpadOption:
            if ack.payload.count >= 2 {
                if let left = action(forRaw: ack.payload[0]) { touchLeftAction = left }
                if let right = action(forRaw: ack.payload[1]) { touchRightAction = right }
            }
        default:
            break
        }
    }

    // MARK: Sending

    private func send(_ frame: SPPFrame, log: Bool = true) {
        guard let bytes = SPPCodec.encode(id: frame.id, payload: frame.payload, style: frameStyle) else {
            addLog(.init(direction: .info, name: "Frame too large",
                         summary: "\(frame.payload.count) bytes exceeds the \(frameStyle.rawValue) limit"))
            return
        }
        if log {
            addLog(.init(direction: .sent, name: MsgID.name(frame.id), hex: bytes.hexString,
                         summary: frame.payload.isEmpty ? "" : "\(frame.payload.count) bytes"))
        }
        transport?.send(bytes) { [weak self] error in
            guard let error else { return }
            self?.addLog(.init(direction: .info, name: "Send error", summary: error.localizedDescription))
        }
    }

    public func sendRaw(id: UInt8, payload: [UInt8]) {
        send(SPPFrame(id: id, payload: payload))
    }

    public func refresh() {
        send(Commands.debugSKU())
        send(Commands.versionInfo())
        send(Commands.multipoint())
        if has(.customEqualizer) { send(Commands.customEQQuery()) }
    }

    // MARK: Noise control

    public func setNoiseMode(_ mode: NoiseMode, persist: Bool = true) {
        guard model != nil else { return }
        guard mode == .off || availableNoiseModes.contains(mode) else { return }
        if has(.noiseControl) {
            send(Commands.noiseMode(mode))
        } else if mode == .ambient {
            send(Commands.legacyAmbient(true))
        } else if mode == .anc {
            send(Commands.legacyANC(true))
        } else {
            if has(.ambientSound) { send(Commands.legacyAmbient(false)) }
            if has(.ancLevel) || model?.id == .budsLive { send(Commands.legacyANC(false)) }
        }
        noiseMode = mode
        if persist {
            store.update(for: address ?? "") { $0.noiseMode = mode.rawValue }
        }
    }

    public func toggleNoiseCancellation() {
        guard let mode = noiseMode else { return }
        if mode == .anc {
            setNoiseMode(.off)
        } else if availableNoiseModes.contains(.anc) {
            setNoiseMode(.anc)
        }
    }

    public func cycleNoiseMode() {
        let modes = availableNoiseModes
        guard !modes.isEmpty else { return }
        let current = noiseMode ?? modes[0]
        let index = modes.firstIndex(of: current) ?? 0
        setNoiseMode(modes[(index + 1) % modes.count])
    }

    public func setANCLevelHigh(_ high: Bool, persist: Bool = true) {
        guard has(.ancLevel) else { return }
        send(Commands.ancLevel(high))
        ancLevelHigh = high
        if persist { store.update(for: address ?? "") { $0.ancLevelHigh = high } }
    }

    public func setAmbientVolume(_ value: Int, persist: Bool = true) {
        guard has(.ambientVolume), let model else { return }
        let clamped = max(0, min(model.ambientVolumeMax, value))
        send(Commands.ambientVolume(clamped))
        ambientVolume = clamped
        if persist { store.update(for: address ?? "") { $0.ambientVolume = clamped } }
    }

    public func setAmbientCustom(enabled: Bool, left: Int? = nil, right: Int? = nil, tone: Int? = nil) {
        guard has(.ambientCustomize) else { return }
        let l = left ?? ambientCustomLeft
        let r = right ?? ambientCustomRight
        let t = tone ?? ambientTone
        send(Commands.customAmbient(enabled: enabled, left: l, right: r, tone: t))
        ambientCustomEnabled = enabled
        ambientCustomLeft = l
        ambientCustomRight = r
        ambientTone = t
        store.update(for: address ?? "") {
            $0.ambientCustomEnabled = enabled
            $0.ambientCustomLeft = l
            $0.ambientCustomRight = r
            $0.ambientTone = t
        }
    }

    public func setSidetone(_ enabled: Bool) {
        guard has(.sidetone) else { return }
        send(Commands.sidetone(enabled))
        sidetone = enabled
        store.update(for: address ?? "") { $0.sidetone = enabled }
    }

    public func setExtraHighAmbient(_ enabled: Bool) {
        guard has(.extraHighAmbient) else { return }
        send(Commands.extraHighAmbient(enabled))
        extraHighAmbient = enabled
        store.update(for: address ?? "") { $0.extraHighAmbient = enabled }
    }

    public func setDetectConversations(_ enabled: Bool) {
        guard has(.detectConversations) else { return }
        send(Commands.detectConversations(enabled))
        detectConversations = enabled
        store.update(for: address ?? "") { $0.detectConversations = enabled }
    }

    public func setDetectConversationsDuration(_ index: Int) {
        guard has(.detectConversations) else { return }
        let clamped = max(0, min(2, index))
        send(Commands.detectConversationsDuration(clamped))
        detectConversationsDuration = clamped
    }

    public func setANCWithOneEarbud(_ enabled: Bool) {
        guard has(.ancWithOneEarbud) else { return }
        send(Commands.ancWithOneEarbud(enabled))
        ancWithOneEarbud = enabled
        store.update(for: address ?? "") { $0.ancWithOneEarbud = enabled }
    }

    public func setAdaptiveVolume(_ enabled: Bool) {
        guard has(.adaptiveVolume) else { return }
        send(Commands.adaptiveVolume(enabled))
        adaptiveVolume = enabled
        store.update(for: address ?? "") { $0.adaptiveVolume = enabled }
    }

    public func setSirenDetect(_ enabled: Bool) {
        guard has(.sirenDetect) else { return }
        send(Commands.sirenDetect(enabled))
        sirenDetect = enabled
        store.update(for: address ?? "") { $0.sirenDetect = enabled }
    }

    public func setAutoPause(_ enabled: Bool) {
        guard has(.autoPause) else { return }
        send(Commands.autoPause(enabled))
        autoPause = enabled
        store.update(for: address ?? "") { $0.autoPause = enabled }
    }

    public func setSpeakSeamlessly(_ enabled: Bool) {
        guard has(.speakSeamlessly) else { return }
        send(Commands.speakSeamlessly(enabled))
        speakSeamlessly = enabled
    }

    public func setSeamlessConnection(_ enabled: Bool) {
        guard has(.seamlessConnection) else { return }
        send(Commands.seamlessConnection(enabled))
        seamlessConnection = enabled
        store.update(for: address ?? "") { $0.seamlessConnection = enabled }
    }

    // MARK: Equalizer

    public func setEQOff(persist: Bool = true) {
        guard has(.equalizer) else { return }
        send(model?.id == .buds ? Commands.legacyEqualizer(enabled: false, preset: 0)
                                : Commands.equalizer(enabled: false, preset: 0))
        eqSelection = .off
        if persist { store.update(for: address ?? "") { $0.eqEnabled = false; $0.eqPreset = 0 } }
    }

    public func selectEQPreset(_ index: Int, persist: Bool = true) {
        guard has(.equalizer) else { return }
        let preset = max(0, min(4, index))
        send(model?.id == .buds ? Commands.legacyEqualizer(enabled: true, preset: preset)
                                : Commands.equalizer(enabled: true, preset: preset))
        eqSelection = .preset(preset)
        if persist { store.update(for: address ?? "") { $0.eqEnabled = true; $0.eqPreset = preset } }
    }

    public func applyCustomEQ(bands: [Int], persist: Bool = true) {
        guard has(.customEqualizer) else { return }
        var values = bands
        if values.count != 9 { values = Array(values.prefix(9)) + Array(repeating: 0, count: max(0, 9 - values.count)) }
        values = values.map { max(-10, min(10, $0)) }
        send(Commands.customEqualizer(bands: values))
        send(Commands.equalizer(enabled: true, preset: Self.customPresetIndex))
        customEQBands = values
        eqSelection = .custom
        if persist {
            store.update(for: address ?? "") {
                $0.eqEnabled = true
                $0.eqPreset = Self.customPresetIndex
                $0.customEQBands = values
            }
        }
    }

    public func updateCustomEQBands(_ bands: [Int]) {
        var values = bands
        if values.count != 9 { values = Array(values.prefix(9)) + Array(repeating: 0, count: max(0, 9 - values.count)) }
        customEQBands = values.map { max(-10, min(10, $0)) }
    }

    // MARK: Touch

    public func setTouchpadLocked(_ locked: Bool) {
        guard has(.touchLock) else { return }
        touchLocked = locked
        sendTouchConfiguration()
        store.update(for: address ?? "") { $0.touchpadLocked = locked }
    }

    public func setTouchGesture(single: Bool? = nil, double: Bool? = nil, triple: Bool? = nil,
                                hold: Bool? = nil, swipe: Bool? = nil,
                                doubleDuringCall: Bool? = nil, holdDuringCall: Bool? = nil) {
        if let single { touchSingleTap = single }
        if let double { touchDoubleTap = double }
        if let triple { touchTripleTap = triple }
        if let hold { touchHold = hold }
        if let swipe { touchSwipe = swipe }
        if let doubleDuringCall { touchDoubleTapDuringCall = doubleDuringCall }
        if let holdDuringCall { touchHoldDuringCall = holdDuringCall }
        sendTouchConfiguration()
        store.update(for: address ?? "") {
            $0.touchSingle = self.touchSingleTap
            $0.touchDouble = self.touchDoubleTap
            $0.touchTriple = self.touchTripleTap
            $0.touchHold = self.touchHold
            $0.touchSwipe = self.touchSwipe
            $0.touchDoubleDuringCall = self.touchDoubleTapDuringCall
            $0.touchHoldDuringCall = self.touchHoldDuringCall
        }
    }

    public func setTouchAction(_ action: TouchAction, left: Bool) {
        guard let raw = model?.touchMap[action] else { return }
        let leftRaw = left ? raw : (model?.touchMap[touchLeftAction] ?? 2)
        let rightRaw = left ? (model?.touchMap[touchRightAction] ?? 2) : raw
        send(Commands.touchOptions(left: leftRaw, right: rightRaw))
        if left { touchLeftAction = action } else { touchRightAction = action }
    }

    public func setDoubleTapVolume(_ enabled: Bool) {
        guard has(.doubleTapVolume) else { return }
        send(Commands.doubleTapVolume(enabled))
        doubleTapVolume = enabled
        store.update(for: address ?? "") { $0.doubleTapVolume = enabled }
    }

    public func setNoiseCycle(left: UInt8, right: UInt8) {
        guard has(.noiseControlCycle) else { return }
        send(Commands.noiseControlCycle(bitsLeft: left, bitsRight: right))
        cycleBitsLeft = left
        cycleBitsRight = right
    }

    private func sendTouchConfiguration() {
        guard let model else { return }
        if has(.advancedTouch) {
            if model.id == .buds4 || model.id == .buds4Pro {
                // Buds4 uses a different 12-byte layout; encode it explicitly.
                let payload: [UInt8] = [
                    0, touchLocked ? 0 : 1,
                    touchSingleTap ? 1 : 0,
                    touchDoubleTap ? 1 : 0,
                    touchTripleTap ? 1 : 0,
                    touchHold ? 1 : 0,
                    touchDoubleTapDuringCall ? 1 : 0,
                    touchHoldDuringCall ? 1 : 0,
                    touchSwipe ? 1 : 0,
                    touchDoubleTapDuringCall ? 1 : 0,
                    UInt8(clamping: lightingStyle),
                    UInt8(clamping: quickLaunch)
                ]
                send(SPPFrame(id: MsgID.lockTouchpad, payload: payload))
            } else {
                var payload: [UInt8] = [
                    touchLocked ? 0 : 1,
                    touchSingleTap ? 1 : 0,
                    touchDoubleTap ? 1 : 0,
                    touchTripleTap ? 1 : 0,
                    touchHold ? 1 : 0
                ]
                if has(.callGestures) {
                    payload.append(touchDoubleTapDuringCall ? 1 : 0)
                    payload.append(touchHoldDuringCall ? 1 : 0)
                }
                send(SPPFrame(id: MsgID.lockTouchpad, payload: payload))
            }
        } else {
            send(Commands.lockTouchpad(locked: touchLocked))
        }
    }

    // MARK: Find, fit, extras

    public func setFindMyBuds(active: Bool) {
        guard has(.findMyBuds) else { return }
        if active {
            if has(.findWhileWearing), placementLeft == .wearing || placementRight == .wearing {
                send(Commands.findMyEarbudsWhileWearing(active: true))
            } else {
                send(Commands.findMyEarbuds(active: true))
            }
        } else {
            send(Commands.findMyEarbuds(active: false))
        }
        findMyBudsActive = active
    }

    public func runFitTest() {
        guard has(.fitTest) else { return }
        fitTestGeneration += 1
        let generation = fitTestGeneration
        let connection = connectionGeneration
        fitResult = nil
        send(Commands.fitTest(true))
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, generation == self.fitTestGeneration,
                  connection == self.connectionGeneration, self.link == .connected else { return }
            self.send(Commands.fitTest(false))
        }
    }

    public func setSpatialAudio(_ enabled: Bool) {
        guard has(.spatialAudio) else { return }
        send(Commands.spatialAudio(enabled))
        spatialAudio = enabled
    }

    public func setHeadTracking(_ enabled: Bool) {
        guard has(.headTracking) else { return }
        send(Commands.headTracking(enabled))
        headTracking = enabled
    }

    public func setGameMode(_ enabled: Bool) {
        send(Commands.gameMode(enabled))
        gameMode = enabled
    }

    public func setModelOverride(_ id: DeviceModelID?) {
        guard let address else { return }
        store.update(for: address) { $0.modelOverride = id?.rawValue }
        if let id {
            model = DeviceCatalog.model(for: id)
        } else {
            model = detectedModel
        }
        didHandshake = false
        handshake()
        didApplySaved = false
        restoreSavedValuesIfNeeded()
    }

    public func forgetDevice() {
        guard let address else { return }
        store.forget(address: address)
        disconnect()
        self.address = nil
        deviceName = "Galaxy Buds"
    }

    // MARK: Logging

    private func addLog(_ entry: PacketLogEntry) {
        packetLog.append(entry)
        if packetLog.count > 500 { packetLog.removeFirst(packetLog.count - 500) }
    }

    public func clearLog() { packetLog.removeAll() }

    public func copyLog() -> String {
        packetLog.map {
            var line = "\($0.date.formatted(date: .omitted, time: .standard)) \($0.direction.rawValue) \($0.name) \($0.summary)"
            if !$0.hex.isEmpty { line += "\n    \($0.hex)" }
            return line
        }.joined(separator: "\n")
    }
}
