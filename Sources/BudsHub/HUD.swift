import AppKit
import BudsKit
import SwiftUI

final class HUD {
    static let shared = HUD()

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var generation = 0

    func show(mode: NoiseMode, level: Bool?, battery: Int?, deviceName: String) {
        let detail: String
        if mode == .anc, let level {
            detail = level ? "High level" : "Low level"
        } else {
            detail = deviceName
        }
        show(title: mode.title, symbol: mode.symbol, subtitle: detail, battery: battery,
             tinted: mode != .off)
    }

    func show(title: String, symbol: String, subtitle: String, battery: Int?, tinted: Bool = true) {
        generation += 1
        let generation = self.generation
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let host = NSHostingView(rootView: HUDView(title: title, symbol: symbol, subtitle: subtitle,
                                                   battery: battery, tinted: tinted))
        var size = host.fittingSize
        if size.width < 120 || size.height < 40 {
            size = NSSize(width: 320, height: 78)
        }
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.minY + 120,
                                  width: size.width, height: size.height), display: true)
        }

        hideWork?.cancel()
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { [weak self, weak panel] in
            guard let self, let panel, self.generation == generation else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, self.generation == generation else { return }
                panel.orderOut(nil)
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        return panel
    }
}

private struct HUDView: View {
    let title: String
    let symbol: String
    let subtitle: String
    let battery: Int?
    let tinted: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 44, height: 44)
                .tintedCircleGlass(tinted ? .accentColor : nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                HStack(spacing: 6) {
                    Text(subtitle)
                    if let battery {
                        Text("·")
                        Text("\(battery)%")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 24)
        .padding(.vertical, 12)
        .capsuleGlass()
        .padding(20)
    }
}
