import Foundation
import BudsKit

@MainActor
func runProbe() {
    guard CommandLine.arguments.count > 1 else {
        print("usage: swift run BudsProbe <paired-device-address>")
        exit(2)
    }
    let address = CommandLine.arguments[1]
    let controller = BudsController()
    controller.rememberSettings = false
    controller.autoReconnect = true

    func state(_ label: String) {
        print("--- \(label) ---")
        print("link=\(controller.link) name=\(controller.deviceName) model=\(controller.model?.displayName ?? "nil")")
        print("battery L=\(controller.leftBattery?.level ?? -1) R=\(controller.rightBattery?.level ?? -1) case=\(controller.caseBattery?.level ?? -1)")
        print("mode=\(controller.noiseMode.map { String(describing: $0) } ?? "nil") anc=\(controller.ancLevelHigh) vol=\(controller.ambientVolume) eq=\(controller.eqSelection)")
        print("touch L=\(controller.touchLeftAction) R=\(controller.touchRightAction) lock=\(controller.touchLocked) single=\(controller.touchSingleTap) double=\(controller.touchDoubleTap) swipe=\(controller.touchSwipe)")
        print("sku=\(controller.deviceInfo.skuLeft ?? "nil") fw=\(controller.deviceInfo.firmwareLeft ?? "nil")")
        print("last packets:")
        for p in controller.packetLog.suffix(12) {
            print("  \(p.direction.rawValue) \(p.name) \(p.summary.prefix(70))")
        }
    }

    controller.connect(address: address)
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
        state("first connection")
        controller.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            controller.connect(address: address)
            DispatchQueue.main.asyncAfter(deadline: .now() + 22) {
                state("second connection")
                let ok = controller.link == .connected && controller.leftBattery != nil
                controller.disconnect()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(ok ? 0 : 1) }
            }
        }
    }
}

Task { @MainActor in runProbe() }
RunLoop.main.run()
