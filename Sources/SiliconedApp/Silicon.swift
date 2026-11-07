// Fork: **Siliconed's own look — « Silicon »**, built around the name: a graphite canvas over a
// wafer's die grid, a thin iridescent sheen (a wafer's interference colors) on what is open, small
// spec-sheet labels over each setting, figures in a monospaced readout, and the app's blue for what
// acts. One place for the colors, the type and the drawn materials — and for the controls, drawn
// here (cells, chips, slider, switch, stepper, the mode switch) so that nothing in the main window
// is the stock pop-up button, stepper, switch or popover.

import AppKit
import SwiftUI

enum Silicon {
    // MARK: Colors — graphite in dark, porcelain in light

    static let canvas = dynamic(dark: 0x0B0C0F, light: 0xE6E7EB)
    /// The canvas under the light: the middle of its vignette.
    static let canvasLift = dynamic(dark: 0x17191F, light: 0xF5F6F8)
    static let panel = dynamic(dark: 0x131418, light: 0xFBFBFC)
    static let panelTop = dynamic(dark: 0x1C1E24, light: 0xFFFFFF)
    static let cell = dynamic(dark: 0x1F2128, light: 0xEDEEF2)
    static let cellHover = dynamic(dark: 0x282B34, light: 0xE2E4EA)
    static let edge = dynamic(dark: 0xFFFFFF, light: 0x000000, darkAlpha: 0.08, lightAlpha: 0.10)
    static let edgeStrong = dynamic(dark: 0xFFFFFF, light: 0x000000, darkAlpha: 0.17, lightAlpha: 0.20)
    static let gridLine = dynamic(dark: 0xFFFFFF, light: 0x000000, darkAlpha: 0.04, lightAlpha: 0.055)
    static let track = dynamic(dark: 0xFFFFFF, light: 0x000000, darkAlpha: 0.12, lightAlpha: 0.12)

    /// A wafer's interference colors, left to right: the sheen on what is open.
    static let sheenColors: [Color] = [0x5AC8FA, 0x7C8CFF, 0xC084FC, 0xFFB86B, 0x5AC8FA].map(Color.init(rgb:))
    static var sheen: LinearGradient {
        LinearGradient(colors: sheenColors, startPoint: .leading, endPoint: .trailing)
    }

    /// What acts: the app's blue, a shade lighter at the top.
    static var accentFill: LinearGradient {
        LinearGradient(colors: [Color.accentColor.mix(with: .white, by: 0.22), .accentColor], startPoint: .top, endPoint: .bottom)
    }

    // MARK: Type

    /// The headline: wide, like the name on a chip's package.
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold).width(.expanded) }
    /// A spec-sheet label, set in capitals (`SpecCaption`).
    static let caption = Font.system(size: 9, weight: .semibold).width(.expanded)
    static let value = Font.system(size: 13, weight: .medium)
    /// Figures: sizes, memory, times, strengths.
    static let readout = Font.system(size: 11, weight: .regular, design: .monospaced)

    static func dynamic(dark: Int, light: Int, darkAlpha: CGFloat = 1, lightAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(rgb: dark, alpha: darkAlpha)
                                                                : NSColor(rgb: light, alpha: lightAlpha)
        })
    }
}

extension Color {
    init(rgb: Int) { self.init(nsColor: NSColor(rgb: rgb, alpha: 1)) }
}

