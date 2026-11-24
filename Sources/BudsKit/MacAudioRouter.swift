import AVFoundation
import CoreAudio
import Foundation

/// Mac-side audio routing helpers. The buds switch multipoint focus based on
/// A2DP activity, so selecting them as the default output and holding a silent
/// IO stream is enough to ask the firmware for audio focus.
public enum MacAudioRouter {
    private static var engine: AVAudioEngine?
    private static var holdTimer: Timer?
    private static var heldDevice: AudioDeviceID?
    private static var usedHALStart = false

    public static func outputDevices() -> [(id: AudioDeviceID, name: String)] {
        enumerateDevices().compactMap { id in
            guard hasOutput(id), let name = name(of: id) else { return nil }
            return (id, name)
        }
    }

    public static func device(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value = uid as CFString
        var id: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                       UInt32(MemoryLayout<CFString?>.size), pointer, &size, &id)
        }
        return status == noErr && id != kAudioObjectUnknown ? id : nil
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

    public static var defaultOutputID: AudioDeviceID? {
        var device: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else {
            return nil
        }
        return device
    }

    public static var defaultOutputName: String? {
        guard let device = defaultOutputID else { return nil }
        return name(of: device)
    }

    /// True when the system default output is the buds identified by their
    /// Bluetooth address. Comparing device identity avoids mistaking another
    /// pair with a similar name for the controlled earbuds.
    public static func isDefaultOutput(address: String?) -> Bool {
        guard let address else { return false }
        let uid = address.replacingOccurrences(of: ":", with: "-").uppercased() + ":output"
        guard let target = device(forUID: uid), let current = defaultOutputID else { return false }
        return current == target
    }

    /// Selects the buds as the default output and holds a silent A2DP stream for
    /// a short bridging period. The media app that starts playing keeps the
    /// stream alive; without this hold the link closes as soon as a short clip
    /// ends and the buds fall back to the phone.
    @discardableResult
    public static func claim(address: String?, deviceName: String) -> Bool {
        let id: AudioDeviceID?
        if let address {
            let uid = address.replacingOccurrences(of: ":", with: "-").uppercased() + ":output"
            // A targeted claim must not silently select a different pair of
            // buds; only fall back when no address was supplied.
            id = device(forUID: uid)
        } else {
            id = device(named: deviceName) ?? device(named: "Buds")
        }
        guard let id else { return false }
        guard setDefaultOutput(id) else { return false }
        return hold(id)
    }

    /// Stops the silent bridge stream. Other apps that are playing keep their
    /// own stream and the buds stay on the Mac.
    public static func releaseHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        engine?.stop()
        engine = nil
        if usedHALStart, let heldDevice {
            AudioDeviceStop(heldDevice, nil)
        }
        heldDevice = nil
        usedHALStart = false
    }

    public static var isHolding: Bool { engine?.isRunning == true || usedHALStart }

    private static func hold(_ id: AudioDeviceID) -> Bool {
        releaseHold()
        heldDevice = id
        usedHALStart = false
        // Keep the bridge open long enough for a media app to start its own
        // stream. A permanent hold would block the phone's media focus.
        holdTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
            releaseHold()
        }
        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else {
            usedHALStart = AudioDeviceStart(id, nil) == noErr
            if !usedHALStart { releaseHold() }
            return usedHALStart
        }
        let silence = AVAudioSourceNode { _, _, _, audioBufferList in
            for buffer in UnsafeMutableAudioBufferListPointer(audioBufferList) {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
            }
            return noErr
        }
        engine.attach(silence)
        engine.connect(silence, to: engine.mainMixerNode, format: format)
        var device = id
        if let audioUnit = engine.outputNode.audioUnit {
            AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global, 0, &device,
                                 UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        engine.prepare()
        do {
            try engine.start()
            self.engine = engine
            return true
        } catch {
            usedHALStart = AudioDeviceStart(id, nil) == noErr
            if !usedHALStart { releaseHold() }
            return usedHALStart
        }
    }

    private static func enumerateDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr,
              size >= UInt32(MemoryLayout<AudioBufferList>.size) else {
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
}

/// Observes the system default output device and calls `onChange` whenever it
/// changes. The callback runs on `queue`; callers decide where to hop next.
public final class DefaultOutputObserver {
    private let queue = DispatchQueue(label: "io.github.budshub.audio-route")
    private let onChange: () -> Void
    private var listener: AudioObjectPropertyListenerBlock?
    private var installed = false

    public init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    public func start() {
        guard !installed else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.onChange()
        }
        let status = withUnsafePointer(to: &address) { pointer in
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), pointer, queue, block)
        }
        guard status == noErr else { return }
        listener = block
        installed = true
    }

    public func stop() {
        guard installed, let listener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        _ = withUnsafePointer(to: &address) { pointer in
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), pointer, queue, listener)
        }
        self.listener = nil
        installed = false
    }
}
