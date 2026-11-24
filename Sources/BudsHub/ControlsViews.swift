import SwiftUI
import BudsKit

/// Advanced controls shown in the Controls settings tab. Keeping these out of
/// the popover is deliberate: the menu bar is for the two or three things people
/// change daily, not every firmware switch.
struct AudioSettingsCard: View {
    @ObservedObject var buds: BudsController

    var body: some View {
        Card(title: "Audio focus", symbol: "hifispeaker.2") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Use this Mac for audio").font(.caption.weight(.medium))
                        Text("The buds follow the last device that starts audio")
                            .font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button("Take audio") { buds.claimMacAudio() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
                ToggleRow(title: "Claim when Mac media plays",
                          subtitle: "Watch Now Playing and take audio focus automatically",
                          symbol: "music.note",
                          isOn: Binding(get: { buds.autoClaimAudio },
                                        set: { buds.autoClaimAudio = $0 }))
                Text("macOS uses AAC or SBC. Samsung SSC 24-bit is only available from a Galaxy phone.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SoundSettingsCard: View {
    @ObservedObject var buds: BudsController

    var body: some View {
        Card(title: "Sound", symbol: "waveform") {
            VStack(spacing: 7) {
                if buds.has(.ambientVolume), let max = buds.model?.ambientVolumeMax, max > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.1").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text("Ambient volume").font(.caption)
                        Slider(value: Binding(get: { Double(buds.ambientVolume) },
                                              set: { buds.setAmbientVolume(Int($0.rounded())) }),
                               in: 0...Double(max), step: 1)
                            .controlSize(.mini)
                        Text("\(buds.ambientVolume)/\(max)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Divider().opacity(0.5)
                }

                if buds.has(.ambientCustomize) {
                    ToggleRow(title: "Custom ambient sound",
                              subtitle: "Tune each ear and the tone",
                              symbol: "slider.horizontal.3",
                              isOn: Binding(get: { buds.ambientCustomEnabled },
                                            set: { buds.setAmbientCustom(enabled: $0) }))
                    if buds.ambientCustomEnabled {
                        HStack(spacing: 10) {
                            Stepper("L \(buds.ambientCustomLeft)", value: Binding(
                                get: { buds.ambientCustomLeft },
                                set: { buds.setAmbientCustom(enabled: true, left: $0) }), in: 0...(buds.model?.ambientVolumeMax ?? 2))
                            Stepper("R \(buds.ambientCustomRight)", value: Binding(
                                get: { buds.ambientCustomRight },
                                set: { buds.setAmbientCustom(enabled: true, right: $0) }), in: 0...(buds.model?.ambientVolumeMax ?? 2))
                        }
                        .font(.caption2)
                        .controlSize(.mini)
                    }
                }

                if buds.has(.sidetone) {
                    ToggleRow(title: "Sidetone", subtitle: "Hear your own voice on calls",
                              symbol: "phone.arrow.up.right",
                              isOn: Binding(get: { buds.sidetone }, set: { buds.setSidetone($0) }))
                }
                if buds.has(.extraHighAmbient) {
                    ToggleRow(title: "Extra-high ambient", subtitle: "Boost outside sound",
                              symbol: "speaker.plus",
                              isOn: Binding(get: { buds.extraHighAmbient }, set: { buds.setExtraHighAmbient($0) }))
                }
                if buds.has(.detectConversations) {
                    ToggleRow(title: "Detect conversations",
                              subtitle: "Switch to ambient when you talk",
                              symbol: "person.wave.2",
                              isOn: Binding(get: { buds.detectConversations },
                                            set: { buds.setDetectConversations($0) }))
                    if buds.detectConversations {
                        MenuRow(title: "Resume after", value: durationLabel, options: ["5 seconds", "10 seconds", "15 seconds"]) {
                            buds.setDetectConversationsDuration($0)
                        }
                    }
                }
                if buds.has(.adaptiveVolume) {
                    ToggleRow(title: "Adaptive volume", subtitle: "Match loudness to your surroundings",
                              symbol: "ear.badge.waveform",
                              isOn: Binding(get: { buds.adaptiveVolume }, set: { buds.setAdaptiveVolume($0) }))
                }
                if buds.has(.sirenDetect) {
                    ToggleRow(title: "Siren detect", subtitle: "Lower noise cancellation for sirens",
                              symbol: "light.beacon.max",
                              isOn: Binding(get: { buds.sirenDetect }, set: { buds.setSirenDetect($0) }))
                }
                if buds.has(.autoPause) {
                    ToggleRow(title: "Pause when one earbud is removed",
                              symbol: "pause.circle",
                              isOn: Binding(get: { buds.autoPause }, set: { buds.setAutoPause($0) }))
                }
                if buds.has(.ancWithOneEarbud) {
                    ToggleRow(title: "Noise control with one earbud",
                              symbol: "earbuds",
                              isOn: Binding(get: { buds.ancWithOneEarbud }, set: { buds.setANCWithOneEarbud($0) }))
                }
                if buds.has(.speakSeamlessly) {
                    ToggleRow(title: "Speak seamlessly", subtitle: "Relay your voice to the call",
                              symbol: "waveform.and.person.filled",
                              isOn: Binding(get: { buds.speakSeamlessly }, set: { buds.setSpeakSeamlessly($0) }))
                }
                if buds.has(.seamlessConnection) {
                    ToggleRow(title: "Seamless connection",
                              subtitle: "Hand audio between the earbuds automatically",
                              symbol: "arrow.triangle.2.circlepath",
                              isOn: Binding(get: { buds.seamlessConnection },
                                            set: { buds.setSeamlessConnection($0) }))
                }
                if buds.has(.spatialAudio) {
                    ToggleRow(title: "Spatial audio", symbol: "spatial.audio",
                              isOn: Binding(get: { buds.spatialAudio }, set: { buds.setSpatialAudio($0) }))
                }
                if buds.has(.headTracking) {
                    ToggleRow(title: "Head tracking", subtitle: "Keep sound fixed in space",
                              symbol: "airpods.gen3",
                              isOn: Binding(get: { buds.headTracking }, set: { buds.setHeadTracking($0) }))
                }
            }
        }
    }

    private var durationLabel: String {
        switch buds.detectConversationsDuration {
        case 1: return "10 seconds"
        case 2: return "15 seconds"
        default: return "5 seconds"
        }
    }
}

struct GesturesSettingsCard: View {
    @ObservedObject var buds: BudsController

    var body: some View {
        Card(title: "Gestures", symbol: "hand.tap") {
            VStack(spacing: 7) {
                if buds.has(.touchLock) {
                    ToggleRow(title: "Lock touchpad", subtitle: "Ignore taps on both earbuds",
                              symbol: "lock",
                              isOn: Binding(get: { buds.touchLocked }, set: { buds.setTouchpadLocked($0) }))
                }

                if buds.has(.advancedTouch) {
                    ToggleRow(title: "Single tap", symbol: "hand.point.up",
                              isOn: Binding(get: { buds.touchSingleTap }, set: { buds.setTouchGesture(single: $0) }))
                    ToggleRow(title: "Double tap", symbol: "hand.tap",
                              isOn: Binding(get: { buds.touchDoubleTap }, set: { buds.setTouchGesture(double: $0) }))
                    ToggleRow(title: "Triple tap", symbol: "hand.tap.fill",
                              isOn: Binding(get: { buds.touchTripleTap }, set: { buds.setTouchGesture(triple: $0) }))
                    ToggleRow(title: "Touch and hold", symbol: "hand.point.up.left",
                              isOn: Binding(get: { buds.touchHold }, set: { buds.setTouchGesture(hold: $0) }))
                    if buds.has(.swipeGesture) {
                        ToggleRow(title: "Volume swipe", symbol: "hand.draw",
                                  isOn: Binding(get: { buds.touchSwipe }, set: { buds.setTouchGesture(swipe: $0) }))
                    }
                    if buds.has(.callGestures) {
                        ToggleRow(title: "Double tap during calls", symbol: "phone",
                                  isOn: Binding(get: { buds.touchDoubleTapDuringCall },
                                                set: { buds.setTouchGesture(doubleDuringCall: $0) }))
                        ToggleRow(title: "Hold during calls", symbol: "phone.badge.waveform",
                                  isOn: Binding(get: { buds.touchHoldDuringCall },
                                                set: { buds.setTouchGesture(holdDuringCall: $0) }))
                    }
                }

                if buds.has(.doubleTapVolume) {
                    ToggleRow(title: "Double-tap side to change volume",
                              symbol: "speaker.wave.2",
                              isOn: Binding(get: { buds.doubleTapVolume }, set: { buds.setDoubleTapVolume($0) }))
                }

                if let model = buds.model, !model.availableTouchActions.isEmpty {
                    Divider().opacity(0.5)
                    let actions = model.availableTouchActions
                    MenuRow(title: "Touch & hold left", value: buds.touchLeftAction.title,
                            options: actions.map(\.title)) { index in
                        buds.setTouchAction(actions[index], left: true)
                    }
                    MenuRow(title: "Touch & hold right", value: buds.touchRightAction.title,
                            options: actions.map(\.title)) { index in
                        buds.setTouchAction(actions[index], left: false)
                    }
                }

                if buds.has(.noiseControlCycle) {
                    Divider().opacity(0.5)
                    HStack {
                        Text("Touch & hold cycles").font(.caption)
                        Spacer()
                        Text(cycleDescription).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var cycleDescription: String {
        let bits = buds.cycleBitsRight
        var modes: [String] = []
        if bits & 0x01 != 0 { modes.append("Ambient") }
        if bits & 0x02 != 0 { modes.append("Adaptive") }
        if bits & 0x04 != 0 { modes.append("Off") }
        if bits & 0x08 != 0 { modes.append("ANC") }
        return modes.isEmpty ? "—" : modes.joined(separator: " ↔ ")
    }
}

struct FindAndFitCard: View {
    @ObservedObject var buds: BudsController

    var body: some View {
        Card(title: "Find & fit", symbol: "location.magnifyingglass") {
            VStack(spacing: 8) {
                if buds.has(.findMyBuds) {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Find my earbuds").font(.caption.weight(.medium))
                            Text(buds.findMyBudsActive ? "Playing a sound…" : "Loud — take them out of your ears first")
                                .font(.caption2).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Button(buds.findMyBudsActive ? "Stop" : "Play") {
                            buds.setFindMyBuds(active: !buds.findMyBudsActive)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(buds.findMyBudsActive ? .red : nil)
                    }
                }

                if buds.has(.fitTest) {
                    Divider().opacity(0.5)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Fit test").font(.caption.weight(.medium))
                            if let result = buds.fitResult {
                                Text("Left \(fitText(result.left)) · Right \(fitText(result.right))")
                                    .font(.caption2)
                                    .foregroundStyle(result.left == 1 && result.right == 1 ? .green : .secondary)
                            } else {
                                Text("Check the seal in each ear").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 4)
                        Button("Test") { buds.runFitTest() }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }

                if let multipoint = buds.multipoint, multipoint.supported {
                    Divider().opacity(0.5)
                    HStack {
                        Text("Multipoint").font(.caption)
                        Spacer()
                        Text(multipoint.haveDevices ? "Connected to multiple devices" : "Single device")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func fitText(_ value: Int) -> String {
        switch value {
        case 1: return "Good"
        case 0: return "Bad"
        default: return "Failed"
        }
    }
}

struct DeviceSettingsCard: View {
    @ObservedObject var buds: BudsController

    var body: some View {
        Card(title: "Device", symbol: "info.circle") {
            VStack(spacing: 3) {
                KeyValueRow(key: "Model", value: buds.model?.displayName ?? buds.detectedModel?.displayName ?? "Detecting…")
                if let firmware = buds.deviceInfo.firmwareLeft {
                    KeyValueRow(key: "Firmware", value: firmware, mono: true)
                }
                if let sku = buds.deviceInfo.skuLeft {
                    KeyValueRow(key: "SKU", value: sku, mono: true)
                }
                if let build = buds.deviceInfo.build {
                    KeyValueRow(key: "Build", value: build, mono: true)
                }
                if let address = buds.address {
                    KeyValueRow(key: "Address", value: address.uppercased(), mono: true)
                }
                if buds.revision > 0 {
                    KeyValueRow(key: "Status revision", value: "\(buds.revision)")
                }
                if let batteryType = buds.batteryType {
                    KeyValueRow(key: "Battery type", value: batteryType)
                }
            }
        }
    }
}
