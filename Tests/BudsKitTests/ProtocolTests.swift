import Testing
@testable import BudsKit

private func bytes(_ hex: String) -> [UInt8] {
    hex.split(separator: " ").compactMap { UInt8($0, radix: 16) }
}

@Test func goldenNoiseAmbientFrame() throws {
    let encoded = try #require(SPPCodec.encode(id: MsgID.noiseControls, payload: [2], style: .modern))
    #expect(encoded.hexString == "fd 04 00 78 02 b2 a1 dd")
}

@Test func goldenManagerInfoFrame() throws {
    let encoded = try #require(SPPCodec.encode(id: MsgID.managerInfo, payload: [1, 1, 34], style: .modern))
    #expect(encoded.hexString == "fd 06 00 88 01 01 22 da 58 dd")
}

@Test func decodesLiveExtendedStatus() {
    let raw = bytes("fd 40 00 61 04 08 30 53 01 00 11 00 00 03 ff 52 01 00 54 01 54 01 02 00 04 99 00 04 01 10 01 01 01 00 11 02 00 01 00 01 00 00 01 00 00 00 00 00 01 00 01 01 00 01 00 01 00 01 01 01 01 00 00 01 00 c0 88 dd")
    guard let frame = SPPCodec.decodeSingle(raw, style: .modern) else {
        Issue.record("frame did not decode")
        return
    }
    #expect(frame.id == MsgID.extendedStatusUpdated)
    #expect(frame.payload.count == 61)
    let model = DeviceCatalog.model(for: .buds3Pro)
    guard let state = StatusParser.parse(frame: frame, model: model) else {
        Issue.record("state did not parse")
        return
    }
    #expect(state.revision == 4)
    #expect(state.batteryLeft == 48)
    #expect(state.batteryRight == 83)
    #expect(state.caseBattery == 0)
    #expect(state.noiseMode == .anc)
    #expect(state.equalizerMode == 3)
    #expect(state.ambientVolume == 4)
    #expect(state.ancLevel == 1)
    #expect(state.deviceColorLeft == 340)
}

@Test func decodesCapturedHighBitHeaderFrame() {
    let raw = bytes("fd 06 50 c2 26 00 01 8b 7a dd")
    let frame = SPPCodec.decodeSingle(raw, style: .modern)
    #expect(frame?.id == MsgID.spatialAudioData)
    #expect(frame?.payload == [0x26, 0x00, 0x01])
}

@Test func detectsModels() {
    #expect(DeviceCatalog.model(deviceName: "My Buds3 Pro")?.id == .buds3Pro)
    #expect(DeviceCatalog.model(deviceName: "Galaxy Buds2 Pro")?.id == .buds2Pro)
    #expect(DeviceCatalog.model(deviceName: "Galaxy Buds Live")?.id == .budsLive)
    #expect(DeviceCatalog.model(deviceName: "Galaxy Buds")?.id == .buds)
    #expect(DeviceCatalog.model(skuOrFirmware: "SM-R630NZA AINU")?.id == .buds3Pro)
    #expect(DeviceCatalog.model(skuOrFirmware: "R170XXU0ATF2")?.id == .buds)
}

@Test func parsesVendorProductID() {
    // Production form: a standard 8-4-4-4-12 UUID string as produced by
    // IOBluetoothTransport.uuidString (32 hex digits without dashes).
    #expect(DeviceCatalog.productID(fromServiceUUID: "d908aab5-7a90-4cbe-8641-86a553db0154") == 340)
    #expect(DeviceCatalog.model(productID: 340)?.id == .buds3Pro)
    #expect(DeviceCatalog.model(productID: 0x154)?.id == .buds3Pro)
}

@Test func parsesSKUAndEQ() {
    let sku = PayloadParser.parseSKU(Array("SM-R630NZAAINU".utf8) + Array("SM-R630NZAAINU".utf8))
    #expect(sku.left == "SM-R630NZAAINU")
    let eq = PayloadParser.parseCustomEQ([2, 3, 1, 2, 3, 0xFF, 0xFD, 0x00])
    #expect(eq?.presetCount == 2)
    #expect(eq?.bandCount == 3)
    #expect(eq?.bands == [-1, -3, 0])
}

@Test func frameDirectionRoundTrip() throws {
    // Captured traffic: the 0x1000 bit marks device-originated frames.
    for response in [false, true] {
        let bytes = try #require(SPPCodec.encode(id: MsgID.noiseControls, payload: [2], style: .modern, response: response))
        #expect(SPPCodec.decodeSingle(bytes, style: .modern)?.direction == (response ? .response : .request))
    }
    for response in [false, true] {
        let bytes = try #require(SPPCodec.encode(id: MsgID.noiseControls, payload: [2], style: .legacy, response: response))
        #expect(SPPCodec.decodeSingle(bytes, style: .legacy)?.direction == (response ? .response : .request))
    }
}

@Test func legacyRoundTrip() throws {
    let encoded = try #require(SPPCodec.encode(id: MsgID.equalizer, payload: [1, 5], style: .legacy))
    let frame = SPPCodec.decodeSingle(encoded, style: .legacy)
    #expect(frame?.id == MsgID.equalizer)
    #expect(frame?.payload == [1, 5])
    #expect(encoded.first == 0xFE)
    #expect(encoded.last == 0xEE)
}

@Test func preservesGestureFlagsAlongsideCycleMask() {
    var payload = [UInt8](repeating: 0, count: 61)
    payload[0] = 4
    payload[10] = 0x08 // single tap only
    payload[12] = 0
    let frame = SPPFrame(id: MsgID.extendedStatusUpdated, payload: payload)
    guard let state = StatusParser.parse(frame: frame, model: DeviceCatalog.model(for: .buds3Pro)) else {
        Issue.record("state did not parse")
        return
    }
    #expect(state.touchpad.singleTap == true)
    #expect(state.touchpad.doubleTap == false)
    #expect(state.touchpad.tripleTap == false)
    #expect(state.touchpad.hold == false)
}

@Test @MainActor func demoSessionDrivesController() async throws {
    let controller = BudsController()
    controller.autoReconnect = false
    controller.rememberSettings = false
    controller.connectDemo()
    try await Task.sleep(nanoseconds: 900_000_000)
    #expect(controller.link == .connected)
    #expect(controller.model?.id == .buds3Pro)
    #expect(controller.leftBattery?.level == 82)
    #expect(controller.rightBattery?.level == 84)
    #expect(controller.noiseMode == .anc)
    #expect(controller.availableNoiseModes.contains(.adaptive) == false)
    controller.setNoiseMode(.ambient)
    #expect(controller.noiseMode == .ambient)
    controller.setANCLevelHigh(false)
    #expect(controller.ancLevelHigh == false)
    controller.disconnect()
}


@Test func frameSizeLimits() {
    #expect(SPPCodec.encode(id: 1, payload: [UInt8](repeating: 0, count: 1020), style: .modern) != nil)
    #expect(SPPCodec.encode(id: 1, payload: [UInt8](repeating: 0, count: 1021), style: .modern) == nil)
    #expect(SPPCodec.encode(id: 1, payload: [UInt8](repeating: 0, count: 252), style: .legacy) != nil)
    #expect(SPPCodec.encode(id: 1, payload: [UInt8](repeating: 0, count: 253), style: .legacy) == nil)
}
