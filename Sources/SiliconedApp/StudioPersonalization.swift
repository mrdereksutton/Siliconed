// Studio personalization: Signature Studio Themes (Cinema Lime, Electric Studio, Indigo & Mint),
// Higgsfield-inspired Cinema Camera & Optics Rig, Style Presets, LoRA visual thumbnails & trigger words,
// Favorites, Inline Prompt Auto-Polish, Main-Composer @Subject Vault & Autocomplete, Ambient Canvas
// Backlight, and Living Latent Shimmer.

import AppKit
import CryptoKit
import ImageIO
import Siliconed
import SwiftUI

// MARK: - Central Personalization Hub

@MainActor @Observable
final class StudioHub {
    static let shared = StudioHub()

    private static let customStylesKey = "studio.customStyles"
    private static let selectedStyleKey = "studio.selectedStyle"
    private static let selectedCameraKey = "studio.selectedCamera"
    private static let selectedLensKey = "studio.selectedLens"
    private static let selectedLightingKey = "studio.selectedLighting"
    private static let loraTriggersKey = "studio.loraTriggers"
    private static let loraAutoTriggersKey = "studio.loraAutoTriggers"
    private static let favoritesKey = "studio.favorites"
    private static let ambientBacklightKey = "studio.ambientBacklight"
    private static let autoPolishKey = "studio.autoPolish"

    // MARK: Studio Theme

    var theme: StudioTheme = Palette.activeTheme {
        didSet {
            guard theme != oldValue else { return }
            Palette.activeTheme = theme
            UserDefaults.standard.set(theme.rawValue, forKey: Palette.themeKey)
            MainWindow.shared.refreshChrome()
            LabWindow.shared.refreshChrome()
            SettingsWindow.shared.refreshChrome()
        }
    }

    // MARK: Cinema Camera & Optics Rig (Higgsfield-Inspired)

    struct GearPreset: Identifiable, Equatable {
        let id: String
        let name: String
        let badge: String
        let specTag: String
        let promptPhrase: String
        let symbol: String
        let paletteHex: [Int]
    }

    static let cameraBodies: [GearPreset] = [
        GearPreset(
            id: "none",
            name: "Default Sensor",
            badge: "AUTO",
            specTag: "MODEL NATIVE",
            promptPhrase: "",
            symbol: "camera",
            paletteHex: [0x2B2F3C, 0x171922]
        ),
        GearPreset(
            id: "alexa35",
            name: "ARRI Alexa 35",
            badge: "ALEXA 35",
            specTag: "SUPER 35 · 17 STOPS",
            promptPhrase: "shot on ARRI Alexa 35 cinema camera, 17 stops of dynamic range, organic cinema color science, creamy highlight roll-off",
            symbol: "video.fill",
            paletteHex: [0x2F6F6D, 0x132A31]
        ),
        GearPreset(
            id: "vraptor",
            name: "RED V-Raptor 8K",
            badge: "V-RAPTOR",
            specTag: "8K VV · RAZOR",
            promptPhrase: "shot on RED V-Raptor 8K VV, tack-sharp micro-detail, crisp cinema contrast, deep shadow separation",
            symbol: "camera.metering.center.weighted",
            paletteHex: [0xB91C1C, 0x381219]
        ),
        GearPreset(
            id: "venice2",
            name: "Sony Venice 2",
            badge: "VENICE 2",
            specTag: "FULL FRAME · IMAX",
            promptPhrase: "shot on Sony Venice 2 full-frame cinema camera, lush natural skin tones, clean low-light fidelity",
            symbol: "film.stack",
            paletteHex: [0x4338CA, 0x1E1B4B]
        ),
        GearPreset(
            id: "portra400",
            name: "Kodak Portra 400",
            badge: "PORTRA 400",
            specTag: "35MM FILM · WARM",
            promptPhrase: "shot on 35mm Kodak Portra 400 color negative film, fine organic silver grain, warm golden highlights",
            symbol: "film",
            paletteHex: [0xD97706, 0x542B14]
        ),
        GearPreset(
            id: "cinestill800t",
            name: "CineStill 800T",
            badge: "800T",
            specTag: "TUNGSTEN · HALATION",
            promptPhrase: "shot on CineStill 800T tungsten motion picture film, glowing red halation around practical lights, moody nocturnal palette",
            symbol: "sparkles.tv",
            paletteHex: [0x0EA5E9, 0x7F1D1D]
        ),
        GearPreset(
            id: "hasselblad",
            name: "Hasselblad X2D",
            badge: "X2D 100C",
            specTag: "MEDIUM FORMAT",
            promptPhrase: "shot on Hasselblad X2D 100C medium format camera, sculptural tonal depth, museum-grade clarity",
            symbol: "camera.aperture",
            paletteHex: [0x78716C, 0x262422]
        ),
    ]

