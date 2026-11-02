// Fork: **the composer** — the prompt and what a render needs most, in one glass card at the foot of
// the canvas, laid out as the image generators Derek works with lay it out: the prompt, then the model,
// the aspect ratio, the resolution and the batch as pills that show only the current choice (each opens
// its list on a click), then « Generate ». Under them, the cost before the click, what stops it, or how
// far the running render is. The rest (an edit's images, the LoRA stack, seed, steps, detail, solver)
// is the left column's (`GenerateSettings`). Shown on the Generate tab; Explore keeps its own form.

import AppKit
import Siliconed
import SwiftUI

struct Composer: View {
    @Bindable var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            prompt
            HStack(spacing: 8) {
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
                BatchPill(app: app)
                Spacer(minLength: 8)
                GenerateButton(app: app)
            }
            StatusLine(app: app)
        }
        .padding(16)
        .glass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(maxWidth: 920)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var prompt: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $app.prompt)
                .accessibilityLabel(Text("Prompt"))
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .scrollIndicators(.automatic)
                .frame(height: 64)
            if app.prompt.isEmpty {
                Text(app.references.isEmpty ? "Describe the image…" : "Say what changes…")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
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
/// then on the right what stops « Generate », the measure a first render waits for, or the running
/// render's step and time left with its stop.
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
            } else if app.state(of: .denoising) == .active, app.totalSteps > 0 {
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
