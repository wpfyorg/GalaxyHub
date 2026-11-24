import Foundation
import IOBluetooth

public struct ConnectedDevice: Equatable, Sendable {
    public var address: String
    public var name: String
    public var model: DeviceModel?
    public var serviceName: String
    public var serviceUUID: String
    public var rssi: Int
    public init(address: String, name: String, model: DeviceModel?, serviceName: String, serviceUUID: String, rssi: Int = 0) {
        self.address = address
        self.name = name
        self.model = model
        self.serviceName = serviceName
        self.serviceUUID = serviceUUID
        self.rssi = rssi
    }
}

public enum TransportError: LocalizedError {
    case bluetoothUnavailable
    case deviceNotFound(String)
    case connectFailed(IOReturn)
    case serviceNotFound
    case channelOpenFailed(IOReturn)
    case notOpen
    case sendFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: return "Bluetooth is unavailable. Turn Bluetooth on and allow Buds Hub in System Settings › Privacy & Security › Bluetooth."
        case .deviceNotFound(let address): return "No paired device found at \(address). Pair the earbuds in System Settings › Bluetooth first."
        case .connectFailed(let code): return "Could not connect to the earbuds (0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .serviceNotFound: return "The earbuds' control service was not found. Try re-pairing the earbuds."
        case .channelOpenFailed(let code): return "Could not open the RFCOMM channel (0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .notOpen: return "The earbuds are not connected."
        case .sendFailed(let code): return "Sending to the earbuds failed (0x\(String(UInt32(bitPattern: code), radix: 16)))."
        }
    }
}

public protocol BudsLink: AnyObject {
    var onData: (([UInt8]) -> Void)? { get set }
    var onClosed: ((String) -> Void)? { get set }
    var onLog: ((String) -> Void)? { get set }
    func connect(address: String, preferredModel: DeviceModel?, completion: @escaping (Result<ConnectedDevice, Error>) -> Void)
    func send(_ bytes: [UInt8], completion: ((Error?) -> Void)?)
    func disconnect()
}

public final class IOBluetoothTransport: NSObject, BudsLink, IOBluetoothRFCOMMChannelDelegate, IOBluetoothDeviceAsyncCallbacks {
    public var onData: (([UInt8]) -> Void)?
    public var onClosed: ((String) -> Void)?
    public var onLog: ((String) -> Void)?

    private let queue = DispatchQueue(label: "io.github.budshub.bluetooth", qos: .userInitiated)
    private var channel: IOBluetoothRFCOMMChannel?
    private var closing = false
    private let stateLock = NSLock()
    private var sawData = false
    private var busy = false
    private var sdpSemaphore: DispatchSemaphore?
    public private(set) var connectedDevice: ConnectedDevice?

    public static let knownServiceUUIDs = [
        "2e73a4ad-332d-41fc-90e2-16bef06523f2", // Samsung SPP (Buds2 and newer)
        "00001101-0000-1000-8000-00805f9b34fb", // Standard SPP (Buds+/Live/Pro)
        "00001102-0000-1000-8000-00805f9b34fd", // Legacy SPP (Buds 2019)
        "f8620674-a1ed-41ab-a8b9-de9ad655729d"  // SMEP SPP
    ]

    public override init() { super.init() }