    static let lenses: [GearPreset] = [
        GearPreset(
            id: "none",
            name: "Default Lens",
            badge: "AUTO",
            specTag: "UNCONSTRAINED",
            promptPhrase: "",
            symbol: "circle.dashed",
            paletteHex: [0x2B2F3C, 0x171922]
        ),
        GearPreset(
            id: "ultra18",
            name: "18mm Ultra-Wide",
            badge: "18MM",
            specTag: "RECTILINEAR · DEEP",
            promptPhrase: "18mm ultra-wide cinema prime lens, dramatic spatial perspective, strong leading lines",
            symbol: "arrow.up.left.and.down.right.magnifyingglass",
            paletteHex: [0x0284C7, 0x172554]
        ),
        GearPreset(
            id: "anamorphic24",
            name: "24mm Anamorphic",
            badge: "24MM ANA",
            specTag: "2.39:1 · OVAL BOKEH",
            promptPhrase: "24mm Panavision C-Series anamorphic lens, oval bokeh, subtle horizontal optical flare, widescreen cinema framing",
            symbol: "rectangle.compress.vertical",
            paletteHex: [0x0D9488, 0x312E81]
        ),
        GearPreset(
            id: "prime35",
            name: "35mm Director’s Prime",
            badge: "35MM",
            specTag: "T1.3 · NATURAL",
            promptPhrase: "35mm Master Prime cinema lens at T1.4, natural human perspective, crisp subject separation",
            symbol: "smallcircle.filled.circle",
            paletteHex: [0x65A30D, 0x1A2E05]
        ),
        GearPreset(
            id: "cooke50",
            name: "50mm Cooke S4/i",
            badge: "50MM",
            specTag: "COOKE LOOK · WARM",
            promptPhrase: "50mm Cooke S4/i prime lens, warm velvety focus rolloff, dimensional cinema character",
            symbol: "camera.macro",
            paletteHex: [0xCA8A04, 0x422006]
        ),
        GearPreset(
            id: "portrait85",
            name: "85mm f/1.4 Portrait",
            badge: "85MM F/1.4",
            specTag: "CREAMY BOKEH",
            promptPhrase: "85mm f/1.4 portrait prime lens, razor-thin focal plane, creamy circular bokeh",
            symbol: "person.crop.square",
            paletteHex: [0xDB2777, 0x4A044E]
        ),
        GearPreset(
            id: "macro100",
            name: "100mm Macro Probe",
            badge: "100MM MACRO",
            specTag: "1:1 EXTREME DETAIL",
            promptPhrase: "100mm macro probe lens, extreme tactile surface micro-texture, intimate shallow depth of field",
            symbol: "scope",
            paletteHex: [0x059669, 0x064E3B]
        ),
    ]

    static let lightings: [GearPreset] = [
        GearPreset(
            id: "none",
            name: "Natural / Prompted",
            badge: "AUTO",
            specTag: "SCENE DEFAULT",
            promptPhrase: "",
            symbol: "sun.max",
            paletteHex: [0x2B2F3C, 0x171922]
        ),
        GearPreset(
            id: "chiaroscuro",
            name: "Sculpted Chiaroscuro",
            badge: "LOW KEY",
            specTag: "SINGLE KEY + SHADOW",
            promptPhrase: "dramatic chiaroscuro cinema lighting, sculpted directional key light, deep rich shadows",
            symbol: "circle.lefthalf.filled",
            paletteHex: [0xB45309, 0x1C1917]
        ),
        GearPreset(
            id: "volumetric",
            name: "Volumetric Haze",
            badge: "ATMOS",
            specTag: "LIGHT BEAMS · DEPTH",
            promptPhrase: "atmospheric cinema haze, volumetric light shafts, layered aerial perspective",
            symbol: "sun.haze.fill",
            paletteHex: [0x6366F1, 0x1E1B4B]
        ),
        GearPreset(
            id: "goldenRim",
            name: "Golden Hour Rim",
            badge: "GOLDEN",
            specTag: "WARM BACKLIGHT",
            promptPhrase: "low golden-hour sun backlight, luminous edge rim light, warm atmospheric bounce",
            symbol: "sun.horizon.fill",
            paletteHex: [0xF59E0B, 0x7C2D12]
        ),
        GearPreset(
            id: "wetNeon",
            name: "Wet Neon Practical",
            badge: "NEON",
            specTag: "CYAN & TUNGSTEN",
            promptPhrase: "practical neon signage lighting, wet specular reflections, moody cyan and warm tungsten contrast",
            symbol: "bolt.horizontal.fill",
            paletteHex: [0x06B6D4, 0x701A75]
        ),
        GearPreset(
            id: "softbox",
            name: "Commercial Softbox",
            badge: "STUDIO",
            specTag: "DIFFUSED KEY",
            promptPhrase: "large overhead diffused studio softbox, crisp eye catchlights, clean editorial fill",
            symbol: "light.cylindrical.ceiling.fill",
            paletteHex: [0x64748B, 0x1E293B]
        ),
    ]

