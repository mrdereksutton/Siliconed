// **The app's colors & Studio Theme Engine**: three curated darkroom & daylight palettes inspired by
// cinema grading suites (Cinema Lime), creative AI studios (Electric Studio), and Siliconed's own
// icon chart (Indigo & Mint). Every surface, wire, CTA gradient, and AppKit ink updates live.

import AppKit
import SwiftUI

enum StudioTheme: String, CaseIterable, Identifiable, Sendable {
    case cinemaLime
    case electricStudio
    case siliconedIndigo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cinemaLime: String(localized: "Cinema Lime")
        case .electricStudio: String(localized: "Electric Studio")
        case .siliconedIndigo: String(localized: "Indigo & Mint")
        }
    }

    var subtitle: String {
        switch self {
        case .cinemaLime: String(localized: "Obsidian darkroom & electric chartreuse")
        case .electricStudio: String(localized: "Midnight slate & luminous rose-violet")
        case .siliconedIndigo: String(localized: "Deep indigo night & mint glow")
        }
    }

    var symbol: String {
        switch self {
        case .cinemaLime: "film.stack"
        case .electricStudio: "sparkles"
        case .siliconedIndigo: "cpu"
        }
    }

    /// Preview swatch hexes `[ground, accentStart, accentEnd]`.
    var swatchHexes: [Int] {
        switch self {
        case .cinemaLime: [0x090A0F, 0xE4FF54, 0xB8F218]
        case .electricStudio: [0x0A0914, 0xF43F5E, 0x7C3AED]
        case .siliconedIndigo: [0x131424, 0x6EF1DD, 0x56C0B0]
        }
    }
}

enum Palette {
    static let themeKey = "studio.theme"

    /// Current theme read by both SwiftUI views and AppKit dynamic `NSColor` providers.
    nonisolated(unsafe) static var activeTheme: StudioTheme = {
        if let raw = UserDefaults.standard.string(forKey: themeKey),
           let parsed = StudioTheme(rawValue: raw) {
            return parsed
        }
        return .cinemaLime
    }()

    static var peach: Color { Color(nsColor: peachInk) }
    /// The same, for AppKit: the prompt's caret.
    static let peachInk = dynamicInk(
        dark: { _ in 0xF2B279 },
        light: { _ in 0xB36D2A }
    )

    static var rose: Color { dynamic(dark: { _ in 0xEFA6D6 }, light: { _ in 0xB06194 }) }
    static var sky: Color { dynamic(dark: { _ in 0x7FCAFE }, light: { _ in 0x3786C3 }) }

    /// **A series** (bracketing): one yellow everywhere, distinct from `live` and the three stage wires.
    static let bracketInk = dynamicInk(
        dark: { _ in 0xFFD60A },
        light: { _ in 0xB89400 }
    )
    static var bracket: Color { Color(nsColor: bracketInk) }

    /// What runs: the stage at work, the steps done, the image followed, the button that starts something.
    static var live: Color { Color(nsColor: liveInk) }
    static let liveInk = dynamicInk(
        dark: { theme in
            switch theme {
            case .cinemaLime: 0xD4FF33
            case .electricStudio: 0xD946EF
            case .siliconedIndigo: 0x56C0B0
            }
        },
        light: { theme in
            switch theme {
            case .cinemaLime: 0x1E6F36
            case .electricStudio: 0x9333EA
            case .siliconedIndigo: 0x3F3A8A
            }
        }
    )

