// Fork: **the size, picked by aspect ratio and resolution.** Two compact pills show only the current
// ratio (its shape and name) and the current resolution; each opens its full list when clicked, the
// other choices staying out of sight until then. 1K is about a megapixel, 2K about four. The pair names
// a size in `SizeTable`; a size typed by hand shows its pixels instead. An edit keeps image 1's framing,
// as upstream.

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

/// **The ratio and the resolution as two pills**, each opening its list only when clicked; under the
/// ratios, a size typed by hand.
struct SizePills: View {
    @Bindable var app: AppState
    @State private var choosingRatio = false
    @State private var choosingTier = false

    var body: some View {
        let current = app.sizeCell
        HStack(spacing: 8) {
            Pill(isPresented: $choosingRatio) {
                if let current {
                    RatioShape(ratio: current.ratio, side: 13)
                    Text(verbatim: SizeTable.ratioTitle(current)).monospacedDigit()
                } else {
                    Text(verbatim: "\(app.format.width) × \(app.format.height)").monospacedDigit()
                }
            } choices: {
                VStack(alignment: .leading, spacing: 0) {
                    RatioChoices(app: app) { choosingRatio = false }
                    Divider().padding(.horizontal, 14)
                    CustomSize(app: app, title: "Custom size") { choosingRatio = false }
                }
            }
            .help(SizeTable.approximateHelp(current))
            if let current {
                Pill(isPresented: $choosingTier) {
                    Image(systemName: "diamond").imageScale(.small)
                    Text(verbatim: current.resolution.rawValue)
                } choices: {
                    TierChoices(app: app) { choosingTier = false }
                }
                .help("1K is about 1 megapixel, 2K about 4")
            }
        }
    }
}

/// **The aspect ratios**, tallest to widest, each with its shape; a ratio beyond this Mac's memory or
/// the model's side limit at the current resolution falls back to 1K, one unavailable at 1K too is greyed
/// with its reason (`scaleUnavailable`).
struct RatioChoices: View {
    @Bindable var app: AppState
    let done: () -> Void

    var body: some View {
        let current = app.sizeCell
        let resolution = current?.resolution ?? .oneK
        ChoiceList(title: "Aspect ratio") {
            ForEach(SizeTable.ratios, id: \.self) { r in
                let cell = SizeScales.cell(r, resolution)!
                let fallback = SizeScales.cell(r, .oneK)!
                let fits = app.scaleUnavailable(cell) == nil
                let target = fits ? cell : fallback
                let why = app.scaleUnavailable(target)
                ChoiceRow(selected: current?.ratio == r, enabled: why == nil) {
                    app.selectScale(r, target.resolution)
                    done()
                } label: {
                    RatioShape(ratio: r, side: 14)
                    Text(verbatim: SizeTable.ratioTitle(target)).monospacedDigit().frame(width: 48, alignment: .leading)
                    if let why {
                        Text(verbatim: why).foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: "\(target.width) × \(target.height)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// **The resolutions** at the current ratio: 1K about a megapixel, 2K about four — with the pixels, or
/// why a resolution is greyed (the model's side limit or the Mac it needs: `scaleUnavailable`).
struct TierChoices: View {
    @Bindable var app: AppState
    let done: () -> Void

    var body: some View {
        let current = app.sizeCell
        let resolution = current?.resolution ?? .oneK
        let ratio = current?.ratio ?? SizeTable.square
        ChoiceList(title: "Resolution") {
            ForEach(SizeResolution.allCases, id: \.self) { q in
                let cell = SizeScales.cell(ratio, q)!
                let why = app.scaleUnavailable(cell)
                ChoiceRow(selected: q == resolution, enabled: why == nil) {
                    app.selectScale(ratio, q)
                    done()
                } label: {
                    Text(verbatim: q.rawValue).frame(width: 24, alignment: .leading)
                    if let why {
                        Text(verbatim: why).foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: "\(cell.width) × \(cell.height)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// A ratio's shape, fitted in a square of `side` points.
struct RatioShape: View {
    let ratio: SizeRatio
    var side: CGFloat = 14

    var body: some View {
        let w = ratio.width >= ratio.height ? side : side * CGFloat(ratio.width) / CGFloat(ratio.height)
        let h = ratio.height >= ratio.width ? side : side * CGFloat(ratio.height) / CGFloat(ratio.width)
        RoundedRectangle(cornerRadius: side / 6, style: .continuous)
            .strokeBorder(.primary, lineWidth: 1.3)
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
