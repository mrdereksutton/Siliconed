// Fork: **the size, picked by aspect ratio and resolution.** A compact pill shows the current
// ratio (its proportional frame and name) and resolution (`1K` or `2K`); clicking it opens a
// visual output popover combining a live 3×3 rule-of-thirds frame preview, visual aspect-ratio
// box tiles, a 1K / 2K resolution selector bar, and custom pixel entry.

import AppKit
import Siliconed
import SwiftUI

/// The ratios offered and the size each takes — upstream's table (`SizeScales`, held by its tests: sides in multiples of 32,
/// so that every model takes them), ordered from tallest to widest. 9:16 and 16:9 are 768 × 1344 and 1344 × 768 at 1K
/// (4:7, the nearest in multiples of 32 near a megapixel, shown as « ≈ 9:16 » and « ≈ 16:9 »), the exact 1440 × 2560 and
/// 2560 × 1440 at 2K.
enum SizeTable {
    /// Tallest to widest.
    static let ratios: [SizeRatio] = SizeScales.portraits.reversed() + [SizeRatio(1, 1)] + SizeScales.landscapes
    static let square = SizeRatio(1, 1)

    /// « 3:4 », or « ≈ 9:16 » where the pixels at this resolution are not quite that proportion.
    static func ratioTitle(_ cell: SizeCell) -> String {
        cell.isApproximate ? "≈ \(cell.ratio)" : cell.ratio.description
    }

    /// The footnote of an approximate proportion, as a tooltip.
    static func approximateHelp(_ cell: SizeCell?) -> Text {
        guard let cell, cell.isApproximate else { return Text("Aspect ratio") }
        let pixels = "\(cell.width) × \(cell.height)"
        let really = cell.actualRatio.description, asked = cell.ratio.description
        let off = cell.deviation.formatted(.percent.precision(.fractionLength(1)))
        return Text("\(pixels) is really \(really), \(off) off \(asked): an exact \(asked) in multiples of 32 has no size near this resolution.")
    }
}

/// **The combined aspect-ratio & resolution pill**, opening the visual Output popover when clicked.
struct SizePills: View {
    @Bindable var app: AppState
    @State private var isPresented = false

    var body: some View {
        let current = app.sizeCell
        Pill(isPresented: $isPresented) {
            if let current {
                RatioShape(ratio: current.ratio, side: 13)
                Text(verbatim: SizeTable.ratioTitle(current)).monospacedDigit()
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Text(verbatim: current.resolution.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                RatioShape(ratio: SizeRatio(max(1, app.format.width), max(1, app.format.height)), side: 13)
                Text(verbatim: "\(app.format.width) × \(app.format.height)").monospacedDigit()
            }
        } choices: {
            OutputSizePopover(app: app) { isPresented = false }
        }
        .help(SizeTable.approximateHelp(current))
    }
}

/// **Combined Visual Output Popover**:
/// - Left: a 3×3 rule-of-thirds composition grid with a live morphing aspect-ratio frame, orientation label, and pixel dimensions.
/// - Right: visual aspect-ratio box tiles (`9:16` through `16:9`) above a full-width `1K / 2K` resolution bar, plus custom `W × H` entry.
struct OutputSizePopover: View {
    @Bindable var app: AppState
    let done: () -> Void
    @State private var hoveredRatio: SizeRatio?
    @State private var hoveredResolution: SizeResolution?
    @State private var showCustom = false

    private var activeRatio: SizeRatio {
        hoveredRatio ?? app.sizeCell?.ratio ?? SizeRatio(max(1, app.format.width), max(1, app.format.height))
    }

    private var activeResolution: SizeResolution {
        hoveredResolution ?? app.sizeCell?.resolution ?? .oneK
    }

    private var previewCell: SizeCell? {
        guard let cell = SizeScales.cell(activeRatio, activeResolution) else { return nil }
        if app.scaleUnavailable(cell) == nil { return cell }
        if let fallback = SizeScales.cell(activeRatio, .oneK), hoveredResolution == nil {
            return fallback
        }
        return cell
    }