    /// Signature multi-stop CTA gradient for Generate, active mode pills, and studio badges.
    static func ctaGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme != .dark {
            let colors: [Color] = switch activeTheme {
            case .cinemaLime: [Color(hex: 0x258542), Color(hex: 0x195E2D)]
            case .electricStudio: [Color(hex: 0xEC4899), Color(hex: 0x7C3AED)]
            case .siliconedIndigo: [Color(hex: 0x4F46E5), Color(hex: 0x3F3A8A)]
            }
            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        let colors: [Color] = switch activeTheme {
        case .cinemaLime: [Color(hex: 0xE6FF57), Color(hex: 0xBDFA19)]
        case .electricStudio: [Color(hex: 0xF43F5E), Color(hex: 0xD946EF), Color(hex: 0x7C3AED)]
        case .siliconedIndigo: [Color(hex: 0x6EF1DD), Color(hex: 0x48B5A5)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// **The words the writer brings** (Rewrite, Describe), over the text.
    static var addedInk: NSColor { peachInk }
    static let addedWash = dynamicInk(
        dark: { _ in 0xF2B279 },
        light: { _ in 0xB36D2A },
        alpha: 0.12
    )

    /// A selected segment, a checked box: `.tint(Palette.control)` on the control.
    static var control: Color {
        dynamic(
            dark: { theme in
                switch theme {
                case .cinemaLime: 0x4C6B28
                case .electricStudio: 0x8B5CF6
                case .siliconedIndigo: 0x6660CB
                }
            },
            light: { theme in
                switch theme {
                case .cinemaLime: 0x1E6F36
                case .electricStudio: 0x7C3AED
                case .siliconedIndigo: 0x3F3A8A
                }
            }
        )
    }

    /// A selection in the prompt (AppKit).
    static let selectionInk = dynamicInk(
        dark: { theme in
            switch theme {
            case .cinemaLime: 0x8BB82D
            case .electricStudio: 0x9333EA
            case .siliconedIndigo: 0x6660CB
            }
        },
        light: { theme in
            switch theme {
            case .cinemaLime: 0x1E6F36
            case .electricStudio: 0x7C3AED
            case .siliconedIndigo: 0x3F3A8A
            }
        },
        alpha: 0.34
    )

    @MainActor static func ink(_ view: NSTextView) {
        view.insertionPointColor = peachInk
        view.selectedTextAttributes = [.backgroundColor: selectionInk]
    }

    /// A link's words (`ChartLinkStyle`).
    static var link: Color {
        dynamic(
            dark: { theme in
                switch theme {
                case .cinemaLime: 0xCBEF43
                case .electricStudio: 0xE879F9
                case .siliconedIndigo: 0x999BEE
                }
            },
            light: { theme in
                switch theme {
                case .cinemaLime: 0x1B6530
                case .electricStudio: 0x7E22CE
                case .siliconedIndigo: 0x3F3A8A
                }
            }
        )
    }

    /// A label or a glyph on `live`.
    static var onLive: Color {
        dynamic(
            dark: { theme in
                switch theme {
                case .cinemaLime: 0x090C04
                case .electricStudio: 0xFFFFFF
                case .siliconedIndigo: 0x0F1021
                }
            },
            light: { _ in 0xFCFCFC }
        )
    }

    static var failure: Color { dynamic(dark: { _ in 0xFC5852 }, light: { _ in 0xD02C2A }) }

    /// Behind the image: deep darkroom obsidian at night, warm paper by day.
    static var canvas: Color { Color(nsColor: canvasInk) }
    static let canvasInk = dynamicInk(
        dark: { theme in
            switch theme {
            case .cinemaLime: 0x08090D
            case .electricStudio: 0x090812
            case .siliconedIndigo: 0x131424
            }
        },
        light: { theme in
            switch theme {
            case .cinemaLime: 0xF6F7F4
            case .electricStudio: 0xF8F6FC
            case .siliconedIndigo: 0xF9F6F2
            }
        }
    )

    /// The rack's column; the ground of Settings and Prompt Lab.
    static var column: Color { Color(nsColor: columnInk) }
    static let columnInk = dynamicInk(
        dark: { theme in
            switch theme {
            case .cinemaLime: 0x0E1017
            case .electricStudio: 0x11101E
            case .siliconedIndigo: 0x1B1C2F
            }
        },
        light: { theme in
            switch theme {
            case .cinemaLime: 0xEDEFE9
            case .electricStudio: 0xF0ECF9
            case .siliconedIndigo: 0xF0ECE7
            }
        }
    )

    /// A card a step above the column.
    static var surface: Color {
        dynamic(
            dark: { theme in
                switch theme {
                case .cinemaLime: 0x151822
                case .electricStudio: 0x19172B
                case .siliconedIndigo: 0x2A283D
                }
            },
            light: { _ in 0xFEFDFB }
        )
    }

    /// Elevated floating studio surface (popovers, active cards, pills).
    static var surfaceElevated: Color {
        dynamic(
            dark: { theme in
                switch theme {
                case .cinemaLime: 0x1C202E
                case .electricStudio: 0x221F38
                case .siliconedIndigo: 0x33314A
                }
            },
            light: { _ in 0xFFFFFF }
        )
    }

    /// A field inside a box: a recess.
    static var well: Color {
        Color(nsColor: NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.065)
                : NSColor(white: 0, alpha: 0.055)
        })
    }

    /// Crisp border hairline.
    static let hairline = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.13)
            : NSColor(white: 0, alpha: 0.12)
    })

    /// Top-edge specular highlight gradient giving cards tactile glass/anodized depth.
    static func specularRim(for scheme: ColorScheme, active: Bool = false) -> LinearGradient {
        if active {
            return LinearGradient(
                colors: [live.opacity(0.85), live.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        let top = scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
        let mid = scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
        let bottom = scheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.10)
        return LinearGradient(colors: [top, mid, bottom], startPoint: .top, endPoint: .bottom)
    }

    private static func dynamic(
        dark: @escaping @Sendable (StudioTheme) -> Int,
        light: @escaping @Sendable (StudioTheme) -> Int
    ) -> Color {
        Color(nsColor: dynamicInk(dark: dark, light: light))
    }

    private static func dynamicInk(
        dark: @escaping @Sendable (StudioTheme) -> Int,
        light: @escaping @Sendable (StudioTheme) -> Int,
        alpha: CGFloat = 1
    ) -> NSColor {
        func srgb(_ v: Int) -> NSColor {
            NSColor(
                srgbRed: CGFloat(v >> 16 & 0xFF) / 255,
                green: CGFloat(v >> 8 & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255,
                alpha: alpha
            )
        }
        return NSColor(name: nil) { a in
            let theme = Palette.activeTheme
            return a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? srgb(dark(theme)) : srgb(light(theme))
        }
    }
}

/// **A stage's or a port's icon**: a full tile of `color`, the glyph hollowed in the card's color.
struct IconTile: View {
    let symbol: String
    let color: Color
    var side: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: side * 0.55, weight: .semibold))
            .foregroundStyle(Palette.surface)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: side / 4, style: .continuous).fill(color))
    }
}

