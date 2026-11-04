// Fork: **the size, picked by aspect ratio and resolution.** Two cells show only the current ratio (its
// shape and name) and the current resolution; each opens its full list when clicked, the other choices
// staying out of sight until then. 1K is about a megapixel, 2K about four. The pair names a size in
// `SizeTable`; a size typed by hand shows its pixels instead. An edit keeps image 1's framing, as upstream.

import AppKit
import Siliconed
import SwiftUI

/// The ratios offered and the size each takes — upstream's table (`SizeScales`, held by its tests: sides in multiples of 32,
/// so that every model takes them), read for the composer's eight ratios. 9:16 and 16:9 are 768 × 1344 and 1344 × 768 at 1K
/// (4:7, the nearest in multiples of 32 near a megapixel), the exact 1440 × 2560 and 2560 × 1440 at 2K.
enum SizeTable {
    struct Ratio: Hashable, Identifiable {
        let w: Int, h: Int
        var id: String { label }
        var label: String { "\(w):\(h)" }
    }

    enum Tier: Int, CaseIterable, Hashable {
        case oneK = 1, twoK = 2
        var label: String { "\(rawValue)K" }
    }

    /// Tallest to widest.
    static let ratios: [Ratio] = [Ratio(w: 9, h: 16), Ratio(w: 2, h: 3), Ratio(w: 3, h: 4), Ratio(w: 4, h: 5),
                                  Ratio(w: 1, h: 1), Ratio(w: 4, h: 3), Ratio(w: 3, h: 2), Ratio(w: 16, h: 9)]
    static let square = Ratio(w: 1, h: 1)

    static func format(_ r: Ratio, _ t: Tier) -> RecommendedFormat {
        SizeScales.cell(SizeRatio(r.w, r.h), t == .oneK ? .oneK : .twoK)?.format ?? RecommendedFormat(1024, 1024)
    }

    /// The ratio and resolution that name `f`; nil for a size typed by hand.
    static func match(_ f: RecommendedFormat) -> (ratio: Ratio, tier: Tier)? {
        for r in ratios {
            for t in Tier.allCases where format(r, t) == f { return (r, t) }
        }
        return nil
    }
}

extension AppState {
    /// Fork: takes the size a ratio and a resolution name (`SizeTable`).
    func pickSize(_ r: SizeTable.Ratio, _ t: SizeTable.Tier) {
        let f = SizeTable.format(r, t)
        format = f
        // After the format: `orientationChanged` then finds the two agreeing and keeps the size.
        if orientation != f.orientation { orientation = f.orientation }
    }

    /// Fork: the chosen model takes `f` and this Mac's memory holds it (`checkFormat`, `macNeeded`).
    func renders(_ f: RecommendedFormat) -> Bool {
        (try? checkFormat(width: f.width, height: f.height)) != nil && macNeeded(f, images: 0) == nil
    }
}

/// **The aspect ratios**, tallest to widest, each with its shape; a ratio beyond this Mac's memory at
/// the current resolution falls back to 1K, one this Mac cannot render at all is greyed.
struct RatioChoices: View {
    @Bindable var app: AppState
    let done: () -> Void

    var body: some View {
        let current = SizeTable.match(app.format)
        let tier = current?.tier ?? .oneK
        ChoiceList(title: "Aspect ratio") {
            ForEach(SizeTable.ratios) { r in
                let fits = app.renders(SizeTable.format(r, tier))
                ChoiceRow(selected: current?.ratio == r, enabled: fits || app.renders(SizeTable.format(r, .oneK))) {
                    app.pickSize(r, fits ? tier : .oneK)
                    done()
                } label: {
                    RatioShape(ratio: r, side: 14)
                    Text(verbatim: r.label).monospacedDigit().frame(width: 36, alignment: .leading)
                    let f = SizeTable.format(r, fits ? tier : .oneK)
                    Text(verbatim: "\(f.width) × \(f.height)").font(Silicon.readout).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// **The resolutions** at the current ratio: 1K about a megapixel, 2K about four — with the pixels, or
/// the Mac a size needs when this one's memory falls short.
struct TierChoices: View {
    @Bindable var app: AppState
    let done: () -> Void

    var body: some View {
        let current = SizeTable.match(app.format)
        let tier = current?.tier ?? .oneK
        let ratio = current?.ratio ?? SizeTable.square
        ChoiceList(title: "Resolution") {
            ForEach(SizeTable.Tier.allCases, id: \.self) { t in
                let f = SizeTable.format(ratio, t)
                ChoiceRow(selected: t == tier, enabled: app.renders(f)) {
                    app.pickSize(ratio, t)
                    done()
                } label: {
                    Text(verbatim: t.label).frame(width: 24, alignment: .leading)
                    // Beyond this Mac's memory: the Mac it needs, said where the choice is made.
                    if let n = app.macNeeded(f, images: 0) {
                        Text("\(String(f.width)) × \(String(f.height)) — needs a Mac with \(String(n)) GB")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: "\(f.width) × \(f.height)").font(Silicon.readout).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// A ratio's shape, fitted in a square of `side` points.
struct RatioShape: View {
    let ratio: SizeTable.Ratio
    var side: CGFloat = 14

    var body: some View {
        let w = ratio.w >= ratio.h ? side : side * CGFloat(ratio.w) / CGFloat(ratio.h)
        let h = ratio.h >= ratio.w ? side : side * CGFloat(ratio.h) / CGFloat(ratio.w)
        RoundedRectangle(cornerRadius: side / 6, style: .continuous)
            .strokeBorder(.primary, lineWidth: 1.3)
            .frame(width: w, height: h)
            .frame(width: side, height: side)
    }
}

// MARK: - Lists

/// **A list of choices**: its spec-sheet title, then one row per choice.
struct ChoiceList<Rows: View>: View {
    let title: LocalizedStringKey
    var minWidth: CGFloat = 170
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SpecCaption(title)
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .padding(.bottom, 6)
            rows
        }
        .padding(8)
        .frame(minWidth: minWidth, maxWidth: .infinity, alignment: .leading)
    }
}

/// A choice: what it is, and a check when it is the current one — on a blue tint; lit under the pointer.
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
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(hovering ? 0.24 : 0.16)
                               : hovering ? Silicon.cellHover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { hovering = $0 && enabled }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