    var selectedCameraId: String = UserDefaults.standard.string(forKey: StudioHub.selectedCameraKey) ?? "none" {
        didSet {
            guard selectedCameraId != oldValue else { return }
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(selectedCameraId, forKey: Self.selectedCameraKey)
            }
        }
    }

    var selectedLensId: String = UserDefaults.standard.string(forKey: StudioHub.selectedLensKey) ?? "none" {
        didSet {
            guard selectedLensId != oldValue else { return }
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(selectedLensId, forKey: Self.selectedLensKey)
            }
        }
    }

    var selectedLightingId: String = UserDefaults.standard.string(forKey: StudioHub.selectedLightingKey) ?? "none" {
        didSet {
            guard selectedLightingId != oldValue else { return }
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(selectedLightingId, forKey: Self.selectedLightingKey)
            }
        }
    }

    var activeCamera: GearPreset {
        Self.cameraBodies.first { $0.id == selectedCameraId } ?? Self.cameraBodies[0]
    }

    var activeLens: GearPreset {
        Self.lenses.first { $0.id == selectedLensId } ?? Self.lenses[0]
    }

    var activeLighting: GearPreset {
        Self.lightings.first { $0.id == selectedLightingId } ?? Self.lightings[0]
    }

    var hasActiveOptics: Bool {
        selectedCameraId != "none" || selectedLensId != "none" || selectedLightingId != "none"
    }

    var opticsSummaryBadge: String {
        var tags: [String] = []
        if activeCamera.id != "none" { tags.append(activeCamera.badge) }
        if activeLens.id != "none" { tags.append(activeLens.badge) }
        if activeLighting.id != "none" { tags.append(activeLighting.badge) }
        return tags.joined(separator: " · ")
    }

    func resetOptics() {
        selectedCameraId = "none"
        selectedLensId = "none"
        selectedLightingId = "none"
    }

    // MARK: Style Presets

    struct StylePreset: Identifiable, Codable, Equatable {
        var id: String
        var name: String
        var promptSuffix: String
        var symbol: String
        var paletteHex: [Int]
        var isCustom: Bool = false
    }

    static let builtInStyles: [StylePreset] = [
        StylePreset(
            id: "none",
            name: "None",
            promptSuffix: "",
            symbol: "circle.slash",
            paletteHex: [0x3A3A3C, 0x1C1C1E]
        ),
        StylePreset(
            id: "film35",
            name: "35mm Film",
            promptSuffix: "35mm analog film photograph, Kodak Portra 400, natural film grain, organic halation, warm cinematic tones, shallow depth of field",
            symbol: "film",
            paletteHex: [0xD98A4E, 0x6E3B26]
        ),
        StylePreset(
            id: "studio",
            name: "Studio Strobe",
            promptSuffix: "editorial studio photography, sculpted softbox key light, subtle rim light, 85mm f/1.4 prime lens, crisp micro-contrast and lifelike texture",
            symbol: "light.cylindrical.ceiling",
            paletteHex: [0x6B8CAE, 0x223344]
        ),
        StylePreset(
            id: "editorial",
            name: "Editorial",
            promptSuffix: "high-fashion magazine editorial photography, medium format Hasselblad clarity, dramatic directional daylight, rich tonal depth",
            symbol: "camera.aperture",
            paletteHex: [0xB68F66, 0x3D2E24]
        ),
        StylePreset(
            id: "neon",
            name: "Cinematic Neon",
            promptSuffix: "anamorphic cinema still, atmospheric night mist, wet asphalt reflections, moody teal and warm tungsten neon lighting, 2.39:1 film grade",
            symbol: "sparkles.tv",
            paletteHex: [0x29A8AB, 0x6A2C70]
        ),
        StylePreset(
            id: "anime",
            name: "Anime Keyframe",
            promptSuffix: "masterpiece anime feature film keyframe, expressive cel shading, richly painted background art, luminous atmospheric sky and rim lighting",
            symbol: "sparkles",
            paletteHex: [0x5C7AEA, 0x9B5DE5]
        ),
        StylePreset(
            id: "impasto",
            name: "Oil Impasto",
            promptSuffix: "fine art oil painting on coarse linen canvas, expressive palette-knife impasto brushwork, chiaroscuro lighting, rich tactile pigment",
            symbol: "paintbrush.pointed",
            paletteHex: [0xC86D51, 0x3E4E50]
        ),
        StylePreset(
            id: "macro",
            name: "Product Macro",
            promptSuffix: "commercial luxury macro photography, precision specular highlights, tack-sharp focal plane, creamy bokeh, clean studio reflections",
            symbol: "scope",
            paletteHex: [0x52B788, 0x1B4332]
        ),
        StylePreset(
            id: "monochrome",
            name: "Monochrome",
            promptSuffix: "timeless silver gelatin black and white photography, Leica M Monochrom, deep velvety blacks, luminous silver highlights, fine grain",
            symbol: "circle.lefthalf.filled",
            paletteHex: [0x8E8E93, 0x2C2C2E]
        ),
    ]

    var selectedStyleId: String = UserDefaults.standard.string(forKey: StudioHub.selectedStyleKey) ?? "none" {
        didSet {
            guard selectedStyleId != oldValue else { return }
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(selectedStyleId, forKey: Self.selectedStyleKey)
            }
        }
    }

    var customStyles: [StylePreset] = StudioHub.loadCustomStyles() {
        didSet {
            if EveryImage.shared.folder != nil, let data = try? JSONEncoder().encode(customStyles) {
                UserDefaults.standard.set(data, forKey: Self.customStylesKey)
            }
        }
    }

    private static func loadCustomStyles() -> [StylePreset] {
        guard let data = UserDefaults.standard.data(forKey: customStylesKey),
              let decoded = try? JSONDecoder().decode([StylePreset].self, from: data) else { return [] }
        return decoded
    }

    var allStyles: [StylePreset] { Self.builtInStyles + customStyles }

    var activeStyle: StylePreset {
        allStyles.first { $0.id == selectedStyleId } ?? Self.builtInStyles[0]
    }

    func localizedStyleName(_ preset: StylePreset) -> String {
        if preset.isCustom { return preset.name }
        switch preset.id {
        case "none": return String(localized: "None")
        case "film35": return String(localized: "35mm Film")
        case "studio": return String(localized: "Studio Strobe")
        case "editorial": return String(localized: "Editorial")
        case "neon": return String(localized: "Cinematic Neon")
        case "anime": return String(localized: "Anime Keyframe")
        case "impasto": return String(localized: "Oil Impasto")
        case "macro": return String(localized: "Product Macro")
        case "monochrome": return String(localized: "Monochrome")
        default: return preset.name
        }
    }

    func addCustomStyle(name: String, suffix: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedSuffix.isEmpty else { return }
        let preset = StylePreset(
            id: "custom-" + UUID().uuidString,
            name: trimmedName,
            promptSuffix: trimmedSuffix,
            symbol: "wand.and.stars",
            paletteHex: [0x7B61FF, 0x2E2A5C],
            isCustom: true
        )
        customStyles.append(preset)
        selectedStyleId = preset.id
    }

    func deleteCustomStyle(_ preset: StylePreset) {
        customStyles.removeAll { $0.id == preset.id }
        if selectedStyleId == preset.id { selectedStyleId = "none" }
    }

    // MARK: LoRA Thumbnails & Trigger Words

    var loraTriggers: [String: String] = UserDefaults.standard.dictionary(forKey: StudioHub.loraTriggersKey) as? [String: String] ?? [:] {
        didSet {
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(loraTriggers, forKey: Self.loraTriggersKey)
            }
        }
    }

    var loraAutoTriggers: [String: Bool] = UserDefaults.standard.dictionary(forKey: StudioHub.loraAutoTriggersKey) as? [String: Bool] ?? [:] {
        didSet {
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(loraAutoTriggers, forKey: Self.loraAutoTriggersKey)
            }
        }
    }

    @ObservationIgnored private var sidecarThumbnails: [String: NSImage?] = [:]
    @ObservationIgnored private var sidecarTriggersChecked: Set<String> = []

    private func loraKey(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    func triggerWords(for path: String) -> String {
        let key = loraKey(path)
        if let saved = loraTriggers[key] { return saved }
        if !sidecarTriggersChecked.contains(path) {
            sidecarTriggersChecked.insert(path)
            if let discovered = Self.discoverSidecarTriggers(for: path), !discovered.isEmpty {
                loraTriggers[key] = discovered
                return discovered
            }
        }
        return ""
    }

    func setTriggerWords(_ words: String, for path: String) {
        loraTriggers[loraKey(path)] = words.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func autoTrigger(for path: String) -> Bool {
        loraAutoTriggers[loraKey(path)] ?? true
    }

    func setAutoTrigger(_ on: Bool, for path: String) {
        loraAutoTriggers[loraKey(path)] = on
    }

    func loraThumbnail(for path: String, history: [Entry]) -> NSImage? {
        if let cached = sidecarThumbnails[path] {
            if let img = cached { return img }
        } else {
            let loaded = Self.discoverSidecarImage(for: path)
            sidecarThumbnails[path] = .some(loaded)
            if let loaded { return loaded }
        }
        let targetName = loraKey(path)
        if let match = history.first(where: { entry in
            entry.settings.loras.contains { URL(fileURLWithPath: $0.path).lastPathComponent == targetName }
        }) {
            return NSImage(cgImage: match.vignette, size: .zero)
        }
        return nil
    }

    private static func discoverSidecarImage(for path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let candidates = [
            "\(stem).preview.png", "\(stem).preview.jpg", "\(stem).preview.jpeg", "\(stem).preview.webp",
            "\(stem).png", "\(stem).jpg", "\(stem).jpeg", "\(stem).webp",
        ]
        for file in candidates {
            let candidate = dir.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: candidate.path),
                  let src = CGImageSourceCreateWithURL(candidate as CFURL, nil) else { continue }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 160,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                return NSImage(cgImage: cg, size: .zero)
            }
        }
        return nil
    }

    private static func discoverSidecarTriggers(for path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        for ext in ["civitai.info", "json"] {
            let infoURL = dir.appendingPathComponent("\(stem).\(ext)")
            guard let data = try? Data(contentsOf: infoURL),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let words = obj["trainedWords"] as? [String], !words.isEmpty {
                return words.joined(separator: ", ")
            }
            if let words = obj["activation text"] as? String, !words.isEmpty {
                return words
            }
        }
        return nil
    }

    /// Combines the user's prompt with any auto-enabled LoRA trigger words, Cinema Camera & Optics Rig, and Style Preset.
    func decoratedPrompt(_ basePrompt: String, loras: [LoRASlot]) -> String {
        var parts: [String] = []
        let trimmed = basePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return basePrompt }

        for slot in loras where !slot.path.isEmpty && autoTrigger(for: slot.path) {
            let words = triggerWords(for: slot.path)
            if !words.isEmpty, !trimmed.localizedCaseInsensitiveContains(words) {
                parts.append(words)
            }
        }
        parts.append(trimmed)

        for gear in [activeCamera, activeLens, activeLighting] where !gear.promptPhrase.isEmpty {
            if !trimmed.localizedCaseInsensitiveContains(gear.promptPhrase) {
                parts.append(gear.promptPhrase)
            }
        }

        let style = activeStyle
        if !style.promptSuffix.isEmpty, !trimmed.localizedCaseInsensitiveContains(style.promptSuffix) {
            parts.append(style.promptSuffix)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Favorites

    var favoriteKeys: Set<String> = Set(UserDefaults.standard.stringArray(forKey: StudioHub.favoritesKey) ?? []) {
        didSet {
            if EveryImage.shared.folder != nil {
                UserDefaults.standard.set(Array(favoriteKeys), forKey: Self.favoritesKey)
            }
        }
    }

    nonisolated static func fingerprint(seed: UInt64, width: Int, height: Int, prompt: String) -> String {
        let raw = "\(seed)|\(width)x\(height)|\(prompt)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    func fingerprint(for entry: Entry) -> String {
        Self.fingerprint(seed: entry.seed, width: entry.width, height: entry.height, prompt: entry.settings.prompt)
    }

    func isFavorite(_ entry: Entry) -> Bool {
        favoriteKeys.contains(fingerprint(for: entry))
    }

    func toggleFavorite(_ entry: Entry) {
        let key = fingerprint(for: entry)
        if favoriteKeys.contains(key) {
            favoriteKeys.remove(key)
        } else {
            favoriteKeys.insert(key)
        }
    }

    // MARK: Ambient Canvas Backlight

    var ambientBacklight: Bool = (UserDefaults.standard.object(forKey: StudioHub.ambientBacklightKey) as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(ambientBacklight, forKey: Self.ambientBacklightKey)
        }
    }

    struct AuraColors: Equatable {
        var primary: Color
        var secondary: Color
    }

    @ObservationIgnored private var auraCache: [UUID: AuraColors] = [:]

    func aura(for entry: Entry?) -> AuraColors? {
        guard let entry else { return nil }
        if let cached = auraCache[entry.id] { return cached }
        let sampled = Self.sampleAura(from: entry.vignette)
        auraCache[entry.id] = sampled
        return sampled
    }

    static func sampleAura(from cg: CGImage) -> AuraColors {
        let side = 6
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return AuraColors(primary: Palette.live.opacity(0.3), secondary: .purple.opacity(0.2))
        }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        var r1 = 0.0, g1 = 0.0, b1 = 0.0, w1 = 0.0
        var r2 = 0.0, g2 = 0.0, b2 = 0.0, w2 = 0.0
        for y in 0..<side {
            for x in 0..<side {
                let idx = (y * side + x) * 4
                let r = Double(pixels[idx]) / 255.0
                let g = Double(pixels[idx + 1]) / 255.0
                let b = Double(pixels[idx + 2]) / 255.0
                let maxC = max(r, g, b), minC = min(r, g, b)
                let sat = maxC > 0 ? (maxC - minC) / maxC : 0
                let weight = 0.25 + sat * 1.75
                if x + y < side {
                    r1 += r * weight; g1 += g * weight; b1 += b * weight; w1 += weight
                } else {
                    r2 += r * weight; g2 += g * weight; b2 += b * weight; w2 += weight
                }
            }
        }
        let c1 = w1 > 0 ? Color(red: r1 / w1, green: g1 / w1, blue: b1 / w1) : Palette.live
        let c2 = w2 > 0 ? Color(red: r2 / w2, green: g2 / w2, blue: b2 / w2) : c1
        return AuraColors(primary: c1, secondary: c2)
    }

    // MARK: Inline Prompt Polisher & Auto-Polish

    var autoPolish: Bool = UserDefaults.standard.bool(forKey: StudioHub.autoPolishKey) {
        didSet { UserDefaults.standard.set(autoPolish, forKey: Self.autoPolishKey) }
    }
    var isPolishing = false
    var polishLoadingFraction: Double?
    var prePolishPrompt: String?
    var polishNotice: String?

    func canPolish(_ app: AppState) -> Bool {
        !isPolishing && !app.promptIsEmpty && !app.busy
    }

    func revertPolish(on app: AppState) {
        guard let original = prePolishPrompt else { return }
        MainWindow.shared.setPrompt(original, of: app, action: String(localized: "Revert Polish"))
        prePolishPrompt = nil
        polishNotice = nil
    }

    func polishPrompt(on app: AppState, then after: (@MainActor () -> Void)? = nil) {
        let typed = app.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty, !isPolishing else {
            after?()
            return
        }
        let lab = LabModel.shared
        lab.refresh()
        guard lab.pause(rendering: app.busy) == nil, !lab.isWriting, let family = app.card?.family ?? lab.target else {
            if let pause = lab.pause(rendering: app.busy) {
                app.flash(LabModel.presentation(pause).sentence)
            }
            after?()
            return
        }

        let capacity = app.promptNamesImages ? app.maxReferences : 0
        let (input, guarded) = LabModel.rewriteInput(typed, capacity: capacity)
        isPolishing = true
        polishLoadingFraction = nil
        polishNotice = nil
        prePolishPrompt = typed

        lab.writeForRemote(input, for: family, guarded: guarded) { [weak self] event in
            guard let self else { return }
            switch event {
            case .loading(let fraction):
                self.polishLoadingFraction = fraction
            case .text(let partial):
                self.polishLoadingFraction = nil
                app.prompt = partial
            }
        } finish: { [weak self] outcome in
            guard let self else { return }
            Task { @MainActor in
                await lab.writer.release()
                self.isPolishing = false
                self.polishLoadingFraction = nil
                switch outcome {
                case .written(let result):
                    MainWindow.shared.setPrompt(result.text, of: app, action: String(localized: "Polish Prompt"))
                    self.polishNotice = result.notice
                    after?()
                case .failed(_, let message):
                    if let prev = self.prePolishPrompt { app.prompt = prev }
                    self.prePolishPrompt = nil
                    app.flash(message)
                case .stoppedByRender:
                    if let prev = self.prePolishPrompt { app.prompt = prev }
                    self.prePolishPrompt = nil
                }
            }
        }
    }

    // MARK: Main-Window Subject Sheet Hook

    var subjectDraft: SubjectDraft?

    func beginNamingSubject(from source: SubjectSource, app: AppState) {
        let lib = MainWindow.shared.local.subjects
        guard let draft = SubjectDraft(new: source, taken: lib.all.map(\.name)) else {
            app.flash(String(localized: "This image can’t be read"))
            return
        }
        subjectDraft = draft
    }

    func editSubject(_ subject: NamedSubjects.Subject) {
        let lib = MainWindow.shared.local.subjects
        subjectDraft = SubjectDraft(editing: subject, library: lib)
    }

    func chooseFileForNewSubject(app: AppState) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        beginNamingSubject(from: .file(url), app: app)
    }
}