    public static func pairedDevices() -> [IOBluetoothDevice] {
        var seen = Set<String>()
        return (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).filter { device in
            let key = normalize(device.addressString ?? "")
            guard !key.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    public static func normalize(_ address: String) -> String {
        address.lowercased().replacingOccurrences(of: ":", with: "-")
    }

    public static func displayAddress(_ address: String) -> String {
        address.uppercased().replacingOccurrences(of: "-", with: ":")
    }

    public static func sdpUUID(_ string: String) -> IOBluetoothSDPUUID? {
        let hex = string.replacingOccurrences(of: "-", with: "")
        guard hex.count == 32 else { return nil }
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return IOBluetoothSDPUUID(bytes: bytes, length: 16)
    }

    public static func uuidString(_ uuid: IOBluetoothSDPUUID) -> String {
        let data = uuid as Data
        guard data.count == 16 else { return uuid.description }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
    }

    /// Reads the ServiceClassIDList of every cached SDP record and returns all UUIDs.
    public static func serviceUUIDs(of device: IOBluetoothDevice) -> [String] {
        guard let records = device.services as? [IOBluetoothSDPServiceRecord] else { return [] }
        var uuids = Set<String>()
        for record in records {
            if let element = record.getAttributeDataElement(1),
               let array = element.getArrayValue() as? [IOBluetoothSDPDataElement] {
                for sub in array {
                    if let uuid = sub.getUUIDValue() {
                        uuids.insert(uuidString(uuid))
                    }
                }
            }
        }
        return Array(uuids)
    }

    public static func model(for device: IOBluetoothDevice) -> DeviceModel? {
        // Prefer the vendor SPP UUID product ID (survives device renames).
        for uuid in serviceUUIDs(of: device) {
            if let product = DeviceCatalog.productID(fromServiceUUID: uuid),
               let model = DeviceCatalog.model(productID: product) {
                return model
            }
        }
        return DeviceCatalog.model(deviceName: device.name ?? "")
    }

    public static func resolveDevice(address: String) -> IOBluetoothDevice? {
        let normalized = normalize(address)
        return pairedDevices().first { normalize($0.addressString ?? "") == normalized }
    }

    /// Quick, non-connecting model detection for the device picker.
    public static func probeModel(address: String) -> (name: String, model: DeviceModel?)? {
        guard let device = resolveDevice(address: address) else { return nil }
        return (device.name ?? "Galaxy Buds", model(for: device))
    }

    /// UI-facing discovery. Call this off the main thread: the first IOBluetooth
    /// call initializes CoreBluetooth and can wait on the main queue.
    public static func discoverBudsDevices() -> [(address: String, name: String, model: DeviceModel?, connected: Bool)] {
        pairedDevices().compactMap { device in
            guard let address = device.addressString else { return nil }
            let name = device.name ?? "Unknown device"
            // Only Samsung devices have the vendor product ID. Do not match
            // "Buds" generically: OPPO/OnePlus/Sony earbuds would be listed
            // with a Galaxy profile. A renamed Samsung pair still appears once
            // its SDP vendor UUID is cached.
            let hasSamsungUUID = serviceUUIDs(of: device).contains { $0.hasPrefix("d908aab5-") }
            let looksSamsung = hasSamsungUUID
                || name.localizedCaseInsensitiveContains("galaxy")
                || name.localizedCaseInsensitiveContains("samsung")
            guard looksSamsung else { return nil }
            return (address, name, model(for: device) ?? DeviceCatalog.model(deviceName: name), device.isConnected())
        }
    }

    public var isBusy: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return busy
    }

    public func connect(address: String, preferredModel: DeviceModel?, completion: @escaping (Result<ConnectedDevice, Error>) -> Void) {
        stateLock.lock(); busy = true; stateLock.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            defer {
                self.stateLock.lock(); self.busy = false; self.stateLock.unlock()
            }
            do {
                let info = try self.connectSync(address: address, preferredModel: preferredModel)
                DispatchQueue.main.async { completion(.success(info)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func connectSync(address: String, preferredModel: DeviceModel?) throws -> ConnectedDevice {
        guard let device = Self.resolveDevice(address: address) else {
            throw TransportError.deviceNotFound(address)
        }
        let name = device.name ?? "Galaxy Buds"
        onLogOnMain("Connecting to \(name) (\(Self.displayAddress(address)))")

        if !device.isConnected() {
            let status = device.openConnection()
            onLogOnMain("openConnection -> 0x\(String(status, radix: 16))")
            if status != kIOReturnSuccess {
                throw TransportError.connectFailed(status)
            }
        }

        if (device.services as? [IOBluetoothSDPServiceRecord])?.isEmpty ?? true {
            onLogOnMain("Refreshing SDP database")
            let semaphore = DispatchSemaphore(value: 0)
            sdpSemaphore = semaphore
            let started = device.performSDPQuery(self)
            if started == kIOReturnSuccess {
                _ = semaphore.wait(timeout: .now() + 5)
            }
            sdpSemaphore = nil
            // Some stacks deliver the callback just after the timeout.
            if (device.services as? [IOBluetoothSDPServiceRecord])?.isEmpty ?? true {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // The profile used to choose a service is not proof of the hardware:
        // keep detection separate so firmware SKU detection still runs.
        let detected = Self.model(for: device)
        let profile = detected ?? preferredModel

        var serviceRecord: IOBluetoothSDPServiceRecord?
        var usedUUID = ""
        let candidates = (profile?.serviceUUIDs ?? []) + Self.knownServiceUUIDs
        var tried = Set<String>()
        for uuidString in candidates where !tried.contains(uuidString) {
            tried.insert(uuidString)
            guard let uuid = Self.sdpUUID(uuidString),
                  let record = device.getServiceRecord(for: uuid) else { continue }
            var cid: BluetoothRFCOMMChannelID = 0
            if record.getRFCOMMChannelID(&cid) == kIOReturnSuccess {
                serviceRecord = record
                usedUUID = uuidString
                break
            }
        }

        // Some firmware only exposes the service through the SDP list rather
        // than getServiceRecord(for:). Match our candidate UUIDs against it.
        if serviceRecord == nil, let records = device.services as? [IOBluetoothSDPServiceRecord] {
            let wanted = Set(candidates)
            for record in records {
                let uuids = Set(Self.serviceUUIDs(ofRecord: record))
                guard !uuids.intersection(wanted).isEmpty else { continue }
                var cid: BluetoothRFCOMMChannelID = 0
                if record.getRFCOMMChannelID(&cid) == kIOReturnSuccess {
                    serviceRecord = record
                    usedUUID = uuids.intersection(wanted).first ?? ""
                    break
                }
            }
        }

        guard let record = serviceRecord else { throw TransportError.serviceNotFound }
        var channelID: BluetoothRFCOMMChannelID = 0
        guard record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess else {
            throw TransportError.serviceNotFound
        }

        let serviceName = record.getServiceName() ?? "SPP"
        onLogOnMain("Opening \(serviceName) (channel \(channelID))")
        var newChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelSync(&newChannel, withChannelID: channelID, delegate: self)
        guard let newChannel else {
            throw TransportError.channelOpenFailed(status)
        }
        // macOS frequently reports kIOReturnError here even though the
        // channel opens a moment later. Trust the channel, then poll.
        channel = newChannel
        closing = false
        stateLock.lock(); sawData = false; stateLock.unlock()
        var opened = newChannel.isOpen()
        var tries = 0
        // The channel can take several seconds to report open after a fresh
        // Bluetooth power cycle, and macOS sometimes reports kIOReturnError
        // even when the channel is coming up. Wait, but do not pretend a
        // permanently closed channel is connected.
        while !opened && !hasSeenData() && tries < 60 {
            Thread.sleep(forTimeInterval: 0.1)
            opened = newChannel.isOpen()
            tries += 1
        }
        if !opened && !hasSeenData() {
            newChannel.setDelegate(nil)
            _ = newChannel.close()
            channel = nil
            closing = true
            connectedDevice = nil
            throw TransportError.channelOpenFailed(status)
        }
        if let profile {
            onLogOnMain("Using \(profile.displayName) profile")
        } else {
            onLogOnMain("Unknown model; will detect from firmware SKU")
        }
        let info = ConnectedDevice(address: address, name: name, model: detected,
                                   serviceName: serviceName, serviceUUID: usedUUID,
                                   rssi: Int(device.rssi()))
        connectedDevice = info
        return info
    }

    public static func serviceUUIDs(ofRecord record: IOBluetoothSDPServiceRecord) -> [String] {
        guard let element = record.getAttributeDataElement(1),
              let array = element.getArrayValue() as? [IOBluetoothSDPDataElement] else { return [] }
        return array.compactMap { $0.getUUIDValue().map(uuidString) }
    }

    public func send(_ bytes: [UInt8], completion: ((Error?) -> Void)?) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.sendSync(bytes)
                if let completion { DispatchQueue.main.async { completion(nil) } }
            } catch {
                if let completion { DispatchQueue.main.async { completion(error) } }
            }
        }
    }

    private func sendSync(_ bytes: [UInt8]) throws {
        guard let channel, channel.isOpen() else { throw TransportError.notOpen }
        let mtu = max(1, Int(channel.getMTU()))
        var offset = 0
        while offset < bytes.count {
            let count = min(mtu, bytes.count - offset)
            let result = bytes.withUnsafeBytes { raw -> IOReturn in
                let base = raw.baseAddress!.advanced(by: offset)
                return channel.writeSync(UnsafeMutableRawPointer(mutating: base), length: UInt16(count))
            }
            if result != kIOReturnSuccess {
                throw TransportError.sendFailed(result)
            }
            offset += count
        }
    }

    public func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.closing = true
            self.channel?.setDelegate(nil)
            _ = self.channel?.close()
            self.channel = nil
            self.connectedDevice = nil
        }
    }

    private func onLogOnMain(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.onLog?(message) }
    }

    private func hasSeenData() -> Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return sawData
    }

    public func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        sdpSemaphore?.signal()
    }

    public func remoteNameRequestComplete(_ device: IOBluetoothDevice!, status: IOReturn) {}

    public func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {}

    public func rfcommChannelData(_ channel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        stateLock.lock(); sawData = true; stateLock.unlock()
        let bytes = [UInt8](Data(bytes: dataPointer, count: dataLength))
        DispatchQueue.main.async { [weak self] in
            self?.onData?(bytes)
        }
    }

    public func rfcommChannelClosed(_ channel: IOBluetoothRFCOMMChannel!) {
        guard !closing else { return }
        self.channel = nil
        DispatchQueue.main.async { [weak self] in
            self?.onClosed?("The earbuds closed the connection")
        }
    }
}
