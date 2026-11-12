// Studio personalization: Signature Studio Themes (Cinema Lime, Electric Studio, Indigo & Mint),
// LoRA visual thumbnails & trigger words, Favorites, Inline Prompt Auto-Polish, Main-Composer @Subject
// Vault & Autocomplete, Ambient Canvas Backlight, and Living Latent Shimmer.

import AppKit
import CryptoKit
import ImageIO
import Siliconed
import SwiftUI

// MARK: - Central Personalization Hub

@MainActor @Observable
final class StudioHub {
    static let shared = StudioHub()

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

    /// Prepends any auto-enabled LoRA trigger words that are not already present in the user's prompt.
    func decoratedPrompt(_ basePrompt: String, loras: [LoRASlot]) -> String {
        let trimmed = basePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return basePrompt }

        var triggers: [String] = []
        for slot in loras where !slot.path.isEmpty && autoTrigger(for: slot.path) {
            let words = triggerWords(for: slot.path)
            if !words.isEmpty, !trimmed.localizedCaseInsensitiveContains(words) {
                triggers.append(words)
            }
        }
        guard !triggers.isEmpty else { return basePrompt }
        return (triggers + [trimmed]).joined(separator: ", ")
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
            HStack(spacing: 7) {
                Circle()
                    .fill(Palette.live)
                    .frame(width: 8, height: 8)
                Text(theme.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(hovering || open ? Palette.surfaceElevated : Color.primary.opacity(0.05)))
            .overlay(Capsule().strokeBorder(open ? Palette.live.opacity(0.6) : Palette.hairline, lineWidth: 1))
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

    var body: some View {
        let _ = hub.theme
        ZStack {
            Palette.canvas
            if let aura = activeAura {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack {
                        Circle()
                            .fill(aura.primary.opacity(colorScheme == .dark ? 0.22 : 0.13))
                            .frame(width: max(w, h) * 0.68, height: max(w, h) * 0.68)
                            .position(x: w * 0.36, y: h * 0.42)
                        Circle()
                            .fill(aura.secondary.opacity(colorScheme == .dark ? 0.18 : 0.10))
                            .frame(width: max(w, h) * 0.62, height: max(w, h) * 0.62)
                            .position(x: w * 0.66, y: h * 0.62)
                    }
                    .blur(radius: 120)
                    // 16-bit float Metal compositing eliminates 8-bit sRGB gradient banding on dark obsidian surfaces.
                    .drawingGroup(opaque: false, colorMode: .extendedLinear)
                }
                .transition(.opacity)
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
