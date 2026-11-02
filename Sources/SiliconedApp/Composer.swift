// Fork: **the composer** — the prompt and every setting of a render in one glass card at the foot of
// the canvas, laid out as the image generators Derek works with lay it out: an edit's images over the
// prompt, then the model, the aspect ratio, the resolution, the LoRA stack, the settings and the batch
// as pills that show only the current choice (each opens its list or its panel on a click), then
// « Generate ». Under them, the cost before the click, or what stops it. Shown on the Generate tab;
// Explore keeps its own form in the left column.

import AppKit
import Siliconed
import SwiftUI

struct Composer: View {
    @Bindable var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if app.editingPossible, !app.references.isEmpty { references }
            prompt
            HStack(spacing: 8) {
                if app.editingPossible { AttachPill(app: app) }
                PillButton { LabWindow.shared.show() } label: {
                    Image(systemName: "wand.and.sparkles")
                }
                .help("Open the Prompt Lab (⌥⌘L)")
                .accessibilityLabel(Text("Prompt Lab"))
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
                Spacer(minLength: 8)
                GenerateButton(app: app)
            }
            StatusLine(app: app)
        }
        .padding(16)
        .glass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // As on the canvas: a PNG Siliconed wrote brings back its settings; on a model that edits, any
        // other image joins the edit.
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
            guard app.editingPossible, !(files.isEmpty && pasted.isEmpty) else { return false }
            pasted.forEach { app.addReference(png: $0) }
            app.addReferences(files)
            return true
        }
    }

    /// **The prompt**: as tall as its text — two lines to seven, then it scrolls. Return makes a new
    /// line; ⌘↩ renders.
    private var prompt: some View {
        // The text, invisible, gives the editor its height (`TextEditor` takes any height it is offered);
        // its line limit is the cap — a `frame(maxHeight:)` would grow to the height offered.
        Text(verbatim: app.prompt + " ")
            .font(.system(size: 15))
            .lineLimit(7)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            .opacity(0)
            .accessibilityHidden(true)
            .overlay {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $app.prompt)
                        .accessibilityLabel(Text("Prompt"))
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                    if app.prompt.isEmpty {
                        Text(app.references.isEmpty ? "Describe the image…" : "Say what changes…")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
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
            Circle().fill(Color.accentColor).frame(width: 7, height: 7)
            Text(verbatim: app.card?.name ?? "—").lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        } choices: {
            VStack(alignment: .leading, spacing: 0) {
                ChoiceList(title: "Model", minWidth: 300) {
                    ForEach(app.visibleCards) { card in
                        ChoiceRow(selected: card.id == app.identifier, enabled: true) {
                            app.identifier = card.id
                            open = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                if app.readySet.contains(card.id) {
                                    Text(verbatim: card.name).fontWeight(.medium)
                                } else {
                                    Text("\(card.name) (not installed)").fontWeight(.medium)
                                }
                                if let blurb = ModelBlurb.text(card) {
                                    Text(verbatim: blurb).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Divider().padding(.horizontal, 16)
                HStack {
                    Button("Models…") { open = false; app.managementOpen = true }
                        .help("Install, import, remove — and what each takes on disk (⇧⌘M)")
                    Spacer()
                    Button("Import…") { open = false; app.chooseToImport() }
                        .disabled(!app.importPossible)
                        .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
                }
                .buttonStyle(.link)
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .help("The denoiser: the publisher’s model, or a fine-tune you imported")
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
/// each LoRA with its strength slider, « Add », « Import… ».
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
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Circle().fill(Color.accentColor))
            }
        } choices: {
            LoRAStack(app: app)
                .font(.callout)
                .padding(14)
                .frame(width: 340, alignment: .leading)
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
            }
        } choices: {
            RenderOptions(app: app)
                .font(.callout)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .frame(width: 330)
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

/// **« Generate »**: the accent, the key under it; greyed while something stops the render (said in
/// the status line under it). During a render it adds to the queue, as upstream's.
private struct GenerateButton: View {
    @Bindable var app: AppState

    var body: some View {
        let blocked = app.formBlocker != nil || app.memoryRefusal != nil
        Button { app.render() } label: {
            HStack(spacing: 10) {
                Text(label).font(.system(size: 14, weight: .semibold))
                Text(verbatim: "⌘↩").font(.system(size: 12, weight: .medium)).opacity(0.65)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.accentColor))
            .opacity(blocked ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(blocked)
    }

    private var label: String {
        let n = app.variantCount
        if app.busy { return n > 1 ? String(localized: "Add \(n) Renders to Queue") : String(localized: "Add to Queue") }
        if !app.references.isEmpty { return n > 1 ? String(localized: "Edit Image \(n) Ways") : String(localized: "Edit Image") }
        let images = n * max(1, app.batch)
        return images > 1 ? String(localized: "Generate \(images) Images") : String(localized: "Generate")
    }
}

// MARK: - The status line

/// **Under the pills, one line**: the cost before the click (size, memory, time learned on this Mac),
/// then on the right what stops « Generate », the measure a first render waits for, or — when the
/// canvas shows another image — the running render's step and time left, with its stop.
private struct StatusLine: View {
    @Bindable var app: AppState

    var body: some View {
        // Read once per drawing: the memory half computes the need against B (`MemoryBudget`).
        let form = app.formBlocker
        let refusal = form == nil ? app.memoryRefusal : nil
        HStack(spacing: 8) {
            cost
            Spacer(minLength: 12)
            if let reason = form ?? refusal?.text {
                Text(reason).lineLimit(1).truncationMode(.tail)
                // A memory refusal is never a dead end: a size this Mac renders.
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
                // The canvas shows another image: the running render's progress is said here instead.
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

    /// Size · memory · renders · time: the figures, text only.
    @ViewBuilder private var cost: some View {
        if app.missing == nil, app.card != nil {
            let f = app.outputFormat
            HStack(spacing: 6) {
                Text(verbatim: "\(f.width) × \(f.height)").monospacedDigit()
                if let need = app.memoryNeed {
                    separator
                    Text(Figures.memory(need)).monospacedDigit()
                }
                if app.variantCount > 1 {
                    separator
                    Text("\(app.variantCount) renders").monospacedDigit().help(app.alternativesHelp)
                }
                separator
                if let t = app.plannedCost {
                    Text(verbatim: "≈ " + Figures.duration(t)).monospacedDigit()
                } else {
                    Text("after one render")
                        .help("Learned on this Mac: the first render at this size, with this model, sets the estimate")
                }
            }
        }
    }

    private var separator: some View { Text(verbatim: "·").foregroundStyle(.tertiary) }
}
