import AVFoundation
import CoreAudio
import Foundation

/// Mac-side audio routing helpers. The buds switch multipoint focus based on
/// A2DP activity, so selecting them as the default output and starting a short
/// silent stream is enough to ask the firmware for audio focus.
public enum MacAudioRouter {
    private static var silentPlayer: AVAudioPlayer?

    public static func outputDevices() -> [(id: AudioDeviceID, name: String)] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids.compactMap { id in
            guard hasOutput(id), let name = name(of: id) else { return nil }
            return (id, name)
        }
    }

    public static func device(named target: String) -> AudioDeviceID? {
        let devices = outputDevices()
        let lowered = target.lowercased()
        if let exact = devices.first(where: { $0.name.lowercased() == lowered }) {
            return exact.id
        }
        if let partial = devices.first(where: { $0.name.lowercased().contains(lowered) }) {
            return partial.id
        }
        // Bluetooth names can gain/lose a user suffix; match the stable part.
        let needles = ["buds3 pro", "buds2 pro", "buds pro", "buds live", "buds+", "buds"]
            .filter { lowered.contains($0) }
        for needle in needles {
            if let match = devices.first(where: { $0.name.lowercased().contains(needle) }) {
                return match.id
            }
        }
        return nil
    }

    @discardableResult
    public static func setDefaultOutput(_ id: AudioDeviceID) -> Bool {
        var device = id
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                          UInt32(MemoryLayout<AudioDeviceID>.size), &device) == noErr
    }

    public static var defaultOutputName: String? {
        var device: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else {
            return nil
        }
        return name(of: device)
    }

    /// Selects the buds as the default output and opens a short silent A2DP
    /// stream. Returns false when the device is not present or cannot be set.
    @discardableResult
    public static func claim(deviceName: String) -> Bool {
        guard let id = device(named: deviceName) ?? device(named: "Buds") else { return false }
        guard setDefaultOutput(id) else { return false }
        playSilence()
        return true
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size >= UInt32(MemoryLayout<AudioBufferList>.size) else {
            return false
        }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private static func name(of id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        let text = name as String
        return text.isEmpty ? nil : text
    }

    private static func playSilence() {
        silentPlayer?.stop()
        guard let data = silentWAV(seconds: 0.8) else { return }
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = 0.01
        player.prepareToPlay()
        silentPlayer = player
        player.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            silentPlayer?.stop()
            silentPlayer = nil
        }
    }

    private static func silentWAV(seconds: Double) -> Data? {
        let sampleRate = 44_100
        let channels = 2
        let bits = 16
        let byteRate = sampleRate * channels * bits / 8
        let blockAlign = channels * bits / 8
        let frameCount = Int(Double(sampleRate) * seconds)
        let dataSize = frameCount * blockAlign
        var data = Data()
        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        append("RIFF"); append32(UInt32(36 + dataSize)); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(UInt16(channels))
        append32(UInt32(sampleRate)); append32(UInt32(byteRate)); append16(UInt16(blockAlign)); append16(UInt16(bits))
        append("data"); append32(UInt32(dataSize))
        data.append(Data(repeating: 0, count: dataSize))
        return data
    }
}
