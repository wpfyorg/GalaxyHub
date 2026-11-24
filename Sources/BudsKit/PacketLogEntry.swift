import Foundation

public struct PacketLogEntry: Identifiable, Equatable {
    public enum Direction: String {
        case sent = "TX"
        case received = "RX"
        case info = "··"
    }
    public let id = UUID()
    public let date: Date
    public let direction: Direction
    public let name: String
    public let hex: String
    public let summary: String

    public init(direction: Direction, name: String, hex: String = "", summary: String = "") {
        self.date = Date()
        self.direction = direction
        self.name = name
        self.hex = hex
        self.summary = summary
    }

    public var line: String {
        "\(direction.rawValue) \(name) \(summary)"
    }
}
