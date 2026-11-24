import AppKit
import SwiftUI
import BudsKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")
            DevicesSettings(model: model)
                .tabItem { Label("Devices", systemImage: "earbuds") }
                .tag("devices")
            ShortcutSettings(model: model)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag("shortcuts")
            DeveloperSettings(model: model)
                .tabItem { Label("Developer", systemImage: "hammer") }
                .tag("developer")
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag("about")
        }
        .frame(width: 600, height: 620)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title.contains("Settings") {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var buds: BudsController
    @AppStorage("showHUD") private var showHUD = true
    @AppStorage("hotkeysEnabled") private var hotkeysEnabled = true

    init(model: AppModel) {
        self.model = model
        self.buds = model.controller
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.12))
                        Image(systemName: "earbuds").font(.system(size: 24, weight: .medium)).foregroundStyle(Color.accentColor)
                    }
                    .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(buds.link == .connected ? buds.deviceName : "Galaxy Buds")
                            .font(.headline)
                        Text(status)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if buds.link == .connected {
                        Button("Disconnect") { buds.disconnect() }
                            .buttonStyle(.glass)
                    } else {
                        Button("Connect") { buds.reconnect() }
                            .buttonStyle(.glassProminent)
                            .disabled(buds.address == nil)
                    }
                }
                .padding(.vertical, 2)
            }

            Section {
                Toggle(isOn: $buds.autoReconnect) {
                    Text("Reconnect automatically")
                    Text("Bring the earbuds back to this Mac when they come out of the case.")
                }
                Toggle(isOn: $buds.rememberSettings) {
                    Text("Remember settings between connections")
                    Text("Re-apply the noise mode, ANC level, ambient volume and equalizer you last picked.")
                }
                Toggle(isOn: $buds.menuBarBattery) {
                    Text("Show battery in the menu bar icon")
                    Text("The ring around the icon fills with the lowest earbud battery.")
                }
                Toggle("Show HUD for shortcuts", isOn: $showHUD)
                Toggle("Enable global shortcuts", isOn: $hotkeysEnabled)
                    .onChange(of: hotkeysEnabled) { _, _ in model.reloadHotkeys() }
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            } footer: {
                Text("Launch at login works when Buds Hub is installed as an app bundle. Settings are stored per paired device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Try demo device") { buds.connectDemo() }
                Button("Forget this device", role: .destructive) { buds.forgetDevice() }
                    .disabled(buds.address == nil)
            }
        }
        .formStyle(.grouped)
    }

    private var status: String {
        switch buds.link {
        case .connected:
            var parts = [buds.model?.displayName ?? buds.detectedModel?.displayName ?? "Connected"]
            if let battery = buds.batteryMin { parts.append("\(battery)%") }
            if let mode = buds.noiseMode { parts.append(mode.shortTitle) }
            return parts.joined(separator: " · ")
        case .connecting:
            return "Connecting…"
        case .failed:
            return buds.lastError ?? "Not connected"
        case .idle:
            return buds.address == nil ? "Not connected" : "Waiting to reconnect"
        }
    }
}

// MARK: - Devices

