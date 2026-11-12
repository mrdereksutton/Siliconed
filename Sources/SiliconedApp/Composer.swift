// Fork: **the composer** — the prompt and every setting of a render in one glass card at the foot of
// the canvas: an edit's images (or a starting image) over the prompt, then the model, the aspect
// ratio, the resolution, the LoRA stack, the settings and the batch as compact pills that show only
// the current choice (each opens its popover on a click), then « Generate ». Under them, the cost
// before the click, or what stops it. Shown on the Generate tab; Explore keeps its own form in the
// left column.

import AppKit
import Siliconed
import SwiftUI

struct Composer: View {
    @Bindable var app: AppState

    var body: some View {
        let hub = StudioHub.shared
        let _ = hub.theme
        VStack(alignment: .leading, spacing: 11) {
            if app.editingPossible, !app.references.isEmpty {
                references
            } else if let start = app.usedStart {
                StartImageRow(app: app, start: start)
            }
            ComposerSubjectsOverlay(app: app)
            prompt
            if hub.prePolishPrompt != nil && !hub.isPolishing {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(Palette.live)
                    Text("Prompt polished")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let note = hub.polishNotice {
                        Text(verbatim: "· " + note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Button("Revert") { hub.revertPolish(on: app) }
                        .buttonStyle(.chartLink)
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            SeriesSummary(app: app)

            Rectangle()
                .fill(Palette.hairline.opacity(0.65))
                .frame(height: 1)

            // Dedicated non-overlapping HStack: pills scroll cleanly inside their own clipped region on the left,
            // while GenerateButton always reserves its own crisp column on the right.
            HStack(alignment: .center, spacing: 14) {
                ScrollView(.horizontal) {
                    pillsRow
                }
                .scrollIndicators(.never)
                .fixedSize(horizontal: false, vertical: true)
                .clipped()

                GenerateButton(app: app)
                    .fixedSize()
            }

            if StatusLine.hasContent(for: app) {
                StatusLine(app: app)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 13)
        .studioCard(cornerRadius: 20, elevated: true)
        // As on the canvas: a PNG Siliconed wrote brings back its settings; on a model that edits, any
        // other image joins the edit; when a starting image is held, a dropped image replaces it.
        .dropDestination(for: DroppedImage.self) { items, _ in
            var files: [URL] = []
            var pasted: [Data] = []
            for item in items {
                switch item {
                case .file(let url) where !AppState.importable(url): files.append(url)
                case .file: break
                case .png(let data): pasted.append(data)
                }
            }
            if items.count == 1, files.count == 1, app.restoreSettings(fromPNG: files[0]) { return true }
            if app.editingPossible, !(files.isEmpty && pasted.isEmpty) {
                pasted.forEach { app.addReference(png: $0) }
                app.addReferences(files)
                return true
            }
            if app.usedStart != nil {
                if let data = pasted.first, let image = AppState.startImage(png: data, name: String(localized: "dropped image")) {
                    app.carryStart(image)
                    return true
                }
                if let url = files.first {
                    app.replaceStart(with: url)
                    return true
                }
            }
            return false
        }
    }

    private var pillsRow: some View {
        HStack(alignment: .center, spacing: 8) {
            if app.editingPossible { AttachPill(app: app) }
            SubjectsVaultPill(app: app)
            ModelPill(app: app)
            if app.references.isEmpty {
                SizePills(app: app)
            } else {
                // An edit keeps image 1's framing: its size, not a choice.
                let f = app.outputFormat
                PillFace {
                    Text(verbatim: "\(f.width) × \(f.height)").monospacedDigit()
                    Image(systemName: "lock.fill").imageScale(.small).foregroundStyle(.secondary)
                }
                .help("An edit keeps the framing of image 1: about 1 megapixel at its proportions, each side at least 512, 1024² at most")
            }
            if app.missing == nil, app.card != nil {
                LoRAPill(app: app)
                SettingsPill(app: app)
            }
            BatchPill(app: app)
        }
    }

    // MARK: The prompt and an edit's images

    /// **The prompt**: open, unboxed writing stage — two lines to seven, then it scrolls. Return makes a new
    /// line; ⌘↩ renders. On its right: the clear button (⌘Z brings the prompt back), Polish, and Prompt Lab (⌥⌘L).
    private var prompt: some View {
        let hub = StudioHub.shared
        // Dedicated HStack so TextEditor stops cleanly to the left of the Clear, Polish, and Prompt Lab buttons
        // and never runs lines of text underneath them.
        return HStack(alignment: .top, spacing: 10) {
            Text(verbatim: app.prompt + " ")
                .font(.system(size: 15.5))
                .lineLimit(7)
                .padding(.leading, 5)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                .opacity(0)
                .accessibilityHidden(true)
                .overlay {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $app.prompt)
                            .accessibilityLabel(Text("Prompt"))
                            .font(.system(size: 15.5))
                            .scrollContentBackground(.hidden)
                            .scrollIndicators(.never)
                        if app.prompt.isEmpty {
                            Text(app.references.isEmpty ? "Describe the image…" : "Say what changes…")
                                .font(.system(size: 15.5))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                }

            HStack(spacing: 6) {
                if !app.prompt.isEmpty {
                    Button {
                        hub.prePolishPrompt = nil
                        MainWindow.shared.setPrompt("", of: app, action: String(localized: "Clear Prompt"))
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            .frame(width: 24, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear the prompt (⌘Z brings it back)")
                    .accessibilityLabel(Text("Clear Prompt"))
                }

                Button {
                    hub.polishPrompt(on: app)
                } label: {
                    HStack(spacing: 3) {
                        if hub.isPolishing {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(hub.autoPolish ? Palette.onLive : (app.promptIsEmpty ? Color.secondary.opacity(0.4) : Palette.live))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                            .fill(hub.autoPolish ? Palette.live : Color.primary.opacity(0.06))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 7.5, style: .continuous).strokeBorder(Palette.hairline))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(app.promptIsEmpty && !hub.isPolishing)
                .contextMenu {
                    Toggle("Auto-Polish on Generate", isOn: Bindable(hub).autoPolish)
                    if hub.prePolishPrompt != nil {
                        Button("Revert") { hub.revertPolish(on: app) }
                    }
                }
                .help(hub.autoPolish
                      ? "Polish prompt now (Auto-Polish is ON — right-click to turn off)"
                      : "Polish prompt with the local AI writer (right-click to enable Auto-Polish)")
                .accessibilityLabel(Text("Polish Prompt"))

                Button { LabWindow.shared.openStudio() } label: {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WireKind.text.color)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7.5, style: .continuous).fill(Color.primary.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 7.5, style: .continuous).strokeBorder(Palette.hairline))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open the Prompt Lab (⌥⌘L)")
                .accessibilityLabel(Text("Prompt Lab"))
            }
            .fixedSize()
        }
    }

    /// An edit's images, numbered as the prompt names them — image 1 is the one edited.
    private var references: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(app.references.enumerated()), id: \.element.id) { n, reference in
                    ReferenceThumbnail(app: app, reference: reference, number: n + 1,
                                       last: n == app.references.count - 1)
                }
            }
        }
        .scrollIndicators(.never)
    }
}

/// **The image the render starts from** (img2img), on a model that starts from one: shown at the head of
/// the composer once the Prompt Lab (or `silicontrol start-image`) has carried one. Its thumbnail, its
/// strength from 0 to 100 % on a slider, and what the strength does here.
private struct StartImageRow: View {
    @Bindable var app: AppState
    let start: ReferenceImage
    @State private var hover = false

