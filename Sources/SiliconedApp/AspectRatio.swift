// Fork: **the size, picked by aspect ratio and resolution.** A chip per ratio, drawn as its shape over
// its name, tallest to widest; then 1K (about a megapixel) or 2K (about four). The pair names a size in
// `SizeTable`; a size typed by hand (the pencil) leaves the chips unlit. An edit keeps image 1's framing
// (`DiTBox`), as upstream.

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

/// The Model box's size: the ratio chips, the resolution, the size in pixels and the pencil.
struct SizePicker: View {
    @Bindable var app: AppState
    @State private var customSize = false

    var body: some View {
        let current = SizeTable.match(app.format)
        let tier = current?.tier ?? .oneK
        let ratio = current?.ratio ?? SizeTable.square
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Aspect ratio").foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(verbatim: "\(app.format.width) × \(app.format.height)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button { customSize = true } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .help("Type a size (width × height)")
                    .accessibilityLabel(Text("Type a size (width × height)"))
                    .popover(isPresented: $customSize, arrowEdge: .trailing) { CustomSize(app: app) }
            }
            .font(.callout)
            HStack(spacing: 3) {
                ForEach(SizeTable.ratios) { r in
                    let fits = app.renders(SizeTable.format(r, tier))
                    RatioChip(ratio: r, selected: current?.ratio == r,
                              enabled: fits || app.renders(SizeTable.format(r, .oneK))) {
                        app.pickSize(r, fits ? tier : .oneK)
                    }
                }
            }
            Field(title: "Resolution") {
                Picker("Resolution", selection: Binding(get: { tier }, set: { app.pickSize(ratio, $0) })) {
                    ForEach(SizeTable.Tier.allCases, id: \.self) { t in
                        Text(verbatim: t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            // 2K beyond this Mac's memory: said under the switch, with the Mac it needs.
            let twoK = SizeTable.format(ratio, .twoK)
            if let n = app.macNeeded(twoK, images: 0) {
                Text("\(String(twoK.width)) × \(String(twoK.height)) — needs a Mac with \(String(n)) GB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A ratio: its shape in an 18-point square, its name under it; lit when it is the size's.
private struct RatioChip: View {
    let ratio: SizeTable.Ratio
    let selected: Bool
    let enabled: Bool
    let pick: () -> Void

    var body: some View {
        let side: CGFloat = 18
        let w = ratio.w >= ratio.h ? side : side * CGFloat(ratio.w) / CGFloat(ratio.h)
        let h = ratio.h >= ratio.w ? side : side * CGFloat(ratio.h) / CGFloat(ratio.w)
        Button(action: pick) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary, lineWidth: 1.5)
                    .frame(width: w, height: h)
                    .frame(width: side, height: side)
                Text(verbatim: ratio.label)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Palette.well : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(Text(verbatim: ratio.label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