// MARK: - Studio Theme Switcher Pill & Popover

struct StudioThemePill: View {
    @State private var open = false
    @State private var hovering = false
    private var hub: StudioHub { .shared }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = hub.theme
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.ctaGradient(for: scheme))
                    .frame(width: 9, height: 9)
                    .shadow(color: Palette.live.opacity(0.6), radius: 4)
                Text(theme.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(hovering || open ? Palette.surfaceElevated : Palette.surface))
            .overlay(Capsule().strokeBorder(Palette.specularRim(for: scheme, active: open), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .popover(isPresented: $open, arrowEdge: .bottom) {
            StudioThemePopover { open = false }
        }
        .help("Switch Studio Theme & Atmosphere")
        .accessibilityLabel(Text("Studio Theme"))
    }
}

struct StudioThemePopover: View {
    let done: () -> Void
    private var hub: StudioHub { .shared }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let _ = hub.theme
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Studio Theme")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: "SILICONED STUDIO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                ForEach(StudioTheme.allCases) { item in
                    let selected = hub.theme == item
                    Button {
                        withAnimation(Motion.pick(.easeInOut(duration: 0.2))) {
                            hub.theme = item
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ThemeMiniatureSwatch(theme: item)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.callout.weight(.semibold))
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Palette.live)
                                    .imageScale(.medium)
                            }
                        }
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? Palette.live.opacity(0.12) : Palette.well)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? Palette.live.opacity(0.75) : Palette.hairline, lineWidth: selected ? 1.5 : 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Toggle(isOn: Bindable(hub).ambientBacklight) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ambient Backlight").font(.callout.weight(.medium))
                    Text("Samples atmospheric color glow from the active canvas image")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Palette.control)
        }
        .padding(14)
        .frame(width: 320)
    }
}