    var body: some View {
        let caption = app.startCaption
        HStack(alignment: .center, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Starting Image").font(.caption.weight(.semibold))
                    Text("Strength").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(verbatim: StartWords.percent(app.startStrength))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .onTapGesture(count: 2) { app.setStartStrength(app.defaultStartStrength) }
                        .help("Strength — double-click for \(StartWords.percent(app.defaultStartStrength))")
                }
                HStack(spacing: 8) {
                    Text("Faithful").font(.caption2).foregroundStyle(.tertiary)
                    Slider(value: Binding(get: { app.startStrength }, set: { app.setStartStrength($0) }), in: 0...1)
                        .controlSize(.small)
                        .accessibilityLabel(Text("Strength"))
                        .accessibilityValue(Text(verbatim: StartWords.percent(app.startStrength)))
                    Text("Free").font(.caption2).foregroundStyle(.tertiary)
                }
                .help(StartWords.explanation(app.startRedraws))
                Text(caption.text)
                    .font(.caption)
                    .foregroundStyle(caption.tone == .failure ? Palette.failure
                                     : caption.tone == .warning ? Color(nsColor: .systemOrange) : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Palette.well))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Palette.hairline))
        .contextMenu {
            Button("Reset to \(StartWords.percent(app.defaultStartStrength))") { app.setStartStrength(app.defaultStartStrength) }
            Button("Replace…") { app.chooseStartReplacement() }
            Divider()
            Button("Remove", role: .destructive) { app.removeStart() }
        }
        .dropDestination(for: DroppedImage.self) { items, _ in
            for item in items {
                switch item {
                case .file(let url) where !AppState.importable(url):
                    app.replaceStart(with: url)
                    return true
                case .file:
                    break
                case .png(let data):
                    guard let image = AppState.startImage(png: data, name: String(localized: "dropped image")) else { return false }
                    app.carryStart(image)
                    return true
                }
            }
            return false
        }
    }

    private var thumbnail: some View {
        Image(nsImage: start.vignette).resizable().scaledToFill()
            .frame(width: ReferenceThumbnail.side, height: ReferenceThumbnail.side)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(WireKind.image.color, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                if hover {
                    Button { app.removeStart() } label: {
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove: the next render starts from noise")
                    .accessibilityLabel(Text("Remove"))
                }
            }
            .onHover { hover = $0 }
            .help(Text(verbatim: "\(start.name) · \(start.width) × \(start.height)"))
            .accessibilityLabel(Text(verbatim: start.name))
    }
}