    var body: some View {
        let current = app.sizeCell
        let currentResolution = current?.resolution ?? .oneK

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RatioPreviewStage(
                    ratio: activeRatio,
                    cell: previewCell,
                    customFormat: current == nil && hoveredRatio == nil ? app.format : nil,
                    unavailableReason: previewCell.flatMap { app.scaleUnavailable($0) }
                )

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aspect ratio")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 5) {
                            ForEach(SizeTable.ratios, id: \.self) { r in
                                let cell = SizeScales.cell(r, currentResolution)!
                                let fallback = SizeScales.cell(r, .oneK)!
                                let fits = app.scaleUnavailable(cell) == nil
                                let target = fits ? cell : fallback
                                let why = app.scaleUnavailable(target)
                                RatioTile(
                                    ratio: r,
                                    title: SizeTable.ratioTitle(target),
                                    selected: current?.ratio == r,
                                    enabled: why == nil,
                                    helpText: why ?? "\(target.width) × \(target.height)"
                                ) {
                                    app.selectScale(r, target.resolution)
                                } onHoverChange: { inside in
                                    hoveredRatio = inside ? r : (hoveredRatio == r ? nil : hoveredRatio)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolution")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        let ratioForTier = hoveredRatio ?? current?.ratio ?? SizeTable.square
                        HStack(spacing: 6) {
                            ForEach(SizeResolution.allCases, id: \.self) { q in
                                let cell = SizeScales.cell(ratioForTier, q)!
                                let why = app.scaleUnavailable(cell)
                                ResolutionTile(
                                    resolution: q,
                                    pixels: "\(cell.width) × \(cell.height)",
                                    unavailable: why,
                                    selected: current?.resolution == q && current != nil
                                ) {
                                    app.selectScale(ratioForTier, q)
                                } onHoverChange: { inside in
                                    hoveredResolution = inside ? q : (hoveredResolution == q ? nil : hoveredResolution)
                                }
                            }
                        }
                        .help("1K is about 1 megapixel, 2K about 4")
                    }
                }
            }

            Divider()