private struct ThemeMiniatureSwatch: View {
    let theme: StudioTheme

    var body: some View {
        let hexes = theme.swatchHexes
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: hexes[0]))
                .frame(width: 44, height: 34)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 2.5) {
                        Circle().fill(.white.opacity(0.28)).frame(width: 4, height: 4)
                        Circle().fill(.white.opacity(0.28)).frame(width: 4, height: 4)
                    }
                    .padding(5)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                )

            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: hexes[1]), Color(hex: hexes[2])],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 22, height: 9)
                .padding(5)
        }
    }
}

// MARK: - Higgsfield-Style Cinema Camera & Optics Rig Pill & Popover

struct CameraPill: View {
    @Bindable var app: AppState
    @State private var open = false
    private var hub: StudioHub { .shared }

    var body: some View {
        let _ = hub.theme
        let active = hub.hasActiveOptics
        Pill(isPresented: $open) {
            if active {
                Circle()
                    .fill(Palette.live)
                    .frame(width: 7, height: 7)
                Text(verbatim: hub.opticsSummaryBadge)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            } else {
                Image(systemName: "camera.aperture").imageScale(.small)
                Text("Optics")
            }
        } choices: {
            OpticsPopover { open = false }
        }
        .help("Cinema Camera, Lens & Lighting Rig — composes authentic optical look into the prompt")
    }
}

