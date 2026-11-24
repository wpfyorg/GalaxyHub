// swift-tools-version: 5.9
import Foundation
import PackageDescription

let testingMacros = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: testingMacros)
    ? [.unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])]
    : []

let package = Package(
    name: "BudsHub",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BudsHub", targets: ["BudsHub"]),
        .library(name: "BudsKit", targets: ["BudsKit"])
    ],
    targets: [
        .target(name: "BudsKit"),
        .executableTarget(name: "BudsHub", dependencies: ["BudsKit"]),
        .executableTarget(name: "BudsProbe", dependencies: ["BudsKit"]),
        .testTarget(name: "BudsKitTests", dependencies: ["BudsKit"],
                    swiftSettings: testSettings)
    ],
    swiftLanguageVersions: [.v5]
)
