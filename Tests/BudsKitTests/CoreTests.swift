import Testing
@testable import BudsKit

@Test func crcVector() {
    #expect(CRC16.compute([0x60]) == 0x6CA6)
}

@Test func frameRoundTrip() throws {
    let bytes = try #require(SPPCodec.encode(id: MsgID.noiseControls, payload: [2], style: .modern))
    let frame = SPPCodec.decodeSingle(bytes, style: .modern)
    #expect(frame?.id == MsgID.noiseControls)
    #expect(frame?.payload == [2])
}

@Test func coreAudioDevicesAreVisible() {
    let devices = MacAudioRouter.outputDevices()
    #expect(!devices.isEmpty)
    #expect(MacAudioRouter.defaultOutputName != nil)
}