/// **The button that starts something** (« Generate », « Install… », « Crop »): filled with the active
/// Studio Theme's luminous CTA gradient and `onLive` ink, with a soft studio halo at night.
struct ProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Face(configuration: configuration) }

    private struct Face: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.controlSize) private var size
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            let _ = StudioHub.shared.theme
            let large = size == .large || size == .extraLarge
            let shape = RoundedRectangle(cornerRadius: large ? 9 : 7, style: .continuous)
            let night = enabled && scheme == .dark
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? AnyShapeStyle(Palette.onLive) : AnyShapeStyle(.secondary))
                .padding(.horizontal, large ? 15 : 11)
                .frame(minHeight: large ? 32 : 25)
                .background {
                    if enabled {
                        shape.fill(Palette.ctaGradient(for: scheme))
                    } else {
                        shape.fill(Palette.well)
                    }
                }
                .overlay(shape.strokeBorder(.white.opacity(night ? 0.32 : 0), lineWidth: 0.75))
                .shadow(color: night ? Palette.live.opacity(0.38) : .clear, radius: 9, y: 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.86 : 1)
                .contentShape(shape)
        }
    }
}

extension ButtonStyle where Self == ProminentButtonStyle {
    static var prominent: ProminentButtonStyle { ProminentButtonStyle() }
}

/// **A link in the chart's accent** (`.chartLink`).
struct ChartLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Face(configuration: configuration) }

    private struct Face: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let _ = StudioHub.shared.theme
            configuration.label
                .foregroundStyle(enabled ? AnyShapeStyle(Palette.link) : AnyShapeStyle(.tertiary))
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Rectangle())
        }
    }
}

extension ButtonStyle where Self == ChartLinkStyle {
    static var chartLink: ChartLinkStyle { ChartLinkStyle() }
}

// MARK: - Studio Specular Surface & Window Drag Area

private struct StudioCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let elevated: Bool
    let active: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let _ = StudioHub.shared.theme
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(elevated ? Palette.surfaceElevated : Palette.surface))
            .overlay(shape.strokeBorder(Palette.specularRim(for: scheme, active: active), lineWidth: active ? 1.5 : 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0.34 : 0.08), radius: elevated ? 16 : 8, y: elevated ? 6 : 3)
    }
}

extension View {
    /// Layered darkroom card with a `1px` top-edge specular rim highlight and ambient shadow.
    func studioCard(cornerRadius: CGFloat = 14, elevated: Bool = false, active: Bool = false) -> some View {
        modifier(StudioCardModifier(cornerRadius: cornerRadius, elevated: elevated, active: active))
    }
}

/// Allows dragging a full-bleed borderless window from any non-interactive region of a custom Studio Header,
/// and zooms the window on double-click just like a native macOS titlebar.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}
}
