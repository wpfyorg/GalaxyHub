import SwiftUI
import BudsKit

/// Follows the system default output so the "Mac" indicator stays true while
/// the buds are selected, "Other" when the route moves elsewhere, and never
/// guesses that the phone is the source.
@MainActor
private final class AudioSourceModel: ObservableObject {
    @Published private(set) var macIsSource = false
    private var observer: DefaultOutputObserver?
    private weak var controller: BudsController?

    func bind(controller: BudsController) {
        self.controller = controller
        refresh()
        guard observer == nil else { return }
        observer = DefaultOutputObserver { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        observer?.start()
    }

    func refresh() {
        guard let controller else { return }
        guard let output = MacAudioRouter.defaultOutputName else {
            macIsSource = false
            return
        }
        let names = [controller.deviceName, controller.model?.displayName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        macIsSource = names.contains { output.localizedCaseInsensitiveContains($0) }
    }

    deinit {
        observer?.stop()
    }
}

/// The popover's short "More" panel: only the things worth changing without
/// opening Settings. Advanced sound, gesture and device controls live in the
/// Controls settings tab.
struct MoreControls: View {
    @ObservedObject var buds: BudsController
    @Environment(\.openWindow) private var openWindow
    @StateObject private var audioSource = AudioSourceModel()
    @State private var allControlsHovered = false

    var body: some View {
        VStack(spacing: 10) {
            if buds.has(.equalizer) {
                EqualizerCard(buds: buds)
            }
            audioQuickCard
            if buds.has(.findMyBuds) {
                findQuickCard
            }
            allControlsLink
        }
    }

    private var audioQuickCard: some View {
        Card {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Audio focus")
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        HStack(spacing: 3) {
                            Circle()
                                .fill(audioSource.macIsSource ? Color.green : Color.secondary.opacity(0.45))
                                .frame(width: 6, height: 6)
                            Text(audioSource.macIsSource ? "Mac" : "Other")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement()
                        .accessibilityLabel(audioSource.macIsSource ? "This Mac is the audio source"
                                                        : "Audio is routed to another device")
                        .animation(.easeInOut(duration: 0.2), value: audioSource.macIsSource)
                    }
                    Text("Take audio back from the phone")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button("Use this Mac") {
                    buds.claimMacAudio()
                    audioSource.refresh()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Use this Mac for audio (⌃⌥M)")
            }
        }
        .onAppear { audioSource.bind(controller: buds) }
        .onChange(of: buds.link) { _, _ in audioSource.refresh() }
    }

    private var findQuickCard: some View {
        Card {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(buds.findMyBudsActive ? Color.red : Color.secondary)
                    .symbolEffect(.pulse, isActive: buds.findMyBudsActive)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Find my earbuds").font(.body.weight(.medium))
                    Text(buds.findMyBudsActive ? "Playing a sound…" : "Only when they are nearby")
                        .font(.subheadline).foregroundStyle(.secondary)
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
        .animation(.easeInOut(duration: 0.2), value: buds.findMyBudsActive)
    }

    private var allControlsLink: some View {
        Button {
            UserDefaults.standard.set("controls", forKey: "settingsTab")
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title.contains("Settings") {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("All controls…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(allControlsHovered ? 0.05 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { allControlsHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: allControlsHovered)
        .accessibilityLabel("All controls")
    }
}