private struct OpticsPopover: View {
    let done: () -> Void
    private var hub: StudioHub { .shared }
    @State private var tab: RigTab = .camera

    enum RigTab: String, CaseIterable, Identifiable {
        case camera
        case lens
        case lighting

        var id: String { rawValue }
        var title: String {
            switch self {
            case .camera: String(localized: "Camera & Stock")
            case .lens: String(localized: "Lens & Focal")
            case .lighting: String(localized: "Lighting")
            }
        }
        var symbol: String {
            switch self {
            case .camera: "video.fill"
            case .lens: "camera.aperture"
            case .lighting: "sun.haze.fill"
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        let _ = hub.theme
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "camera.aperture")
                    .foregroundStyle(Palette.live)
                    .font(.callout.weight(.semibold))
                Text("Cinema Optics Rig")
                    .font(.callout.weight(.semibold))
                Spacer()
                if hub.hasActiveOptics {
                    Button("Reset") { hub.resetOptics() }
                        .buttonStyle(.chartLink)
                        .font(.caption.weight(.semibold))
                }
            }

            // Active rig readout bar
            HStack(spacing: 8) {
                RigReadoutChip(label: "BODY", value: hub.activeCamera.badge, active: hub.activeCamera.id != "none") {
                    tab = .camera
                }
                RigReadoutChip(label: "LENS", value: hub.activeLens.badge, active: hub.activeLens.id != "none") {
                    tab = .lens
                }
                RigReadoutChip(label: "LIGHT", value: hub.activeLighting.badge, active: hub.activeLighting.id != "none") {
                    tab = .lighting
                }
            }

            // Tab selector
            HStack(spacing: 4) {
                ForEach(RigTab.allCases) { item in
                    let selected = tab == item
                    Button {
                        withAnimation(Motion.pick(.easeInOut(duration: 0.15))) { tab = item }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.symbol).font(.system(size: 11, weight: .semibold))
                            Text(item.title).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(selected ? Palette.onLive : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? AnyShapeStyle(Palette.live) : AnyShapeStyle(Color.clear))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.well))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.hairline))

            // Gear grid
            LazyVGrid(columns: columns, spacing: 8) {
                switch tab {
                case .camera:
                    ForEach(StudioHub.cameraBodies) { gear in
                        GearCardTile(gear: gear, selected: hub.selectedCameraId == gear.id) {
                            hub.selectedCameraId = gear.id
                        }
                    }
                case .lens:
                    ForEach(StudioHub.lenses) { gear in
                        GearCardTile(gear: gear, selected: hub.selectedLensId == gear.id) {
                            hub.selectedLensId = gear.id
                        }
                    }
                case .lighting:
                    ForEach(StudioHub.lightings) { gear in
                        GearCardTile(gear: gear, selected: hub.selectedLightingId == gear.id) {
                            hub.selectedLightingId = gear.id
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 400)
    }
}

private struct RigReadoutChip: View {
    let label: String
    let value: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(verbatim: value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(active ? Palette.live : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? Palette.live.opacity(0.10) : Palette.well)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(active ? Palette.live.opacity(0.55) : Palette.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GearCardTile: View {
    let gear: StudioHub.GearPreset
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(
                            colors: gear.paletteHex.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 40)

                    HStack {
                        Text(verbatim: gear.badge)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.42)))
                        Spacer()
                    }
                    .padding(6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: gear.name)
                        .font(.caption.weight(selected ? .semibold : .medium))
                        .lineLimit(1)
                    Text(verbatim: gear.specTag)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? Palette.live.opacity(0.13)
                                   : hovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? Palette.live : hovering ? Color.primary.opacity(0.25) : Palette.hairline,
                                  lineWidth: selected ? 1.6 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(gear.promptPhrase.isEmpty ? Text("No optical modifier added") : Text(verbatim: gear.promptPhrase))
    }
}

// MARK: - Style Presets Pill & Popover

struct StylePill: View {
    @Bindable var app: AppState
    @State private var open = false
    private var hub: StudioHub { .shared }

    var body: some View {
        let _ = hub.theme
        let style = hub.activeStyle
        let active = style.id != "none"
        Pill(isPresented: $open) {
            if active {
                Circle()
                    .fill(LinearGradient(
                        colors: style.paletteHex.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 10, height: 10)
                Text(verbatim: hub.localizedStyleName(style)).lineLimit(1)
            } else {
                Image(systemName: "paintpalette").imageScale(.small)
                Text("Style")
            }
        } choices: {
            StylePopover(app: app) { open = false }
        }
        .help("Visual style preset layered onto the prompt")
    }
}

private struct StylePopover: View {
    @Bindable var app: AppState
    let done: () -> Void
    private var hub: StudioHub { .shared }
    @State private var addingCustom = false
    @State private var customName = ""
    @State private var customSuffix = ""

