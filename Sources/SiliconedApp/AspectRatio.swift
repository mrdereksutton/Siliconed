// Fork: **the size, picked by aspect ratio and resolution.** Two compact buttons show only the current
// ratio (its shape and name) and the current resolution; each opens its full list when clicked, the
// other choices staying out of sight until then. 1K is about a megapixel, 2K about four. The pair names
// a size in `SizeTable`; a size typed by hand (the pencil) shows its pixels instead. An edit keeps
// image 1's framing (`DiTBox`), as upstream.

import AppKit
import Siliconed
import SwiftUI

/// The ratios offered and the size each takes: sides in multiples of 32, so that every model takes them
/// (Qwen-Image-2.1 asks for 32). 9:16 and 16:9 keep upstream's 768 × 1344 and 1344 × 768; 2K doubles each side.
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
        let (w, h): (Int, Int) = switch (r.w, r.h) {
        case (9, 16): (768, 1344)
        case (2, 3): (832, 1248)
        case (3, 4): (864, 1152)
        case (4, 5): (896, 1120)
        case (4, 3): (1152, 864)
        case (3, 2): (1248, 832)
        case (16, 9): (1344, 768)
        default: (1024, 1024)
        }
        return RecommendedFormat(w * t.rawValue, h * t.rawValue)
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

/// The size as a labelled row (`DiTBox`, upstream's rack): the word, then the pills.
struct SizePicker: View {
    @Bindable var app: AppState

    var body: some View {
        HStack(spacing: 6) {
            Text("Size").foregroundStyle(.secondary)
            Spacer(minLength: 8)
            SizePills(app: app)
        }
        .font(.callout)
    }
}

/// **The ratio and the resolution as two pills**, each opening its list only when clicked, then the
/// pencil for a size typed by hand. The size in pixels is the composer's status line.
struct SizePills: View {
    @Bindable var app: AppState
    @State private var customSize = false
    @State private var choosingRatio = false
    @State private var choosingTier = false

    var body: some View {
        let current = SizeTable.match(app.format)
        let tier = current?.tier ?? .oneK
        let ratio = current?.ratio ?? SizeTable.square
        HStack(spacing: 8) {
            Pill(isPresented: $choosingRatio) {
                if let current {
                    RatioShape(ratio: current.ratio, side: 13)
                    Text(verbatim: current.ratio.label).monospacedDigit()
                } else {
                    Text(verbatim: "\(app.format.width) × \(app.format.height)").monospacedDigit()
                }
            } choices: {
                ChoiceList(title: "Aspect ratio") {
                    ForEach(SizeTable.ratios) { r in
                        let fits = app.renders(SizeTable.format(r, tier))
                        ChoiceRow(selected: current?.ratio == r, enabled: fits || app.renders(SizeTable.format(r, .oneK))) {
                            app.pickSize(r, fits ? tier : .oneK)
                            choosingRatio = false
                        } label: {
                            RatioShape(ratio: r, side: 14)
                            Text(verbatim: r.label).monospacedDigit()
                        }
                    }
                }
            }
            if current != nil {
                Pill(isPresented: $choosingTier) {
                    Image(systemName: "diamond").imageScale(.small)
                    Text(verbatim: tier.label)
                } choices: {
                    ChoiceList(title: "Resolution") {
                        ForEach(SizeTable.Tier.allCases, id: \.self) { t in
                            let f = SizeTable.format(ratio, t)
                            ChoiceRow(selected: t == tier, enabled: app.renders(f)) {
                                app.pickSize(ratio, t)
                                choosingTier = false
                            } label: {
                                Text(verbatim: t.label).frame(width: 22, alignment: .leading)
                                // Beyond this Mac's memory: the Mac it needs, said where the choice is made.
                                if let n = app.macNeeded(f, images: 0) {
                                    Text("\(String(f.width)) × \(String(f.height)) — needs a Mac with \(String(n)) GB")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(verbatim: "\(f.width) × \(f.height)").monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Pill(isPresented: $customSize) {
                Image(systemName: "pencil").imageScale(.small)
            } choices: {
                CustomSize(app: app)
            }
            .help("Type a size (width × height)")
            .accessibilityLabel(Text("Type a size (width × height)"))
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

// MARK: - Pills

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
                .fill(Color.primary.opacity(hovering || active ? 0.15 : 0.08)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.hairline))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(Motion.pick(.easeOut(duration: 0.12)), value: hovering)
    }
}

/// A pill that shows only the current choice; its list opens under it on a click.
struct Pill<Label: View, Choices: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var label: Label
    @ViewBuilder var choices: Choices

    var body: some View {
        Button { isPresented.toggle() } label: { PillFace(active: isPresented) { label } }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) { choices }
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

/// The list a pill opens: its title, then one row per choice.
struct ChoiceList<Rows: View>: View {
    let title: LocalizedStringKey
    var minWidth: CGFloat = 170
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            rows
        }
        .padding(8)
        .frame(minWidth: minWidth, alignment: .leading)
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
                    .font(.caption.weight(.semibold))
                    .opacity(selected ? 1 : 0)
            }
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.1 : selected ? 0.06 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { hovering = $0 && enabled }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
