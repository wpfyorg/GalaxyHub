import Foundation

/// CRC-16/XMODEM (poly 0x1021, init 0x0000) as used by the Galaxy Buds SPP protocol.
public enum CRC16 {
    public static func compute(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : (crc << 1)
            }
        }
        return crc
    }

    /// Little-endian CRC bytes, as written on the wire by the Samsung firmware.
    public static func wireBytes(_ body: [UInt8]) -> [UInt8] {
        let crc = compute(body)
        return [UInt8(crc & 0xFF), UInt8((crc >> 8) & 0xFF)]
    }
}