            DisclosureGroup(isExpanded: $showCustom) {
                CustomSize(app: app, title: "Size", done: done)
                    .padding(.top, 4)
            } label: {
                HStack(spacing: 6) {
                    Text("Custom size")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if current == nil {
                        Text(verbatim: "\(app.format.width) × \(app.format.height)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(14)
        .onAppear {
            showCustom = app.sizeCell == nil
        }
    }
}

/// **The 3×3 rule-of-thirds composition stage** that morphs to preview the hovered or selected aspect ratio.
private struct RatioPreviewStage: View {
    let ratio: SizeRatio
    let cell: SizeCell?
    let customFormat: RecommendedFormat?
    let unavailableReason: String?

    private var orientationLabel: LocalizedStringKey {
        if customFormat != nil { return "Custom" }
        switch ratio.orientation {
        case .square: return "Square"
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        }
    }

    var body: some View {
        let gridSide: CGFloat = 108
        let maxFrame: CGFloat = 80
        let wRatio = CGFloat(max(1, ratio.width))
        let hRatio = CGFloat(max(1, ratio.height))
        let frameW = wRatio >= hRatio ? maxFrame : max(18, maxFrame * wRatio / hRatio)
        let frameH = hRatio >= wRatio ? maxFrame : max(18, maxFrame * hRatio / wRatio)

        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))

                // 3×3 rule-of-thirds grid lines
                Canvas { context, size in
                    let thirdW = size.width / 3
                    let thirdH = size.height / 3
                    var path = Path()
                    for i in 1...2 {
                        let x = thirdW * CGFloat(i)
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        let y = thirdH * CGFloat(i)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(.primary.opacity(0.08)), lineWidth: 0.75)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.hairline)

                // Morphing aspect ratio frame
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.9), lineWidth: 1.6)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                    .frame(width: frameW, height: frameH)
                    .animation(Motion.pick(.spring(response: 0.24, dampingFraction: 0.78)), value: ratio)
            }
            .frame(width: gridSide, height: gridSide)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(orientationLabel)
                    if let cell {
                        Text(verbatim: "· \(SizeTable.ratioTitle(cell))").monospacedDigit()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

                if let unavailableReason {
                    Text(verbatim: unavailableReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let cell {
                    Text(verbatim: "\(cell.width) × \(cell.height)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if let customFormat {
                    Text(verbatim: "\(customFormat.width) × \(customFormat.height)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.hairline)
        )
    }
}

/// **A visual aspect-ratio box tile** (`9:16`, `2:3`, `3:4`, `4:5`, `1:1`, `5:4`, `4:3`, `3:2`, `16:9`) with its proportional frame above the ratio label.
private struct RatioTile: View {
    let ratio: SizeRatio
    let title: String
    let selected: Bool
    let enabled: Bool
    let helpText: String
    let action: () -> Void
    let onHoverChange: (Bool) -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RatioShape(ratio: ratio, side: 18, filled: selected)
                    .frame(height: 20)
                Text(verbatim: title)
                    .font(.caption2.weight(selected ? .semibold : .medium).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 44, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.16)
                                   : hovering ? Color.primary.opacity(0.09) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Color.primary.opacity(0.65)
                                           : hovering ? Color.primary.opacity(0.25) : Palette.hairline,
                                  lineWidth: selected ? 1.4 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
        .onHover { inside in
            hovering = inside && enabled
            onHoverChange(inside)
        }
        .help(Text(verbatim: helpText))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// **A segment of the full-width Resolution bar** (`1K` or `2K`).
private struct ResolutionTile: View {
    let resolution: SizeResolution
    let pixels: String
    let unavailable: String?
    let selected: Bool
    let action: () -> Void
    let onHoverChange: (Bool) -> Void
    @State private var hovering = false

    var enabled: Bool { unavailable == nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(verbatim: resolution.rawValue)
                    .font(.callout.weight(.semibold))
                Text(verbatim: unavailable ?? pixels)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.16)
                                   : hovering ? Color.primary.opacity(0.09) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Color.primary.opacity(0.65)
                                           : hovering ? Color.primary.opacity(0.25) : Palette.hairline,
                                  lineWidth: selected ? 1.4 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { inside in
            hovering = inside && enabled
            onHoverChange(inside)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A ratio's shape, fitted in a square of `side` points.
struct RatioShape: View {
    let ratio: SizeRatio
    var side: CGFloat = 14
    var filled = false

    var body: some View {
        let w = ratio.width >= ratio.height ? side : max(4, side * CGFloat(ratio.width) / CGFloat(ratio.height))
        let h = ratio.height >= ratio.width ? side : max(4, side * CGFloat(ratio.height) / CGFloat(ratio.width))
        RoundedRectangle(cornerRadius: max(2, side / 6), style: .continuous)
            .fill(Color.primary.opacity(filled ? 0.18 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: max(2, side / 6), style: .continuous)
                    .strokeBorder(.primary, lineWidth: 1.3)
            )
            .frame(width: w, height: h)
            .frame(width: side, height: side)
    }
}

// MARK: - Pills & Lists

/// **A pill's face**: an icon and a word on a soft rounded plate, brighter under the pointer or open.
struct PillFace<Content: View>: View {
    var active = false
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) { content }
            .font(.callout)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(hovering || active ? 0.14 : 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.hairline))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(Motion.pick(.easeOut(duration: 0.12)), value: hovering)
    }
}

/// A pill that shows only the current choice; its list opens over it on a click.
struct Pill<Label: View, Choices: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var label: Label
    @ViewBuilder var choices: Choices

    var body: some View {
        Button { isPresented.toggle() } label: { PillFace(active: isPresented) { label } }
            .buttonStyle(.plain)
            // Above the pill: the composer sits at the foot of the window.
            .popover(isPresented: $isPresented, arrowEdge: .top) { choices }
    }
}

/// A pill that acts at once.
struct PillButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) { PillFace { label } }
            .buttonStyle(.plain)
    }
}

/// **A list of choices**: its title, then one row per choice.
struct ChoiceList<Rows: View>: View {
    let title: LocalizedStringKey
    var minWidth: CGFloat = 170
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .padding(.bottom, 4)
            rows
        }
        .padding(8)
        .frame(minWidth: minWidth, maxWidth: .infinity, alignment: .leading)
    }
}

/// A choice: what it is, and a check when it is the current one; lit under the pointer.
struct ChoiceRow<Label: View>: View {
    let selected: Bool
    let enabled: Bool
    let pick: () -> Void
    @ViewBuilder var label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 10) {
                label
                Spacer(minLength: 12)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(selected ? 1 : 0)
            }
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(hovering ? 0.22 : 0.14)
                               : hovering ? Color.primary.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { hovering = $0 && enabled }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
