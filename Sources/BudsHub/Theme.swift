import SwiftUI
import BudsKit

// MARK: - Glass / material helpers (macOS 14+ with macOS 26 Liquid Glass when available)

struct GlassBox<Content: View>: View {
    var spacing: CGFloat = 0
    @ViewBuilder var content: () -> Content

    @ViewBuilder var body: some View {
        if #available(macOS 26.0, *) {
            SwiftUICore.GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

struct AdaptiveGlassButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            Button(configuration).buttonStyle(SwiftUI.GlassButtonStyle())
        } else {
            Button(configuration).buttonStyle(.bordered)
        }
    }
}

struct AdaptiveGlassProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            Button(configuration).buttonStyle(SwiftUI.GlassProminentButtonStyle())
        } else {
            Button(configuration).buttonStyle(.borderedProminent)
        }
    }
}

extension PrimitiveButtonStyle where Self == AdaptiveGlassButtonStyle {
    static var glass: AdaptiveGlassButtonStyle { AdaptiveGlassButtonStyle() }
}

extension PrimitiveButtonStyle where Self == AdaptiveGlassProminentButtonStyle {
    static var glassProminent: AdaptiveGlassProminentButtonStyle { AdaptiveGlassProminentButtonStyle() }
}

extension View {
    @ViewBuilder
    func circleGlass(interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .circle)
            } else {
                self.glassEffect(.regular, in: .circle)
            }
        } else {
            self
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func tintedCircleGlass(_ tint: Color?) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint ?? .clear), in: .circle)
        } else {
            self
                .background(Circle().fill(tint ?? Color.secondary.opacity(0.15)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func capsuleGlass() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
    }

    @ViewBuilder
    func roundedRectGlass(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}

// MARK: - Cards and rows

struct Card<Content: View>: View {
    var title: String?
    var symbol: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                    }
                    Text(title).font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .frame(minHeight: 30)
    }
}

struct MenuRow: View {
    let title: String
    let value: String
    let options: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.body)
            Spacer(minLength: 6)
            Menu {
                ForEach(options.indices, id: \.self) { index in
                    Button(options[index]) { onSelect(index) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(value).font(.body.weight(.medium)).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
        }
        .frame(minHeight: 30)
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var mono = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(mono ? .body.monospaced() : .body)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(minHeight: 22)
    }
}

// MARK: - Mode presentation (UI only)

extension NoiseMode {
    var symbol: String {
        switch self {
        case .off: return "speaker.slash"
        case .anc: return "waveform.path.ecg"
        case .ambient: return "ear"
        case .adaptive: return "wand.and.stars"
        }
    }
}

extension Placement {
    var title: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .wearing: return "In ear"
        case .idle: return "Out of ear"
        case .inCase: return "In case"
        case .closedCase: return "Case closed"
        case .charging: return "Charging"
        }
    }
}
