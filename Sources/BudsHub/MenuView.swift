import AppKit
import SwiftUI
import BudsKit

struct MenuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var buds: BudsController
    @Environment(\.openWindow) private var openWindow
    @AppStorage("moreExpanded") private var moreExpanded = false
    @State private var devices: [(address: String, name: String, model: DeviceModel?, connected: Bool)] = []
    @State private var selectedAddress = ""

    init(model: AppModel) {
        self.model = model
        self.buds = model.controller
    }

    private var content: some View {
        VStack(spacing: 10) {
            header
            if buds.link == .connected {
                if !buds.availableNoiseModes.isEmpty {
                    noiseControls
                }
                batteries
                VStack(spacing: 0) {
                    Collapsible(expanded: moreExpanded) {
                        MoreControls(buds: buds).padding(.top, 10)
                    }
                }
            } else {
                disconnected
            }
        }
        .padding(12)
    }

    var body: some View {
        GlassBox(spacing: 0) {
            if buds.link == .connected && moreExpanded {
                ScrollView { content }
                    .scrollIndicators(.never)
                    .frame(width: 300, height: 600)
            } else {
                content.frame(width: 300)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.74), value: buds.noiseMode)
        .animation(.snappy(duration: 0.22), value: buds.link)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: moreExpanded)
        .task { refreshDevices() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            BatteryRing(level: buds.link == .connected ? buds.batteryMin : nil,
                        charging: buds.leftBattery?.charging == true || buds.rightBattery?.charging == true,
                        size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(buds.link == .connected ? buds.deviceName : "Buds Hub")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(buds.link == .failed(buds.lastError ?? "") ? .red : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if buds.link == .connected {
                    Button { withAnimation { moreExpanded.toggle() } } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(moreExpanded ? 180 : 0))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .circleGlass(interactive: true)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(moreExpanded ? "Fewer controls" : "Equalizer, gestures, find and device info")
                    .accessibilityLabel(moreExpanded ? "Show fewer controls" : "Show more controls")
                }
                menu
            }
        }
    }

    private var subtitle: String {
        switch buds.link {
        case .connected:
            var parts: [String] = []
            if let mode = buds.noiseMode?.shortTitle { parts.append(mode) }
            if let battery = buds.batteryMin { parts.append("\(battery)%") }
            return parts.isEmpty ? (buds.model?.displayName ?? "Connected") : parts.joined(separator: " · ")
        case .connecting:
            return "Connecting…"
        case .failed:
            return buds.lastError ?? "Not connected"
        case .idle:
            return "Not connected"
        }
    }

    private var menu: some View {
        Menu {
            Button("Settings…") { openSettings() }.keyboardShortcut(",")
            Button("Reconnect") { buds.reconnect() }
                .disabled(buds.address == nil || buds.link == .connecting)
            Button("Use this Mac for audio") { buds.claimMacAudio() }
                .disabled(buds.link != .connected)
            Button("Try demo") { buds.connectDemo() }
                .disabled(buds.link == .connecting)
            if buds.link == .connected {
                Divider()
                Button("Forget this device", role: .destructive) { buds.forgetDevice() }
            }
            Divider()
            Button("Quit Buds Hub") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .circleGlass(interactive: true)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }

    // MARK: Noise control

    private var noiseControls: some View {
        VStack(spacing: 7) {
            LiquidSegmented(items: buds.availableNoiseModes, selection: buds.noiseMode,
                            onSelect: { buds.setNoiseMode($0) }) { mode, selected in
                HStack(spacing: 5) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .symbolEffect(.bounce, value: selected)
                    if selected {
                        Text(mode.shortTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .help(mode.title)
                .accessibilityLabel(mode.title)
            } widthFor: { _, selected in selected ? nil : 40 }

            if buds.noiseMode == .anc, buds.has(.ancLevel) {
                LiquidSegmented(items: LevelChoice.allCases, selection: buds.ancLevelHigh ? .high : .low,
                                onSelect: { buds.setANCLevelHigh($0 == .high) }, label: { choice, selected in
                    Text(choice == .high ? "High" : "Low")
                        .font(.caption2.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                }, fitToLabels: true)
                .frame(height: 22)
                .transition(.blurReplace)
            }

            if buds.noiseMode == .ambient, buds.has(.ambientVolume), buds.model?.ambientVolumeMax ?? 0 > 0 {
                ambientSlider
            }
        }
    }

    private var ambientSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.1").font(.system(size: 10)).foregroundStyle(.secondary)
            Slider(value: Binding(get: { Double(buds.ambientVolume) },
                                  set: { buds.setAmbientVolume(Int($0.rounded())) }),
                   in: 0...Double(max(1, buds.model?.ambientVolumeMax ?? 2)), step: 1)
                .controlSize(.mini)
                .tint(.accentColor)
            Image(systemName: "speaker.wave.3").font(.system(size: 10)).foregroundStyle(.secondary)
            Text("\(buds.ambientVolume)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Battery

    private var batteries: some View {
        HStack(spacing: 0) {
            BatteryCell(side: "L", battery: buds.leftBattery, placement: buds.placementLeft,
                        symbol: "earbuds")
            Spacer(minLength: 0)
            BatteryCell(side: "R", battery: buds.rightBattery, placement: buds.placementRight,
                        symbol: "earbuds")
            if buds.has(.caseBattery) {
                Spacer(minLength: 0)
                BatteryCell(side: "Case", battery: buds.caseBattery, placement: nil,
                            symbol: "airpods.chargingcase")
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: Disconnected

    private var disconnected: some View {
        VStack(spacing: 8) {
            if buds.link == .connecting {
                VStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Opening the control channel…")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .roundedRectGlass(cornerRadius: 14)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = buds.lastError, buds.link != .idle {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if devices.isEmpty {
                        Text("Pair your Galaxy Buds in System Settings › Bluetooth, then come back here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Bluetooth Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    } else {
                        HStack(spacing: 6) {
                            Menu {
                                ForEach(devices.indices, id: \.self) { index in
                                    Button {
                                        selectedAddress = devices[index].address
                                    } label: {
                                        Text(devices[index].name + (devices[index].model.map { " · \($0.displayName)" } ?? ""))
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(devices.first(where: { $0.address == selectedAddress })?.connected == true ? .green : .secondary)
                                        .frame(width: 6, height: 6)
                                    Text(devices.first(where: { $0.address == selectedAddress })?.name ?? "Choose device")
                                        .font(.caption)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 7, weight: .bold))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.primary.opacity(0.07)))
                            }
                            .menuStyle(.button)
                            .menuIndicator(.hidden)
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                            Button("Connect") {
                                guard selectedAddressIsValid else { return }
                                buds.connect(address: selectedAddress)
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                            .disabled(!selectedAddressIsValid || buds.link == .connecting)
                        }
                        Button("Refresh devices") { refreshDevices() }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .roundedRectGlass(cornerRadius: 14)
            }

            HStack(spacing: 8) {
                Button("Try demo") { buds.connectDemo() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                if buds.address != nil {
                    Button("Retry") { buds.reconnect() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
                Spacer()
            }
        }
    }

    private func refreshDevices() {
        DispatchQueue.global(qos: .userInitiated).async {
            let found = IOBluetoothTransport.discoverBudsDevices()
            DispatchQueue.main.async {
                devices = found
                let wanted = selectedAddress.isEmpty
                    ? (buds.address ?? SettingsStore.shared.lastAddress)
                    : selectedAddress
                if let wanted, found.contains(where: { $0.address == wanted }) {
                    selectedAddress = wanted
                } else {
                    selectedAddress = found.first?.address ?? ""
                }
            }
        }
    }

    private var selectedAddressIsValid: Bool {
        !selectedAddress.isEmpty && devices.contains { $0.address == selectedAddress }
    }

    private func openSettings() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            for window in NSApp.windows where window.title.contains("Settings") {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}

private enum LevelChoice: Int, CaseIterable, Identifiable {
    case low, high
    var id: Int { rawValue }
}

private struct BatteryCell: View {
    let side: String
    let battery: BatteryLevel?
    let placement: Placement?
    let symbol: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(side).font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
            if battery?.charging == true {
                Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(.green)
            }
            Text(displayLevel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
        }
        .help(placement?.title ?? side)
        .accessibilityElement()
        .accessibilityLabel("\(side) \(battery.map { "\($0.level) percent" } ?? "unavailable")")
    }

    private var displayLevel: String {
        guard let battery else { return "—" }
        // The case reports 0 when it is not connected to the buds; don't scare
        // the user with a red "0%" in that state.
        if side == "Case", battery.level == 0, !battery.charging { return "—" }
        return "\(battery.level)%"
    }

    private var color: Color {
        guard let battery else { return .secondary }
        if battery.charging { return .green }
        if side == "Case", battery.level == 0 { return .secondary }
        return battery.level <= 20 ? .red : .primary
    }
}

private struct Collapsible<Content: View>: View {
    let expanded: Bool
    @ViewBuilder let content: () -> Content
    @StateObject private var size = MeasuredHeight()

    var body: some View {
        content()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { size.height = $0 }
            .opacity(expanded ? 1 : 0)
            .frame(height: expanded ? size.height : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(expanded)
            .accessibilityHidden(!expanded)
    }
}

private final class MeasuredHeight: ObservableObject {
    @Published var height: CGFloat = 0
}
