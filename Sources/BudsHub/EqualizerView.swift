import SwiftUI
import BudsKit

struct EqualizerCard: View {
    @ObservedObject var buds: BudsController
    @State private var draft: [Int] = Array(repeating: 0, count: 9)
    /// Visibility of the custom band editor, separate from whether the user
    /// has actually changed the curve.
    @State private var showCustomEditor = false
    /// True only after a slider/Reset edit; incoming device tables are ignored
    /// while the draft is dirty.
    @State private var draftDirty = false

    private let bandLabels = ["60", "120", "250", "500", "1k", "2k", "4k", "8k", "12k"]
    private let columns = [GridItem(.adaptive(minimum: 66), spacing: 6)]

    var body: some View {
        Card(title: "Equalizer", symbol: "slider.vertical.3") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: columns, spacing: 6) {
                    chip("Off", selected: buds.eqSelection == .off && !showCustomEditor) {
                        buds.setEQOff()
                        showCustomEditor = false
                        draftDirty = false
                    }
                    ForEach(0..<BudsController.presetNames.count, id: \.self) { index in
                        chip(BudsController.presetNames[index],
                             selected: buds.eqSelection == .preset(index) && !showCustomEditor) {
                            buds.selectEQPreset(index)
                            showCustomEditor = false
                            draftDirty = false
                        }
                    }
                    if buds.has(.customEqualizer) {
                        chip("Custom", selected: buds.eqSelection == .custom || showCustomEditor) {
                            showCustomEditor = true
                            if !draftDirty { draft = incomingBands }
                        }
                    }
                }

                if buds.has(.customEqualizer) && (showCustomEditor || buds.eqSelection == .custom) {
                    Divider().opacity(0.5)
                    HStack(spacing: 4) {
                        ForEach(0..<9, id: \.self) { index in
                            VStack(spacing: 3) {
                                Text(gainLabel(draft[index]))
                                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                                    .foregroundStyle(draft[index] == 0 ? .secondary : .primary)
                                BandSlider(value: draft[index], range: -10...10) { value in
                                    draft[index] = value
                                    draftDirty = true
                                }
                                .frame(height: 64)
                                .accessibilityLabel("\(bandLabels[index]) hertz")
                                .accessibilityValue("\(draft[index]) decibels")
                                .accessibilityAdjustableAction { direction in
                                    let delta = direction == .increment ? 1 : -1
                                    draft[index] = min(10, max(-10, draft[index] + delta))
                                    draftDirty = true
                                }
                                Text(bandLabels[index])
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    HStack(spacing: 8) {
                        Button("Reset") {
                            draft = Array(repeating: 0, count: 9)
                            draftDirty = true
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        Spacer()
                        Button("Apply") {
                            buds.applyCustomEQ(bands: draft)
                            draftDirty = false
                            showCustomEditor = false
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                    }
                    .font(.callout)
                }
            }
            .onAppear {
                draft = incomingBands
                showCustomEditor = buds.eqSelection == .custom
                draftDirty = false
            }
            .onChange(of: buds.customEQBands) { _, bands in
                if !draftDirty { draft = Self.normalized(bands) }
            }
            .onChange(of: buds.eqSelection) { _, selection in
                if case .custom = selection {
                    showCustomEditor = true
                    if !draftDirty { draft = incomingBands }
                }
            }
        }
    }

    private var incomingBands: [Int] {
        Self.normalized(buds.customEQBands)
    }

    private static func normalized(_ bands: [Int]) -> [Int] {
        guard bands.count == 9 else { return Array(repeating: 0, count: 9) }
        return bands
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 26)
            .background {
                Capsule().fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            }
            .overlay {
                Capsule().strokeBorder(selected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06),
                                       lineWidth: 0.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.18), value: selected)
    }

    private func gainLabel(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

private struct BandSlider: View {
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let span = CGFloat(range.upperBound - range.lowerBound)
            let y = { (v: Int) in height * CGFloat(range.upperBound - v) / span }
            ZStack(alignment: .top) {
                Capsule().fill(Color.primary.opacity(0.10)).frame(width: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: abs(y(value) - y(0)))
                    .offset(y: min(y(value), y(0)))
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                    .frame(width: 11, height: 11)
                    .offset(y: y(value) - 5.5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = min(max(drag.location.y / height, 0), 1)
                        let next = range.upperBound - Int((fraction * span).rounded())
                        if next != value { onChange(next) }
                    }
            )
        }
        .animation(.snappy(duration: 0.1), value: value)
    }
}
