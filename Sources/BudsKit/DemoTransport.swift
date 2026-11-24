import Foundation

/// A self-contained Galaxy Buds3 Pro simulation for previews, tests and
/// running the UI without hardware.
public final class DemoTransport: BudsLink {
    public var onData: (([UInt8]) -> Void)?
    public var onClosed: ((String) -> Void)?
    public var onLog: ((String) -> Void)?

    private var buffer = [UInt8]()
    private var started = false
    private var findActive = false

    public init() {}

    public func connect(address: String, preferredModel: DeviceModel?, completion: @escaping (Result<ConnectedDevice, Error>) -> Void) {
        let info = ConnectedDevice(
            address: "DE:MO:00:00:00:01",
            name: "Galaxy Buds3 Pro (Demo)",
            model: DeviceCatalog.model(for: .buds3Pro),
            serviceName: "GEARMANAGER",
            serviceUUID: "2e73a4ad-332d-41fc-90e2-16bef06523f2"
        )
        DispatchQueue.main.async { completion(.success(info)) }
    }

    public func send(_ bytes: [UInt8], completion: ((Error?) -> Void)?) {
        buffer.append(contentsOf: bytes)
        while let frame = SPPCodec.extractFrames(from: &buffer, style: .modern).first {
            handle(frame)
        }
        DispatchQueue.main.async { completion?(nil) }
    }

    public func disconnect() {
        started = false
    }

    private func handle(_ frame: SPPFrame) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            if !self.started { self.startSession() }
            switch frame.id {
            case MsgID.managerInfo, MsgID.updateTime:
                self.emit(id: MsgID.acknowledgement, payload: [frame.id])
            case MsgID.debugSKU:
                self.emit(id: MsgID.debugSKU, payload: Array("SM-R630NZA AINU".utf8) + Array("SM-R630NZA AINU".utf8))
            case MsgID.versionInfo:
                self.emitVersionLong()
            case MsgID.customEqualizerRecv:
                self.emitCustomEQ()
            case MsgID.noiseControls, MsgID.noiseReductionLevel, MsgID.ambientVolume,
                 MsgID.setDetectConversations, MsgID.setSidetone, MsgID.setAncWithOneEarbud,
                 MsgID.outsideDoubleTap, MsgID.extraHighAmbient, MsgID.adaptiveEQVolume,
                 MsgID.sirenDetect, MsgID.pauseMediaWhenOneBudRemoved, MsgID.setSpeakSeamlessly,
                 MsgID.customizeAmbient, MsgID.equalizer, MsgID.setSpatialAudio:
                self.emit(id: MsgID.acknowledgement, payload: [frame.id] + frame.payload)
            case MsgID.findMyEarbudsStart, MsgID.findMyEarbudsOnWearingStart:
                self.findActive = true
                self.emit(id: MsgID.acknowledgement, payload: [frame.id])
            case MsgID.findMyEarbudsStop:
                self.findActive = false
                self.emit(id: MsgID.acknowledgement, payload: [frame.id])
            case MsgID.checkFit:
                self.emit(id: MsgID.fitResult, payload: [1, 1])
            case MsgID.multipointInfo:
                self.emit(id: MsgID.multipointInfo, payload: [1, 1, 0, 0, 1])
            default:
                break
            }
        }
    }

    private func startSession() {
        guard !started else { return }
        started = true
        onLog?("Demo: session started")
        emitExtendedStatus()
        emitVersionLong()
        emit(id: MsgID.debugSKU, payload: Array("SM-R630NZA AINU".utf8) + Array("SM-R630NZA AINU".utf8))
        emit(id: MsgID.lightingSync, payload: [0])
        emit(id: MsgID.multipointInfo, payload: [1, 1, 0, 0, 1])
        emitCustomEQ()
    }

    private func emit(id: UInt8, payload: [UInt8]) {
        let frame = SPPCodec.encode(id: id, payload: payload, style: .modern, response: true)
        onData?(frame)
    }

    private func emitVersionLong() {
        func pad(_ s: String) -> [UInt8] {
            var bytes = Array(s.utf8)
            if bytes.count > 14 { bytes = Array(bytes.prefix(14)) }
            while bytes.count < 14 { bytes.append(0) }
            return bytes
        }
        emit(id: MsgID.versionInfoLong, payload: [2, 2] + pad("R630XXU0AZG2") + pad("R630XXU0AZG2"))
    }

    private func emitCustomEQ() {
        let bands: [Int8] = [5, 4, 3, 1, 0, 0, 1, 2, 2]
        let presets: [[Int8]] = [
            [5, 4, 1, 0, 0, 0, 1, 3, 4],
            [-2, -1, 0, 0, 0, 0, 0, 1, 2],
            [3, 3, 0, -1, -1, 0, 1, 2, 2],
            [-5, -4, -3, -1, 0, 0, 0, 1, 1],
            [2, 1, 0, 0, 0, 0, 0, -1, -1]
        ]
        var payload: [UInt8] = [6, 9]
        for preset in presets { payload.append(contentsOf: preset.map { UInt8(bitPattern: $0) }) }
        payload.append(contentsOf: bands.map { UInt8(bitPattern: $0) })
        emit(id: MsgID.customEqualizerRecv, payload: payload)
    }

    private func emitExtendedStatus() {
        let payload: [UInt8] = [
            4, 8, 82, 84, 1, 0, 0x11, 96, 0, 3, 0xFF, 0x52,
            1, 0, 0x54, 0x01, 0x54, 0x01, 2, 0, 4, 0x99, 0, 4,
            1, 0x10, 1, 1, 1, 0, 0x11, 2, 0, 1, 0, 1, 0, 0,
            1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1,
            1, 1, 1, 0, 0, 1, 0
        ]
        emit(id: MsgID.extendedStatusUpdated, payload: payload)
    }
}