extension NSColor {
    convenience init(rgb: Int, alpha: CGFloat) {
        self.init(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}

// MARK: - Materials

extension View {
    /// **A panel**: a graphite plate, lighter at the top, a hairline edge and a soft drop; with `sheen`,
    /// the wafer's colors along its top edge.
    func siliconPanel<S: InsettableShape>(_ shape: S, sheen: Bool = false, shadow: Bool = true) -> some View {
        background(shape.fill(LinearGradient(colors: [Silicon.panelTop, Silicon.panel], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(Silicon.edge, lineWidth: 1))
            .overlay {
                if sheen {
                    shape.strokeBorder(Silicon.sheen, lineWidth: 1.2)
                        .opacity(0.9)
                        .mask(VStack(spacing: 0) {
                            LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom).frame(height: 18)
                            Spacer(minLength: 0)
                        })
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(shadow ? 0.45 : 0), radius: 22, y: 10)
    }
}

/// **The canvas**: graphite, lit from the middle, over a wafer's die grid with an alignment cross every
/// fourth die — the grid fades toward the edges, the image alone carries the color.
struct WaferBackground: View {
    var body: some View {
        let center = UnitPoint(x: 0.5, y: 0.42)
        ZStack {
            Silicon.canvas
            RadialGradient(colors: [Silicon.canvasLift, Silicon.canvas], center: center, startRadius: 0, endRadius: 820)
            Canvas { context, size in
                let step: CGFloat = 32
                let origin = CGPoint(x: size.width * center.x, y: size.height * center.y)
                var lines = Path()
                var x = origin.x.truncatingRemainder(dividingBy: step)
                while x <= size.width {
                    lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)); x += step
                }
                var y = origin.y.truncatingRemainder(dividingBy: step)
                while y <= size.height {
                    lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)); y += step
                }
                context.stroke(lines, with: .color(Silicon.gridLine), lineWidth: 0.5)
                var marks = Path()
                let arm: CGFloat = 4
                var i = (origin.x / (step * 4)).rounded(.down) * -1
                while origin.x + i * step * 4 <= size.width {
                    let mx = origin.x + i * step * 4
                    var j = (origin.y / (step * 4)).rounded(.down) * -1
                    while origin.y + j * step * 4 <= size.height {
                        let my = origin.y + j * step * 4
                        marks.move(to: CGPoint(x: mx - arm, y: my)); marks.addLine(to: CGPoint(x: mx + arm, y: my))
                        marks.move(to: CGPoint(x: mx, y: my - arm)); marks.addLine(to: CGPoint(x: mx, y: my + arm))
                        j += 1
                    }
                    i += 1
                }
                context.stroke(marks, with: .color(Silicon.edgeStrong), lineWidth: 0.75)
            }
            .mask(RadialGradient(colors: [.white, .white.opacity(0.4), .clear], center: center, startRadius: 40, endRadius: 760))
        }
        .accessibilityHidden(true)
    }
}

/// **The wafer**: a disc of dies with its flat, faint, behind the empty canvas's question — the app's
/// mark. Its rim carries the sheen.
struct WaferMark: View {
    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2 - 1
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let flatY = c.y + r * 0.93
            let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            var above = context
            above.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: flatY)))
            // The dies.
            var dies = above
            dies.clip(to: disc)
            dies.fill(disc, with: .radialGradient(Gradient(colors: [Silicon.edge, .clear]), center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35),
                                                 startRadius: 0, endRadius: r * 1.3))
            let step = r / 6.5
            var grid = Path()
            var x = c.x - step * 7
            while x <= c.x + r { grid.move(to: CGPoint(x: x, y: c.y - r)); grid.addLine(to: CGPoint(x: x, y: c.y + r)); x += step }
            var y = c.y - step * 7
            while y <= c.y + r { grid.move(to: CGPoint(x: c.x - r, y: y)); grid.addLine(to: CGPoint(x: c.x + r, y: y)); y += step }
            dies.stroke(grid, with: .color(Silicon.edge), lineWidth: 0.75)
            // The rim and the flat, in the sheen.
            let dx = sqrt(max(0, r * r - (flatY - c.y) * (flatY - c.y)))
            let sheen = GraphicsContext.Shading.linearGradient(Gradient(colors: Silicon.sheenColors),
                                                                startPoint: CGPoint(x: c.x - r, y: c.y - r),
                                                                endPoint: CGPoint(x: c.x + r, y: c.y + r))
            var rim = above
            rim.opacity = 0.45
            rim.stroke(disc, with: sheen, lineWidth: 1)
            var flat = context
            flat.opacity = 0.45
            flat.stroke(Path { p in p.move(to: CGPoint(x: c.x - dx, y: flatY)); p.addLine(to: CGPoint(x: c.x + dx, y: flatY)) },
                        with: sheen, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - The spec cells

/// A spec-sheet label: small, wide, in capitals.
struct SpecCaption: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }
    var body: some View {
        Text(text).font(Silicon.caption).tracking(0.7).textCase(.uppercase).foregroundStyle(.secondary).lineLimit(1)
    }
}

/// **A setting's face**: its label over its value, on a cell — brighter under the pointer, edged with
/// the sheen while its panel is open.
struct SpecCellFace<Value: View>: View {
    let caption: LocalizedStringKey
    var open = false
    var hovering = false
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SpecCaption(caption)
            HStack(spacing: 6) { value }
                .font(Silicon.value)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 46, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(hovering || open ? Silicon.cellHover : Silicon.cell))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(open ? AnyShapeStyle(Silicon.sheen) : AnyShapeStyle(Silicon.edge), lineWidth: open ? 1.2 : 1))
        .contentShape(Rectangle())
    }
}