// MARK: - An edit's images

/// **« + » for an image**: the one to edit first, then the ones the prompt draws from. Greyed beyond the
/// model's count or this Mac's memory (the reason is the tooltip).
private struct AttachPill: View {
    @Bindable var app: AppState

    var body: some View {
        let refusal = app.canAddReference ? app.nextReferenceRefusal() : nil
        let enabled = app.canAddReference && refusal == nil
        PillButton { app.chooseReferences() } label: {
            Image(systemName: "photo.badge.plus")
            if !app.references.isEmpty {
                Text(verbatim: "\(app.references.count)/\(app.maxReferences)").monospacedDigit()
            }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .help(refusal.map { Text($0) }
              ?? (app.references.isEmpty ? Text("The image to edit — or drop or paste it here (⌘V)")
                                         : Text("Add an image the prompt can draw from — or drop or paste it here (⌘V)")))
        .accessibilityLabel(Text("Add an Image"))
    }
}

// MARK: - The model

/// **The model as a pill**: its name; a click opens every model with a line on what it makes, then
/// the way to the Models window and to an import.
private struct ModelPill: View {
    @Bindable var app: AppState
    @State private var open = false

    var body: some View {
        Pill(isPresented: $open) {
            Circle().fill(Palette.live).frame(width: 7, height: 7)
            Text(verbatim: app.card?.name ?? "—").lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        } choices: {
            ModelChoices(app: app) { open = false }
        }
        .help("The denoiser: the publisher’s model, or a fine-tune you imported")
    }
}

/// **Every model, with a line on what it makes**; then the way to the Models window and to an import.
private struct ModelChoices: View {
    @Bindable var app: AppState
    let done: () -> Void

