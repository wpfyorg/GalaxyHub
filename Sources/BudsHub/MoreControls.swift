import SwiftUI
import BudsKit

/// The popover's short "More" panel: only the things worth changing without
/// opening Settings. Advanced sound, gesture and device controls live in the
/// Controls settings tab.
struct MoreControls: View {
    @ObservedObject var buds: BudsController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 8) {
            if buds.has(.equalizer) {
                EqualizerCard(buds: buds)
            }
            audioQuickCard
            if buds.has(.findMyBuds) {
                findQuickCard
            }
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
                Text("All controls…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var audioQuickCard: some View {
        Card {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Audio focus").font(.caption.weight(.medium))
                    Text("Take multipoint audio from the phone")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button("Use this Mac") { buds.claimMacAudio() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
        }
    }

    private var findQuickCard: some View {
        Card {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Find my earbuds").font(.caption.weight(.medium))
                    Text(buds.findMyBudsActive ? "Playing a sound…" : "Only when they are nearby")
                        .font(.caption2).foregroundStyle(.secondary)
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
    }
}