private struct DevicesSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var buds: BudsController
    @State private var devices: [(address: String, name: String, model: DeviceModel?, connected: Bool)] = []

    init(model: AppModel) {
        self.model = model
        self.buds = model.controller
    }

    var body: some View {
        Form {
            Section {
                if buds.link == .connected {
                    LabeledContent("Connected") {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(buds.deviceName)
                            Text(buds.model?.displayName ?? "Detecting model…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Service", value: buds.serviceName)
                    LabeledContent("Address", value: buds.address?.uppercased() ?? "—")
                    LabeledContent("Detected model", value: buds.detectedModel?.displayName ?? "Unknown")
                    Picker("Model override", selection: Binding(
                        get: { modelOverride },
                        set: { buds.setModelOverride($0) })) {
                        Text("Automatic").tag(DeviceModelID?.none)
                        ForEach(DeviceModelID.allCases, id: \.self) { id in
                            Text(DeviceCatalog.model(for: id).displayName).tag(DeviceModelID?.some(id))
                        }
                    }
                    if buds.model?.id == .buds4 || buds.model?.id == .buds4Pro {
                        Text("Buds4 volume-swipe and blade-light controls are experimental.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Connect the earbuds to edit their model profile.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Current device")
            }

            Section {
                if devices.isEmpty {
                    Text("No paired Galaxy Buds found. Pair them in System Settings › Bluetooth first.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(devices.indices, id: \.self) { index in
                    let device = devices[index]
                    HStack(spacing: 10) {
                        Circle()
                            .fill(device.connected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name).font(.body.weight(.medium))
                            Text(device.address.uppercased())
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(device.model?.displayName ?? "Galaxy Buds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(buds.address == device.address && buds.link == .connected ? "Connected" : "Connect") {
                            buds.connect(address: device.address)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(buds.link == .connecting || (buds.address == device.address && buds.link == .connected))
                    }
                    .padding(.vertical, 2)
                }
                HStack {
                    Button("Refresh") { refresh() }
                        .buttonStyle(.glass)
                    Spacer()
                    Button("Open Bluetooth Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.glass)
                }
            } header: {
                Text("Paired Galaxy Buds")
            } footer: {
                Text("Buds Hub identifies each model from its vendor service UUID, SKU and firmware. A wrong automatic match can be overridden above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { refresh() }
    }

    private var modelOverride: DeviceModelID? {
        guard let address = buds.address else { return nil }
        return SettingsStore.shared.state(for: address).modelOverride.flatMap(DeviceModelID.init(rawValue:))
    }

    private func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let found = IOBluetoothTransport.discoverBudsDevices()
            DispatchQueue.main.async { devices = found }
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutSettings: View {
    @ObservedObject var model: AppModel
    @AppStorage("hotkeysEnabled") private var hotkeysEnabled = true

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    LabeledContent {
                        ShortcutRecorder(shortcut: binding(for: action)) { _ in }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.title)
                                if model.failedShortcuts.contains(action) {
                                    Text("Already used by another app — pick another combination.")
                                        .font(.caption).foregroundStyle(.red)
                                }
                            }
                        } icon: {
                            Image(systemName: action.symbol)
                        }
                    }
                }
            } footer: {
                Text("Shortcuts work in every app without Accessibility permission. Include ⌘, ⌥, ⌃ or ⇧, or use a function key. Changes apply immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Enable global shortcuts", isOn: $hotkeysEnabled)
                    .onChange(of: hotkeysEnabled) { _, _ in model.reloadHotkeys() }
                Button("Restore defaults") {
                    for action in ShortcutAction.allCases {
                        model.shortcuts.set(action.defaultShortcut, for: action)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for action: ShortcutAction) -> Binding<Shortcut?> {
        Binding(get: { model.shortcuts.shortcut(for: action) },
                set: { model.shortcuts.set($0, for: action) })
    }
}

// MARK: - Developer

private struct DeveloperSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var buds: BudsController
    @State private var commandHex = "22"
    @State private var payloadHex = ""
    @State private var autoScroll = true

    init(model: AppModel) {
        self.model = model
        self.buds = model.controller
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("ID", text: $commandHex, prompt: Text("22"))
                        .font(.body.monospaced())
                        .frame(width: 60)
                    TextField("Payload", text: $payloadHex, prompt: Text("hex, e.g. 01 01"))
                        .font(.body.monospaced())
                    Button("Send") { send() }
                        .buttonStyle(.glassProminent)
                        .disabled(UInt8(Hex.clean(commandHex), radix: 16) == nil
                                  || !Hex.isComplete(payloadHex)
                                  || buds.link != .connected)
                }
                HStack {
                    Button("SKU") { buds.sendRaw(id: MsgID.debugSKU, payload: []) }
                    Button("Version") { buds.sendRaw(id: MsgID.versionInfo, payload: []) }
                    Button("Multipoint") { buds.sendRaw(id: MsgID.multipointInfo, payload: []) }
                    Button("Custom EQ") { buds.sendRaw(id: MsgID.customEqualizerRecv, payload: []) }
                    Spacer()
                    Button("Manager info") { buds.sendRaw(id: MsgID.managerInfo, payload: [1, 1, 34]) }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(buds.link != .connected)
            } header: {
                Text("Raw command")
            } footer: {
                Text("Frames, checksums and model-specific headers are added automatically. Unknown commands can change earbud behaviour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(buds.packetLog) { entry in
                                PacketRow(entry: entry).id(entry.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    .frame(height: 260)
                    .onChange(of: buds.packetLog.last?.id) { _, id in
                        guard autoScroll, let id else { return }
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
                HStack {
                    Toggle("Follow", isOn: $autoScroll).toggleStyle(.checkbox)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(buds.copyLog(), forType: .string)
                    }
                    Button("Clear") { buds.clearLog() }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            } header: {
                Text("Packet log")
            }

            Section {
                LabeledContent("Device", value: buds.deviceName)
                LabeledContent("Model", value: buds.model?.displayName ?? "Unknown")
                LabeledContent("Address", value: buds.address?.uppercased() ?? "—")
                LabeledContent("Service", value: buds.serviceName.isEmpty ? "—" : buds.serviceName)
                LabeledContent("Revision", value: buds.revision == 0 ? "—" : "\(buds.revision)")
                LabeledContent("SKU", value: buds.deviceInfo.skuLeft ?? "—")
                LabeledContent("Firmware", value: buds.deviceInfo.firmwareLeft ?? "—")
                LabeledContent("Build", value: buds.deviceInfo.build ?? "—")
                HStack {
                    Button("Disconnect") { buds.disconnect() }
                    Button("Reconnect") { buds.reconnect() }
                    Button("Try demo") { buds.connectDemo() }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            } header: {
                Text("Link")
            }
        }
        .formStyle(.grouped)
    }

    private func send() {
        guard Hex.isComplete(payloadHex),
              let id = UInt8(Hex.clean(commandHex), radix: 16) else { return }
        buds.sendRaw(id: id, payload: Hex.bytes(payloadHex))
    }
}

private struct PacketRow: View {
    let entry: PacketLogEntry
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(Self.formatter.string(from: entry.date))
                    .foregroundStyle(.tertiary)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 11)
                Text(entry.name).foregroundStyle(entry.direction == .info ? .secondary : .primary)
                if !entry.summary.isEmpty {
                    Text(entry.summary).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if !entry.hex.isEmpty {
                Text(entry.hex)
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .padding(.leading, 18)
            }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .textSelection(.enabled)
    }

    private var icon: String {
        switch entry.direction {
        case .sent: return "arrow.up"
        case .received: return "arrow.down"
        case .info: return "info.circle"
        }
    }

    private var color: Color {
        switch entry.direction {
        case .sent: return .blue
        case .received: return .green
        case .info: return .secondary
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(
                    LinearGradient(colors: [.orange.opacity(0.9), .pink.opacity(0.8)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "earbuds")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 86, height: 86)

            VStack(spacing: 3) {
                Text("Buds Hub").font(.title2.weight(.bold))
                Text("Version 0.1.0").font(.caption).foregroundStyle(.secondary)
            }

            Text("A native macOS client for Samsung Galaxy Buds. Battery, noise control, equalizer, gestures, find-my-earbuds, diagnostics and a packet inspector — no phone required.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            VStack(spacing: 4) {
                Text("Protocol knowledge from GalaxyBudsClient (GPLv3).")
                Text("UI patterns inspired by BudsControl (MIT).")
                Text("Not affiliated with or endorsed by Samsung.")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            HStack {
                Link("GalaxyBudsClient", destination: URL(string: "https://github.com/timschneeb/GalaxyBudsClient")!)
                Link("BudsControl", destination: URL(string: "https://github.com/amarsakore/BudsControl")!)
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

enum Hex {
    static func clean(_ text: String) -> String {
        text.filter(\.isHexDigit)
    }

    static func bytes(_ text: String) -> [UInt8] {
        let digits = Array(clean(text))
        guard isComplete(text) else { return [] }
        return stride(from: 0, to: digits.count, by: 2).compactMap {
            UInt8(String(digits[$0...$0 + 1]), radix: 16)
        }
    }

    /// True when the text contains complete bytes (an even number of hex digits).
    static func isComplete(_ text: String) -> Bool {
        clean(text).count % 2 == 0
    }
}
