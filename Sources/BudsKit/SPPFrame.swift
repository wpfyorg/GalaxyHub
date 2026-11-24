import Foundation

public enum FrameStyle: String, Codable, Sendable {
    /// Galaxy Buds (2019): FE <type> <size> <id> <payload> <crc16> EE
    case legacy
    /// Buds+ and newer: FD <size lo> <size hi + flags> <id> <payload> <crc16> DD
    case modern

    public var som: UInt8 { self == .legacy ? 0xFE : 0xFD }
    public var eom: UInt8 { self == .legacy ? 0xEE : 0xDD }
}

public enum SPPDirection: String, Sendable {
    case request
    case response
}

public struct SPPFrame: Equatable, Sendable {
    public var id: UInt8
    public var payload: [UInt8]
    public var direction: SPPDirection
    public var raw: [UInt8]

    public init(id: UInt8, payload: [UInt8], direction: SPPDirection = .request, raw: [UInt8] = []) {
        self.id = id
        self.payload = payload
        self.direction = direction
        self.raw = raw
    }

    public var hex: String { raw.hexString }
    public var payloadHex: String { payload.hexString }
}

public enum SPPCodec {
    public static let modernMaxPayload = 1024

    /// Encodes a request. Samsung's own clients send requests with the direction bit clear.
    public static func encode(id: UInt8, payload: [UInt8], style: FrameStyle, response: Bool = false) -> [UInt8] {
        let body = [id] + payload
        let crc = CRC16.wireBytes(body)
        switch style {
        case .legacy:
            let size = UInt8(clamping: body.count + crc.count)
            return [style.som, response ? 1 : 0, size, id] + payload + crc + [style.eom]
        case .modern:
            var header = UInt16(body.count + crc.count) & 0x03FF
            if response { header |= 0x1000 }
            return [style.som, UInt8(header & 0xFF), UInt8((header >> 8) & 0xFF), id] + payload + crc + [style.eom]
        }
    }

    /// Pops every complete, checksum-valid frame out of `buffer`, resynchronising on garbage.
    public static func extractFrames(from buffer: inout [UInt8], style: FrameStyle) -> [SPPFrame] {
        var frames: [SPPFrame] = []
        while true {
            guard let somIndex = buffer.firstIndex(of: style.som) else {
                buffer.removeAll(keepingCapacity: true)
                break
            }
            if somIndex > 0 { buffer.removeFirst(somIndex) }
            guard buffer.count >= 4 else { break }

            let headerSize: Int
            let size: Int
            let direction: SPPDirection
            var isFragment = false

            switch style {
            case .legacy:
                headerSize = 3
                size = Int(buffer[2])
                direction = buffer[1] == 0 ? .request : .response
            case .modern:
                headerSize = 3
                let rawHeader = UInt16(buffer[1]) | (UInt16(buffer[2]) << 8)
                size = Int(rawHeader & 0x03FF)
                direction = (rawHeader & 0x1000) != 0 ? .request : .response
                isFragment = (rawHeader & 0x2000) != 0
            }

            // size counts id + payload + crc
            guard size >= 3, size <= modernMaxPayload else {
                buffer.removeFirst()
                continue
            }
            let total = headerSize + size + 1
            guard buffer.count >= total else { break }

            let frameBytes = Array(buffer[0..<total])
            let id = frameBytes[3]
            let payloadLength = size - 3
            let payload = Array(frameBytes[4..<(4 + payloadLength)])
            let crcBytes = Array(frameBytes[(4 + payloadLength)..<(6 + payloadLength)])
            let expected = CRC16.wireBytes([id] + payload)

            let eomOK = frameBytes.last == style.eom
            let crcOK = crcBytes == expected
            if eomOK && crcOK {
                frames.append(SPPFrame(id: id, payload: payload, direction: direction, raw: frameBytes))
                buffer.removeFirst(total)
            } else {
                // Bad frame: drop the SOM and scan forward.
                buffer.removeFirst()
            }
            _ = isFragment // fragment reassembly is only needed for firmware transfer
        }
        return frames
    }

    public static func decodeSingle(_ bytes: [UInt8], style: FrameStyle) -> SPPFrame? {
        var copy = bytes
        return extractFrames(from: &copy, style: style).first
    }
}

extension Array where Element == UInt8 {
    public var hexString: String {
        map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
