// Fork: **the composer** — the prompt and every setting of a render on one graphite panel at the foot
// of the canvas (`Silicon.swift`): an edit's images over the prompt, then the model, the aspect ratio,
// the resolution, the LoRA stack, the settings and the batch as spec cells that show only the current
// choice — each opens its panel over it on a click, one at a time —, then « Generate ». Under them,
// only what stops a render or needs a decision; the time a click costs is Generate's tooltip. Shown on the Generate tab; Explore keeps its own form in
// the left column.

import AppKit
import Siliconed
import SwiftUI

struct Composer: View {
    @Bindable var app: AppState
    /// Where each cell sits, in the composer's own space — its panel opens over it — and where the
    /// composer is in the window: its width holds a panel, its top gives the room above a cell.
    @State private var cells: [ComposerPanel: CGRect] = [:]
    @State private var frame: CGRect = .zero
    private static let space = "composer"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if app.editingPossible, !app.references.isEmpty { references }
            prompt
            HStack(alignment: .center, spacing: 8) {
                if app.editingPossible { AttachCell(app: app) }
                cell(.model, "Model") {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                    Text(verbatim: app.card?.name ?? "—")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .help("The denoiser: the publisher’s model, or a fine-tune you imported")
                if app.references.isEmpty {
                    let current = SizeTable.match(app.format)
                    cell(.ratio, "Ratio") {
                        if let current {
                            RatioShape(ratio: current.ratio, side: 12)
                            Text(verbatim: current.ratio.label)
                        } else {
                            Text(verbatim: "\(app.format.width) × \(app.format.height)")
                        }
                    }
                    .help("Aspect ratio")
                    if let current {
                        cell(.tier, "Resolution") { Text(verbatim: current.tier.label) }
                            .help("Resolution")
                    }
                } else {
                    // An edit keeps image 1's framing: its size, not a choice.
                    let f = app.outputFormat
                    SpecCellFace(caption: "Size") {
                        Text(verbatim: "\(f.width) × \(f.height)")
                        Image(systemName: "lock.fill").imageScale(.small).foregroundStyle(.secondary)
                    }
                    .help("An edit keeps the framing of image 1: about 1 megapixel at its proportions, each side at least 512, 1024² at most")
                }
                if app.missing == nil, app.card != nil {
                    cell(.lora, "LoRA") {
                        if app.loras.isEmpty {
                            Text(verbatim: "—").foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "square.stack.3d.up.fill").imageScale(.small).foregroundStyle(Color.accentColor)
                            Text(verbatim: "\(app.loras.count)")
                        }
                    }
                    .help("Add a LoRA to the stack (3 at most)")
                    // « Settings », not « Steps »: the cell opens the seed, the steps, the detail, the
                    // solver and the previews; its face says the steps and, pinned, that the seed is fixed.
                    cell(.settings, "Settings") {
                        Text("\(app.steps) steps")
                        if app.fixedSeed {
                            Image(systemName: "pin.fill").imageScale(.small).foregroundStyle(.secondary)
                                .help("The seed is fixed: the same image again")
                                .accessibilityLabel(Text("Fixed seed"))
                        }
                    }
                    .help("Seed, steps, detail and solver")
                }
                BatchCell(app: app)
                Spacer(minLength: 8)
                GenerateButton(app: app)
            }
            StatusLine(app: app)
        }
        .padding(16)
        .coordinateSpace(.named(Self.space))
        .siliconPanel(RoundedRectangle(cornerRadius: 20, style: .continuous), sheen: true)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        // A click anywhere but on the composer or its panel closes the panel, as a popover's would —
        // laid under the composer, so that its cells and its prompt still take their clicks.
        .background {
            if app.composerPanel != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 8000, height: 8000)
                    .onTapGesture { close() }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) { panels }
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

    // MARK: The cells and their panels

    private func cell<Value: View>(_ panel: ComposerPanel, _ caption: LocalizedStringKey,
                                   @ViewBuilder value: () -> Value) -> some View {
        SpecCell(caption: caption, open: app.composerPanel == panel, action: { toggle(panel) }, value: value)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { cells[panel] = $0 }
    }

    private func toggle(_ panel: ComposerPanel) {
        withAnimation(Motion.pick(.easeOut(duration: 0.14))) {
            app.composerPanel = app.composerPanel == panel ? nil : panel
        }
    }

    private func close() {
        withAnimation(Motion.pick(.easeOut(duration: 0.14))) { app.composerPanel = nil }
    }

    /// **The open panel, over its cell** — its foot 10 points above the cell, its left edge on the cell's,
    /// kept inside the composer's width. Moved there by an offset: an overlay sets its content in the
    /// composer's own frame (its top left on the composer's), and the panel has to rise above it.
    @ViewBuilder private var panels: some View {
        if let open = app.composerPanel, let cell = cells[open] {
            // The room above the cell, up to under the toolbar: a taller panel scrolls.
            let room = max(160, frame.minY + cell.minY - 80)
            panel(open, room: room)
                .offset(x: min(cell.minX, max(0, frame.width - Self.width(open))), y: cell.minY - 10 - room)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))
        }
    }

    private static func width(_ panel: ComposerPanel) -> CGFloat {
        switch panel {
        case .model: 330
        case .ratio: 280
        case .tier: 300
        case .lora: 360
        case .settings: 390
        }
    }

    /// The panel at its own height when the room above its cell holds it, scrolling in that room
    /// otherwise — so that a short window never pushes the top of a list out of reach.
    @ViewBuilder private func panel(_ open: ComposerPanel, room: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            panelContent(open)
            ScrollView(.vertical) { panelContent(open) }
        }
        .fixedSize(horizontal: true, vertical: false)
        .siliconPanel(RoundedRectangle(cornerRadius: 14, style: .continuous), sheen: true)
        .frame(height: room, alignment: .bottom)
    }

    @ViewBuilder private func panelContent(_ open: ComposerPanel) -> some View {
        Group {
            switch open {
            case .model:
                ModelChoices(app: app, done: close)
            case .ratio:
                VStack(alignment: .leading, spacing: 0) {
                    RatioChoices(app: app, done: close)
                    Rectangle().fill(Silicon.edge).frame(height: 1).padding(.horizontal, 14)
                    CustomSize(app: app, title: "Custom size", done: close)
                }
            case .tier:
                TierChoices(app: app, done: close)
            case .lora:
                LoRAStack(app: app)
                    .padding(14)
            case .settings:
                RenderOptions(app: app)
                    .padding(.horizontal, 14).padding(.vertical, 6)
            }
        }
        .frame(width: Self.width(open))
        .font(.callout)
    }

    // MARK: The prompt and an edit's images

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