    private func palette(for family: Family) -> [Color] {
        switch family {
        case .zImage: [Color(hex: 0x2563EB), Color(hex: 0x0EA5E9)]
        case .qwenImage21: [Color(hex: 0x7C3AED), Color(hex: 0xEC4899)]
        case .anima: [Color(hex: 0xF59E0B), Color(hex: 0xEF4444)]
        case .krea2: [Color(hex: 0x10B981), Color(hex: 0x14B8A6)]
        case .mossImage: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)]
        }
    }

    private func recentPreview(for card: ModelCard) -> CGImage? {
        app.history.first { $0.settings.identifier == card.id }?.vignette
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChoiceList(title: "Model", minWidth: 340) {
                ForEach(app.visibleCards) { card in
                    let installed = app.readySet.contains(card.id)
                    ChoiceRow(selected: card.id == app.identifier, enabled: true) {
                        app.identifier = card.id
                        done()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                if let preview = recentPreview(for: card) {
                                    Image(decorative: preview, scale: 1)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    LinearGradient(
                                        colors: palette(for: card.family),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    Image(systemName: Welcome.symbol(card.family))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.95))
                                }
                            }
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.hairline))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(verbatim: card.name).fontWeight(.semibold)
                                        .foregroundStyle(installed ? .primary : .secondary)
                                    if !installed {
                                        Image(systemName: "arrow.down.circle").imageScale(.small).foregroundStyle(.secondary)
                                            .help(Text("Not installed"))
                                            .accessibilityLabel(Text("Not installed"))
                                    }
                                }
                                if let blurb = ModelBlurb.text(card) {
                                    Text(verbatim: blurb).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            Divider().padding(.horizontal, 16)
            HStack {
                Button("Models…") { done(); app.managementOpen = true }
                    .help("Install, import, remove — and what each takes on disk (⇧⌘M)")
                Spacer()
                Button("Import…") { done(); app.chooseToImport() }
                    .disabled(!app.importPossible)
                    .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
            }
            .buttonStyle(.link)
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

/// What each model makes, in one line — the list's second line.
enum ModelBlurb {
    static func text(_ card: ModelCard) -> String? {
        if card.isImported { return String(localized: "Your imported fine-tune") }
        switch card.family {
        case .krea2: return String(localized: "Aesthetic images, from photography to painting")
        case .zImage: return String(localized: "Photorealistic images, fast")
        case .qwenImage21: return String(localized: "Text to image, and editing by instruction")
        case .anima: return String(localized: "Illustration, painting and anime")
        case .mossImage: return String(localized: "Text to image, beta")
        }
    }
}

// MARK: - The LoRA stack and the settings

/// **The LoRA stack as a pill**: the word and, once some are in, how many; a click opens the stack —
/// each LoRA with its strength slider, the model's LoRAs to add, and « Import… ».
private struct LoRAPill: View {
    @Bindable var app: AppState
    @State private var open = false

    var body: some View {
        Pill(isPresented: $open) {
            Image(systemName: "square.stack.3d.up").imageScale(.small)
            Text("LoRA")
            if !app.loras.isEmpty {
                Text(verbatim: "\(app.loras.count)")
                    .font(.caption.weight(.bold)).monospacedDigit()
                    .foregroundStyle(Palette.onLive)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Circle().fill(Palette.live))
            }
        } choices: {
            LoRAStack(app: app) { open = false }
                .font(.callout)
                .frame(width: 380, alignment: .leading)
        }
        .help("Add a LoRA to the stack (3 at most)")
    }
}

/// **The settings as a pill**: the steps on its face; a click opens the seed, the steps, the detail,
/// the solver and the step previews.
private struct SettingsPill: View {
    @Bindable var app: AppState
    @State private var open = false

    var body: some View {
        Pill(isPresented: $open) {
            Image(systemName: "slider.horizontal.3").imageScale(.small)
            Text("\(app.steps) steps").monospacedDigit()
            if app.fixedSeed {
                Image(systemName: "pin.fill").imageScale(.small).foregroundStyle(.secondary)
                    .help("The seed is fixed: the same image again")
                    .accessibilityLabel(Text("Fixed seed"))
            }
        } choices: {
            ChoiceList(title: "Settings") {
                RenderOptions(app: app).padding(.horizontal, 8)
            }
            .font(.callout)
            .frame(width: 340)
        }
        .help("Seed, steps, detail and solver")
        .accessibilityLabel(Text("Settings"))
    }
}

// MARK: - The batch

/// **How many images a click makes**, − and + on one pill: consecutive seeds, the prompt encoded once.
private struct BatchPill: View {
    @Bindable var app: AppState

    var body: some View {
        PillFace {
            Button { app.batch = max(1, app.batch - 1) } label: {
                Image(systemName: "minus").font(.system(size: 10, weight: .bold)).frame(width: 16, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(app.batch <= 1)
            .foregroundStyle(app.batch <= 1 ? .tertiary : .secondary)
            Text(verbatim: "\(app.batch)").monospacedDigit().frame(minWidth: 12)
            Button { app.batch = min(8, app.batch + 1) } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold)).frame(width: 16, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(app.batch >= 8)
            .foregroundStyle(app.batch >= 8 ? .tertiary : .secondary)
        }
        .help("Consecutive seeds; the prompt is encoded only once")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Batch"))
    }
}

// MARK: - Generate

/// **« Generate »**: crisp overhead-lit Studio CTA with high-contrast ink and zero neon blur;
/// cleanly recessed in neutral dark ink while something stops the render (said in the status line under it).
private struct GenerateButton: View {
    @Bindable var app: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false