/// A cell that opens its panel.
struct SpecCell<Value: View>: View {
    let caption: LocalizedStringKey
    var open = false
    let action: () -> Void
    @ViewBuilder var value: Value
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            SpecCellFace(caption: caption, open: open, hovering: hovering) { value }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.pick(.easeOut(duration: 0.12)), value: hovering)
    }
}

/// The composer's panels, one open at a time (`AppState.composerPanel`); Esc or a click elsewhere
/// closes it.
enum ComposerPanel: Hashable {
    case model, ratio, tier, lora, settings
}

// MARK: - Controls

/// **Choices as chips**: the chosen one in the app's blue.
struct ChipPicker<Choice: Hashable, ChipLabel: View>: View {
    @Binding var selection: Choice
    let choices: [Choice]
    @ViewBuilder let label: (Choice) -> ChipLabel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(choices, id: \.self) { choice in
                let on = choice == selection
                Button { selection = choice } label: {
                    label(choice)
                        .font(.system(size: 12, weight: on ? .semibold : .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(on ? AnyShapeStyle(Silicon.accentFill) : AnyShapeStyle(Silicon.cell)))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Silicon.edge))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// **− value +** on one cell.
struct StepperChip: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 2) {
            step("minus", -1)
            Text(verbatim: "\(value)").font(Silicon.readout.weight(.semibold)).frame(minWidth: 22)
            step("plus", 1)
        }
        .padding(.horizontal, 3)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Silicon.cell))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Silicon.edge))
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    private func step(_ symbol: String, _ by: Int) -> some View {
        let blocked = !range.contains(value + by)
        return Button { value = min(range.upperBound, max(range.lowerBound, value + by)) } label: {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                .frame(width: 20, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(blocked ? .tertiary : .secondary)
        .disabled(blocked)
    }
}

/// **A slider**: a thin track, filled in blue up to a white knob; a double click puts `reset` back.
struct SiliconSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var reset: Double? = nil

    var body: some View {
        GeometryReader { g in
            let span = range.upperBound - range.lowerBound
            let f = span > 0 ? CGFloat((value - range.lowerBound) / span) : 0
            let w = g.size.width
            let zero = span > 0 ? CGFloat((min(max(0, range.lowerBound), range.upperBound) - range.lowerBound) / span) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Silicon.track).frame(height: 4)
                Capsule().fill(Silicon.accentFill)
                    .frame(width: max(4, abs(f - zero) * w), height: 4)
                    .offset(x: min(f, zero) * w)
                Circle().fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: f * (w - 14))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let p = min(max(0, drag.location.x / max(1, w)), 1)
                value = range.lowerBound + Double(p) * span
            })
            .onTapGesture(count: 2) { if let reset { value = reset } }
        }
        .frame(height: 18)
        // To VoiceOver, the system's slider: its role, its value, its steps.
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }
}

/// **A switch**: a capsule, blue when on, its knob white.
struct SiliconToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(Silicon.accentFill) : AnyShapeStyle(Silicon.track))
                    .overlay(Capsule().strokeBorder(Silicon.edge))
                    .frame(width: 34, height: 20)
                Circle().fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                    .padding(2)
            }
            .contentShape(Capsule())
            .onTapGesture { withAnimation(Motion.pick(.spring(duration: 0.22))) { configuration.isOn.toggle() } }
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// **A secondary button**: a cell with its word.
struct SiliconButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 26)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(prominent ? AnyShapeStyle(Silicon.accentFill) : AnyShapeStyle(Silicon.cell)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Silicon.edge))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// **Generate | Explore**, in the middle of the toolbar: the chosen mode on a blue capsule that slides.
struct ModeSwitch: View {
    @Bindable var app: AppState

    var body: some View {
        CapsuleTabs(selection: $app.sidebarTab, tabs: [.generate, .explore]) { $0 == .generate ? "Generate" : "Explore" }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Exploration"))
    }
}