// MARK: - The cells that act at once

/// **« + » for an image**: the one to edit first, then the ones the prompt draws from. Greyed beyond the
/// model's count or this Mac's memory (the reason is the tooltip).
private struct AttachCell: View {
    @Bindable var app: AppState
    @State private var hovering = false

    var body: some View {
        let refusal = app.canAddReference ? app.nextReferenceRefusal() : nil
        let enabled = app.canAddReference && refusal == nil
        Button { app.chooseReferences() } label: {
            SpecCellFace(caption: "Images", hovering: hovering) {
                Image(systemName: "photo.badge.plus")
                if !app.references.isEmpty {
                    Text(verbatim: "\(app.references.count)/\(app.maxReferences)").font(Silicon.readout)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .help(refusal.map { Text($0) }
              ?? (app.references.isEmpty ? Text("The image to edit — or drop or paste it here (⌘V)")
                                         : Text("Add an image the prompt can draw from — or drop or paste it here (⌘V)")))
        .accessibilityLabel(Text("Add an Image"))
    }
}

/// **How many images a click makes**, − and + on its cell: consecutive seeds, the prompt encoded once.
private struct BatchCell: View {
    @Bindable var app: AppState

    var body: some View {
        SpecCellFace(caption: "Batch") {
            step("minus", -1)
            Text(verbatim: "\(app.batch)").font(Silicon.readout.weight(.semibold)).frame(minWidth: 12)
            step("plus", 1)
        }
        .help("Consecutive seeds; the prompt is encoded only once")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Batch"))
    }

    private func step(_ symbol: String, _ by: Int) -> some View {
        let blocked = !(1...8).contains(app.batch + by)
        return Button { app.batch = min(8, max(1, app.batch + by)) } label: {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(blocked)
        .foregroundStyle(blocked ? .tertiary : .secondary)
    }
}

// MARK: - The model list

/// **Every model, with a line on what it makes**; then the way to the Models window and to an import.
private struct ModelChoices: View {
    @Bindable var app: AppState
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChoiceList(title: "Model", minWidth: 300) {
                ForEach(app.visibleCards) { card in
                    ChoiceRow(selected: card.id == app.identifier, enabled: true) {
                        app.identifier = card.id
                        done()
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
            Rectangle().fill(Silicon.edge).frame(height: 1).padding(.horizontal, 14)
            HStack {
                Button("Models…") { done(); app.managementOpen = true }
                    .help("Install, import, remove — and what each takes on disk (⇧⌘M)")
                Spacer()
                Button("Import…") { done(); app.chooseToImport() }
                    .disabled(!app.importPossible)
                    .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
            }
            .buttonStyle(SiliconButtonStyle())
            .padding(.horizontal, 14)
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

// MARK: - Generate

/// **« Generate »**: the mode's action (`SiliconPrimaryStyle`), the key on its cap. Greyed while
/// something stops the render (said in the status line under it). During a render it adds to the
/// queue, as upstream's, and a light sweeps across it.
private struct GenerateButton: View {
    @Bindable var app: AppState

    var body: some View {
        Button { app.render() } label: {
            HStack(spacing: 10) {
                Text(label)
                KeyCap("⌘↩")
            }
        }
        .buttonStyle(SiliconPrimaryStyle(sweeping: app.busy))
        .disabled(app.formBlocker != nil || app.memoryRefusal != nil)
        .help(app.plannedCost.map { Text(verbatim: "≈ " + Figures.duration($0)) } ?? Text(verbatim: "⌘↩"))
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

/// **Under the cells, only when something needs saying**: what stops « Generate » (but not an empty
/// prompt — the greyed button says it), a memory refusal with the size this Mac renders, the measure
/// a first render waits for, or — when the canvas shows another image — the running render's step and
/// time left, with its stop. Nothing otherwise: the size is in the cells, the time in Generate's tooltip.
private struct StatusLine: View {
    @Bindable var app: AppState

    var body: some View {
        // Read once per drawing: the memory half computes the need against B (`MemoryBudget`).
        let form = app.formBlocker.flatMap { app.promptIsEmpty ? nil : $0 }
        let refusal = app.formBlocker == nil ? app.memoryRefusal : nil
        let progress = app.state(of: .denoising) == .active && app.totalSteps > 0
            && !(app.followsRender || app.history.isEmpty)
        if form != nil || refusal != nil || app.diagnosticRunning || progress {
            HStack(spacing: 8) {
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
                } else if progress {
                    // The canvas shows another image: the running render's progress is said here instead.
                    Text("step \(app.currentStep)/\(app.totalSteps)").font(Silicon.readout)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let r = app.remaining(at: context.date) {
                            Text("\(Figures.duration(r)) left").font(Silicon.readout)
                        }
                    }
                    Button { app.cancel() } label: {
                        Image(systemName: "stop.circle.fill").font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                    .help("Stop (⌘.)")
                    .accessibilityLabel(Text("Stop"))
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }
}

extension AppState {
    /// Fork: the prompt has no text — Generate is greyed, and nothing more is said.
    var promptIsEmpty: Bool { prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