    private let columns = [
        GridItem(.fixed(112), spacing: 8),
        GridItem(.fixed(112), spacing: 8),
        GridItem(.fixed(112), spacing: 8),
    ]

    var body: some View {
        let _ = hub.theme
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Style")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if hub.selectedStyleId != "none" {
                    Button("Reset") { hub.selectedStyleId = "none" }
                        .buttonStyle(.chartLink)
                        .font(.caption)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(hub.allStyles) { preset in
                    StyleCardTile(
                        preset: preset,
                        title: hub.localizedStyleName(preset),
                        selected: hub.selectedStyleId == preset.id
                    ) {
                        hub.selectedStyleId = preset.id
                        done()
                    } onDelete: {
                        if preset.isCustom { hub.deleteCustomStyle(preset) }
                    }
                }
            }

            Divider()

            DisclosureGroup(isExpanded: $addingCustom) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $customName)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                    TextField("Prompt", text: $customSuffix)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    HStack {
                        Spacer()
                        Button("Save") {
                            hub.addCustomStyle(name: customName, suffix: customSuffix)
                            customName = ""
                            customSuffix = ""
                            addingCustom = false
                        }
                        .buttonStyle(.prominent)
                        .controlSize(.small)
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || customSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Custom style")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 380)
    }
}

private struct StyleCardTile: View {
    let preset: StudioHub.StylePreset
    let title: String
    let selected: Bool
    let action: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(
                            colors: preset.paletteHex.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 44)
                    Image(systemName: preset.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(8)
                }
                Text(verbatim: title)
                    .font(.caption.weight(selected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? Palette.live.opacity(0.14)
                                   : hovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? Palette.live : hovering ? Color.primary.opacity(0.25) : Palette.hairline,
                                  lineWidth: selected ? 1.6 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(preset.promptSuffix.isEmpty ? Text("No style added") : Text(verbatim: preset.promptSuffix))
        .contextMenu {
            if preset.isCustom {
                Button("Remove", role: .destructive, action: onDelete)
            }
        }
    }
}

// MARK: - Composer @Subject Vault, Autocomplete & Cited Chips

struct SubjectsVaultPill: View {
    @Bindable var app: AppState
    @State private var open = false

    var body: some View {
        let subjects = MainWindow.shared.local.subjects
        let _ = subjects.version
        Pill(isPresented: $open) {
            Image(systemName: "at").imageScale(.small)
            if !subjects.all.isEmpty {
                Text(verbatim: "\(subjects.all.count)")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } choices: {
            SubjectsVaultPopover(app: app) { open = false }
        }
        .help("Named @subjects vault — reusable characters, objects, garments and styles")
        .accessibilityLabel(Text("Subjects"))
    }
}

private struct SubjectsVaultPopover: View {
    @Bindable var app: AppState
    let done: () -> Void
    private var hub: StudioHub { .shared }

    var body: some View {
        let subjects = MainWindow.shared.local.subjects
        let _ = subjects.version
        let _ = hub.theme
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subjects")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !app.promptNamesImages, let qwen = app.visibleReady.first(where: { $0.family == .qwenImage21 }) {
                    Button {
                        app.identifier = qwen.id
                    } label: {
                        Text(verbatim: "→ \(qwen.name)")
                            .font(.caption)
                    }
                    .buttonStyle(.chartLink)
                    .help("Switch to Qwen-Image-2.1 to render @subjects")
                }
            }

            if subjects.all.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Save characters, vehicles, props or outfits as @names to cite directly in your prompt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(subjects.all) { s in
                            SubjectVaultRow(subject: s, subjects: subjects) {
                                insertMention(s.name)
                                done()
                            } onEdit: {
                                done()
                                hub.editSubject(s)
                            } onDelete: {
                                subjects.delete(s)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    done()
                    hub.chooseFileForNewSubject(app: app)
                } label: {
                    Label("New Subject…", systemImage: "plus")
                }
                .buttonStyle(.chartLink)
                .font(.callout)

                Spacer()

                if let entry = app.selectedEntry, entry.grid == nil {
                    Button {
                        done()
                        hub.beginNamingSubject(from: .png(entry.png), app: app)
                    } label: {
                        Label("From Canvas", systemImage: "sparkles.rectangle.stack")
                    }
                    .buttonStyle(.chartLink)
                    .font(.callout)
                }
            }
        }
        .padding(14)
        .frame(width: 330)
    }

    private func insertMention(_ name: String) {
        let token = "@\(name)"
        let trimmed = app.prompt.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            app.prompt = token + " "
        } else if app.prompt.hasSuffix(" ") {
            app.prompt += token + " "
        } else {
            app.prompt += " " + token + " "
        }
    }
}

private struct SubjectVaultRow: View {
    let subject: NamedSubjects.Subject
    let subjects: SubjectLibrary
    let onInsert: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onInsert) {
                HStack(spacing: 10) {
                    if let thumb = subjects.thumbnail(subject) {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(subject.kind.color, lineWidth: 1.2))
                    } else {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Palette.well)
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: subject.kind.symbol).foregroundStyle(subject.kind.color))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "@\(subject.name)")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 4) {
                            Image(systemName: subject.kind.symbol)
                                .font(.system(size: 10))
                            Text(verbatim: subject.kind.label)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hovering {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Edit")
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { hovering = $0 }
    }
}

/// Shows thumbnail chips above the prompt for any `@subjects` currently cited in `app.prompt`,
/// plus live `@` autocomplete suggestions when typing an `@` mention at the end of the prompt.
struct ComposerSubjectsOverlay: View {
    @Bindable var app: AppState