    private var tooltip: String {
        guard app.missing == nil, app.card != nil else { return "⌘↩" }
        let f = app.outputFormat
        var parts = ["\(f.width) × \(f.height)"]
        if let need = app.memoryNeed { parts.append(Figures.memory(need)) }
        if let t = app.plannedCost { parts.append("≈ " + Figures.duration(t)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let blocked = app.formBlocker != nil || app.memoryRefusal != nil
        let shape = RoundedRectangle(cornerRadius: 10.5, style: .continuous)
        Button { app.render() } label: {
            HStack(spacing: 8) {
                Text(GenerateControls.title(app))
                    .font(.system(size: 14, weight: .semibold))
                Text(verbatim: "⌘↩")
                    .font(.system(size: 11.5, weight: .medium))
                    .opacity(blocked ? 0.65 : 0.68)
            }
            .foregroundStyle(blocked ? AnyShapeStyle(Color.primary.opacity(0.4)) : AnyShapeStyle(Palette.onLive))
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background {
                if blocked {
                    shape.fill(Palette.surface).overlay(shape.fill(Palette.well))
                } else {
                    shape.fill(Palette.ctaGradient(for: colorScheme))
                }
            }
            .overlay {
                if blocked {
                    shape.strokeBorder(Palette.hairline, lineWidth: 1)
                } else {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(colorScheme == .dark ? 0.24 : 0.18), .white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
            }
            .shadow(color: blocked ? .clear : .black.opacity(colorScheme == .dark ? 0.28 : 0.10),
                    radius: 2.5, y: 1)
            .brightness(hovering && !blocked ? 0.04 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(blocked)
        .onHover { hovering = $0 }
        .animation(Motion.pick(.easeOut(duration: 0.12)), value: hovering)
        .help(Text(verbatim: tooltip))
    }
}

// MARK: - The status line

/// **Under the pills, shown only when there is something actionable to report**: what stops « Generate »
/// (except an empty prompt), a memory refusal with the size this Mac renders, the measure a first render
/// waits for, or — when the canvas shows another image — the running render's step and time left.
private struct StatusLine: View {
    @Bindable var app: AppState

    static func hasContent(for app: AppState) -> Bool {
        let form = app.formBlocker.flatMap { app.promptIsEmpty ? nil : $0 }
        let refusal = app.formBlocker == nil ? app.memoryRefusal : nil
        if form != nil || refusal?.text != nil { return true }
        if case .running = app.diagnostic { return true }
        if app.state(of: .denoising) == .active, app.totalSteps > 0,
           !(app.followsRender || app.history.isEmpty) { return true }
        return false
    }

    var body: some View {
        let form = app.formBlocker.flatMap { app.promptIsEmpty ? nil : $0 }
        let refusal = app.formBlocker == nil ? app.memoryRefusal : nil
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            if let reason = form ?? refusal?.text {
                Text(reason).lineLimit(1).truncationMode(.tail)
                if let f = refusal?.smaller {
                    Button(String(localized: "Use \(String(f.width)) × \(String(f.height))")) { app.useFormat(f) }
                        .buttonStyle(.link)
                        .help("The largest of this model’s sizes this Mac renders")
                }
            } else if case let .running(done, total, line) = app.diagnostic {
                Text(app.settingsRead ? "The diagnostic is running: renders wait for it."
                                      : "Siliconed measures this Mac before its first render — about a minute.")
                    .lineLimit(1)
                Text(verbatim: "\(line) · \(done + 1)/\(total)").foregroundStyle(.tertiary).lineLimit(1)
            } else if app.state(of: .denoising) == .active, app.totalSteps > 0,
                      !(app.followsRender || app.history.isEmpty) {
                Text("step \(app.currentStep)/\(app.totalSteps)").monospacedDigit()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let r = app.remaining(at: context.date) {
                        Text("\(Figures.duration(r)) left").monospacedDigit()
                    }
                }
                Button { app.cancel() } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("Stop (⌘.)")
                .accessibilityLabel(Text("Stop"))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

extension AppState {
    /// Fork: the prompt has no text — Generate is greyed, and nothing more is said.
    var promptIsEmpty: Bool { prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