/// Fork: **the name in the top bar**, in the wide face of the empty canvas's headline — the window's
/// title, which the bar no longer draws. Beside it, when there is one, what the subtitle used to say:
/// the Mac that computes, or this instance's name.
struct Wordmark: View {
    var note: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "Siliconed")
                .font(Silicon.display(14))
                .foregroundStyle(.primary.opacity(0.92))
            if let note, !note.isEmpty {
                Text(verbatim: note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Capsule().fill(Silicon.cell))
                    .overlay(Capsule().strokeBorder(Silicon.edge))
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// Fork: **a round icon button**, as tall as the mode switch beside it — a cell with its symbol,
/// brighter under the pointer. The top bar's own, instead of the system's glass.
struct SiliconIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconFace(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct IconFace<Label: View>: View {
    let label: Label
    let pressed: Bool
    @State private var hovering = false

    var body: some View {
        label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(hovering ? .primary : .secondary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(hovering ? Silicon.cellHover : Silicon.cell))
            .overlay(Circle().strokeBorder(Silicon.edge))
            .opacity(pressed ? 0.75 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .animation(Motion.pick(.easeOut(duration: 0.12)), value: hovering)
    }
}

/// **Tabs on a capsule**: the chosen one on the app's blue, which slides from one to the next — the
/// window's two modes, the Settings' panes.
struct CapsuleTabs<Value: Hashable>: View {
    @Binding var selection: Value
    let tabs: [Value]
    let title: (Value) -> LocalizedStringKey
    @Namespace private var space

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { segment($0) }
        }
        .padding(3)
        .background(Capsule().fill(Silicon.cell))
        .overlay(Capsule().strokeBorder(Silicon.edge))
    }

    private func segment(_ tab: Value) -> some View {
        let on = selection == tab
        return Button {
            withAnimation(Motion.pick(.spring(duration: 0.3))) { selection = tab }
        } label: {
            Text(title(tab))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? Color.white : Color.secondary)
                .padding(.horizontal, 16)
                .frame(height: 26)
                .background {
                    if on {
                        Capsule().fill(Silicon.accentFill)
                            .shadow(color: Color.accentColor.opacity(0.45), radius: 6, y: 1)
                            .matchedGeometryEffect(id: "mode", in: space)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

extension View {
    /// **A field**: a cell, its text a readout.
    func siliconField() -> some View {
        textFieldStyle(.plain)
            .font(Silicon.readout)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Silicon.cell))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Silicon.edge))
    }
}

/// **A check box**: a small square, blue and ticked when on.
struct SiliconCheckStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(configuration.isOn ? AnyShapeStyle(Silicon.accentFill) : AnyShapeStyle(Silicon.cell))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(configuration.isOn ? Color.clear : Silicon.edgeStrong))
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 15, height: 15)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// **The action of a mode** — Generate, Explore: the app's blue lit from above, a glow under it;
/// while something stops it, the same blue body dimmed, unlit and without its glow — the button
/// waiting, not another control; while `sweeping`, a light crosses it again and again.
struct SiliconPrimaryStyle: ButtonStyle {
    var sweeping = false
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        PrimaryFace(label: configuration.label, pressed: configuration.isPressed, sweeping: sweeping, fullWidth: fullWidth)
    }
}

private struct PrimaryFace<Label: View>: View {
    let label: Label
    let pressed: Bool
    let sweeping: Bool
    let fullWidth: Bool
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.55))
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 46)
            // Disabled, SwiftUI draws `Color.accentColor` grey: the waiting body takes the system's accent
            // as AppKit gives it, which it leaves alone.
            .background(shape.fill(enabled ? AnyShapeStyle(Silicon.accentFill)
                                           : AnyShapeStyle(Color(nsColor: .controlAccentColor).opacity(0.4))))
            .overlay { if sweeping, enabled { Sweep().clipShape(shape) } }
            .overlay(shape.strokeBorder(Color.white.opacity(enabled ? 0.25 : 0.1), lineWidth: 1))
            .shadow(color: Color.accentColor.opacity(enabled ? (hovering ? 0.7 : 0.45) : 0), radius: hovering ? 18 : 12, y: 3)
            .opacity(pressed ? 0.85 : 1)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(Motion.pick(.easeOut(duration: 0.15)), value: hovering)
    }
}

/// A key on its cap: « ⌘↩ » beside the action it presses.
struct KeyCap: View {
    let keys: String
    init(_ keys: String) { self.keys = keys }
    var body: some View {
        Text(verbatim: keys)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.18)))
            .accessibilityHidden(true)
    }
}

/// A light crossing a surface, again and again; still under Reduce Motion.
struct Sweep: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.5)
                .offset(x: phase * g.size.width * 1.5)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard let a = Motion.pick(.linear(duration: 1.6).repeatForever(autoreverses: false)) else { return }
            withAnimation(a) { phase = 1 }
        }
    }
}