    private var trailingMentionQuery: String? {
        guard let atIndex = app.prompt.lastIndex(of: "@") else { return nil }
        if atIndex > app.prompt.startIndex {
            let prev = app.prompt[app.prompt.index(before: atIndex)]
            if prev.isLetter || prev.isNumber { return nil }
        }
        let tail = String(app.prompt[app.prompt.index(after: atIndex)...])
        if tail.contains(where: { $0.isWhitespace }) { return nil }
        return tail
    }

    var body: some View {
        let subjects = MainWindow.shared.local.subjects
        let _ = subjects.version
        let mentions = NamedSubjects.mentions(in: app.prompt)
        let cited = mentions.compactMap { m in subjects.subject(named: m.name) }
        let uniqueCited = cited.reduce(into: [NamedSubjects.Subject]()) { acc, s in
            if !acc.contains(where: { $0.id == s.id }) { acc.append(s) }
        }
        let query = trailingMentionQuery
        let matches: [NamedSubjects.Subject] = if let query {
            subjects.all.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                .filter { $0.id != NamedSubjects.key(query) }
        } else {
            []
        }

        if !uniqueCited.isEmpty || !matches.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !uniqueCited.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(uniqueCited) { s in
                                HStack(spacing: 6) {
                                    if let thumb = subjects.thumbnail(s) {
                                        Image(nsImage: thumb)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 22, height: 22)
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    }
                                    Text(verbatim: "@\(s.name)")
                                        .font(.caption.weight(.semibold))
                                    Text(verbatim: s.kind.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 4)
                                .padding(.trailing, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(s.kind.color.opacity(0.16)))
                                .overlay(Capsule().strokeBorder(s.kind.color.opacity(0.45), lineWidth: 1))
                                .onTapGesture { StudioHub.shared.editSubject(s) }
                            }
                            if !app.promptNamesImages, let qwen = app.visibleReady.first(where: { $0.family == .qwenImage21 }) {
                                Button {
                                    app.identifier = qwen.id
                                } label: {
                                    Label(qwen.name, systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .help("Switch to Qwen-Image-2.1 so the model reads your @subjects")
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }

                if !matches.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(matches.prefix(6)) { s in
                                Button {
                                    completeMention(with: s.name)
                                } label: {
                                    HStack(spacing: 5) {
                                        if let thumb = subjects.thumbnail(s) {
                                            Image(nsImage: thumb)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 18, height: 18)
                                                .clipShape(Circle())
                                        }
                                        Text(verbatim: "@\(s.name)")
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                                    .overlay(Capsule().strokeBorder(Palette.hairline))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
        }
    }

    private func completeMention(with name: String) {
        guard let atIndex = app.prompt.lastIndex(of: "@") else { return }
        app.prompt = String(app.prompt[..<atIndex]) + "@\(name) "
    }
}

// MARK: - Ambient Canvas Backdrop & Living Latent Shimmer

struct AmbientBackdropView: View {
    let app: AppState
    private var hub: StudioHub { .shared }
    @Environment(\.colorScheme) private var colorScheme

    private var activeAura: StudioHub.AuraColors? {
        guard hub.ambientBacklight else { return nil }
        if app.inProgress, app.followsRender, let preview = app.preview {
            return StudioHub.sampleAura(from: preview)
        }
        return hub.aura(for: app.selectedEntry)
    }

    private var studioAmbientColors: (Color, Color) {
        switch hub.theme {
        case .cinemaLime:
            return (Color(hex: 0xD4FF33), Color(hex: 0x10B981))
        case .electricStudio:
            return (Color(hex: 0xEC4899), Color(hex: 0x6366F1))
        case .siliconedIndigo:
            return (Color(hex: 0x56C0B0), Color(hex: 0x6660CB))
        }
    }

    var body: some View {
        let _ = hub.theme
        ZStack {
            Palette.canvas
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                if let aura = activeAura {
                    ZStack {
                        Circle()
                            .fill(aura.primary.opacity(colorScheme == .dark ? 0.25 : 0.15))
                            .frame(width: max(w, h) * 0.72, height: max(w, h) * 0.72)
                            .position(x: w * 0.36, y: h * 0.42)
                        Circle()
                            .fill(aura.secondary.opacity(colorScheme == .dark ? 0.20 : 0.12))
                            .frame(width: max(w, h) * 0.65, height: max(w, h) * 0.65)
                            .position(x: w * 0.66, y: h * 0.62)
                    }
                    .blur(radius: 115)
                    .transition(.opacity)
                } else if hub.ambientBacklight {
                    let (c1, c2) = studioAmbientColors
                    ZStack {
                        Ellipse()
                            .fill(c1.opacity(colorScheme == .dark ? 0.065 : 0.04))
                            .frame(width: w * 0.62, height: h * 0.40)
                            .position(x: w * 0.50, y: h * 0.08)
                        Ellipse()
                            .fill(c2.opacity(colorScheme == .dark ? 0.055 : 0.035))
                            .frame(width: w * 0.50, height: h * 0.42)
                            .position(x: w * 0.78, y: h * 0.85)
                    }
                    .blur(radius: 110)
                }
            }
        }
        .animation(Motion.pick(.easeInOut(duration: 0.55)), value: app.selectedEntry?.id)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Living subtle aurora shimmer inside the incoming image frame before step 1 decodes.
struct LatentShimmerView: View {
    let stage: Engine.Stage?
    @State private var phase = false

    var body: some View {
        let _ = StudioHub.shared.theme
        ZStack {
            Palette.well
            LinearGradient(
                colors: [
                    Palette.live.opacity(0.16),
                    Palette.sky.opacity(0.10),
                    Palette.rose.opacity(0.09),
                    Palette.live.opacity(0.16),
                ],
                startPoint: phase ? .topLeading : .bottomTrailing,
                endPoint: phase ? .bottomTrailing : .topLeading
            )
            .blur(radius: 28)
            .onAppear {
                guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }

            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Palette.live)
                    .symbolEffect(.pulse, options: .repeating, isActive: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                Text(stage?.label ?? String(localized: "Preparing…"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
