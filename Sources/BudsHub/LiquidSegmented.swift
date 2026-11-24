import SwiftUI

/// A segmented control that moves like the macOS 26 system one: a soft pill that
/// lifts and stretches as it glides to the new segment, then settles.
struct LiquidSegmented<Item: Hashable & Identifiable, Content: View>: View {
    let items: [Item]
    let selection: Item?
    var height: CGFloat = 30
    let onSelect: (Item) -> Void
    @ViewBuilder let label: (Item, Bool) -> Content
    var widthFor: (Item, Bool) -> CGFloat? = { _, _ in nil }
    var fitToLabels = false

    @Namespace private var space
    @State private var hovered: Item?

    var body: some View {
        Group {
            if fitToLabels {
                EvenGapsLayout { segments }
            } else {
                HStack(spacing: 0) { segments }
            }
        }
        .background { if let selection { pill(following: selection) } }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: selection)
        .animation(.easeOut(duration: 0.15), value: hovered)
    }

    private var segments: some View {
        ForEach(items) { item in
            let selected = item == selection
            Button { onSelect(item) } label: {
                label(item, selected)
                    .phaseAnimator(BubblePhase.allCases, trigger: selection) { content, phase in
                        content.scaleEffect(selected && phase == .lifted ? 1.10 : 1)
                    } animation: { $0.animation }
                    .frame(maxWidth: widthFor(item, selected) ?? .infinity, minHeight: height)
                    .padding(.horizontal, fitToLabels ? 7 : 4)
                    .background {
                        ZStack {
                            if hovered == item && !selected {
                                Capsule().fill(Color.primary.opacity(0.06))
                            }
                            Capsule().fill(.clear).matchedGeometryEffect(id: item, in: space)
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { hovered = item } else if hovered == item { hovered = nil }
            }
        }
    }

    private func pill(following item: Item) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.16))
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.04)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75)
            )
            .phaseAnimator(BubblePhase.allCases, trigger: selection) { pill, phase in
                pill
                    .scaleEffect(phase == .lifted ? CGSize(width: 1.06, height: 1.28) : CGSize(width: 1, height: 1))
                    .brightness(phase == .lifted ? 0.1 : 0)
                    .shadow(color: .black.opacity(phase == .lifted ? 0.32 : 0.15),
                            radius: phase == .lifted ? 7 : 2, y: phase == .lifted ? 3 : 1)
            } animation: { $0.animation }
            .matchedGeometryEffect(id: item, in: space, isSource: false)
            .allowsHitTesting(false)
    }
}

private enum BubblePhase: CaseIterable {
    case resting, lifted, settled

    var animation: Animation {
        switch self {
        case .resting: return .spring(response: 0.28, dampingFraction: 0.72)
        case .lifted: return .spring(response: 0.22, dampingFraction: 0.62)
        case .settled: return .spring(response: 0.34, dampingFraction: 0.82)
        }
    }
}

private struct EvenGapsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(width: proposal.width ?? ideals.reduce(0) { $0 + $1.width },
                      height: ideals.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        let total = ideals.reduce(0, +)
        let extra = (bounds.width - total) / CGFloat(subviews.count)
        var x = bounds.minX
        for (subview, ideal) in zip(subviews, ideals) {
            let width = extra >= 0 ? ideal + extra : ideal * bounds.width / total
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width
        }
    }
}
