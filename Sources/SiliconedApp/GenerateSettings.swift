// Fork: **what the composer keeps one click away** — the LoRA stack with each strength under the hand,
// and the render's settings (seed, steps, detail, solver, step previews). The composer opens them as
// popovers from its « LoRA » and « Settings » pills; the left column, when shown on the Generate tab,
// lays out the same views (`SettingsColumn`), an edit's images above them.

import AppKit
import Siliconed
import SwiftUI

/// **The LoRA stack**, as the composer's other popovers are laid out: its caption with how many of the three,
/// one line per LoRA with its strength, the model's LoRAs not yet in the stack — a click adds one —, then
/// « Import… » in the footer, as under the model list.
struct LoRAStack: View {
    @Bindable var app: AppState
    var done: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("LoRA").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text(verbatim: "\(app.loras.count)/\(AppState.maxLoRA)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8).padding(.top, 2)
                if app.compatibleLoras.isEmpty {
                    Text("No LoRA for this model").foregroundStyle(.secondary).padding(.horizontal, 8)
                }
                ForEach($app.loras) { $slot in LoRALine(app: app, slot: $slot) }
                LoRAChoices(app: app)
            }
            .padding(8)
            Divider().padding(.horizontal, 16)
            HStack {
                Spacer()
                Button("Import…") { done(); app.chooseToImport() }
                    .buttonStyle(.link)
                    .disabled(!app.importPossible)
                    .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

/// **The model's LoRAs not yet in the stack**, one row each — a click adds it, while the stack has room.
/// Rows, as every list of choices here, rather than a menu.
struct LoRAChoices: View {
    let app: AppState

    var body: some View {
        let used = Set(app.loras.map(\.path))
        let open = app.compatibleLoras.filter { !used.contains($0.path) }
        if app.canAddLoRA, !open.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(open) { l in
                    ChoiceRow(selected: false, enabled: true) {
                        app.loras.append(LoRASlot(path: l.path))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            Text(verbatim: l.name).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .help(l.details)
                }
            }
        }
    }
}

/// **A LoRA of the stack**: its name (a menu to swap it for another), its strength as a figure and a
/// slider — a double click puts 0.8 back —, and its remove button.
struct LoRALine: View {
    let app: AppState
    @Binding var slot: LoRASlot

    var body: some View {
        let name = app.loraCard(slot.path)?.name ?? URL(fileURLWithPath: slot.path).deletingPathExtension().lastPathComponent
        let tooltip = app.loraCard(slot.path)?.details ?? slot.path
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if app.compatibleLoras.count > 1 {
                    Menu {
                        ForEach(app.compatibleLoras) { l in
                            Button(l.name) { slot.path = l.path }.disabled(l.path == slot.path)
                        }
                    } label: {
                        Text(verbatim: name).lineLimit(1).truncationMode(.middle)
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .help(tooltip)
                } else {
                    Text(verbatim: name)
                        .lineLimit(1).truncationMode(.middle)
                        .help(tooltip)
                }
                Spacer(minLength: 4)
                Text(Figures.strength(slot.strength)).monospacedDigit().foregroundStyle(.secondary)
                    .onTapGesture(count: 2) { slot.strength = LoRASlot().strength }
                    .help("Strength — double-click for 0.8")
                    .accessibilityLabel(Text("Strength"))
                    .accessibilityAddTraits(.isStaticText)
                Button {
                    // The id is read BEFORE: `slot` is a binding on `app.loras`, and re-reading it in
                    // `removeAll`'s predicate accesses the array during its mutation.
                    let id = slot.id
                    app.loras.removeAll { $0.id == id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove this LoRA from the stack")
                .accessibilityLabel(Text("Remove this LoRA from the stack"))
            }
            Slider(value: $slot.strength, in: app.loraStrengthRange)
                .controlSize(.small)
                .accessibilityLabel(Text("Strength"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.well))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.hairline))
        .contextMenu {
            Button("Reset to 0.8") { slot.strength = LoRASlot().strength }
        }
    }
}

/// **The render's settings, one per row**: the seed (random or fixed, with its die), a variation when
/// one is set, the steps, the detail and the solver where the model offers them, the step previews.
struct RenderOptions: View {
    @Bindable var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Seed") { seed }
                .help("Random: a new seed for every render. Fixed: the same image again")
            if !app.variations.isEmpty {
                Divider()
                row("Variation") { variation }
                    .help("The next render is a variation of the seed’s image, like the image it came from")
            }
            Divider()
            row("Steps") {
                Stepper(value: $app.steps, in: 1...50) { Text(verbatim: "\(app.steps)").monospacedDigit() }
                    .fixedSize()
            }
            .help(String(localized: "\(app.card?.defaultSteps ?? 8) steps: the count this Turbo model is distilled for"))
            // Not on a model that offers none (Anima): a choice that changes nothing is not shown.
            if app.offersDetail {
                Divider()
                row("Detail") {
                    Picker("Detail", selection: $app.detail) {
                        ForEach(Detail.allCases, id: \.self) { Text(verbatim: $0.choice).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                .help("Adds fine texture and small details; Most can over-sharpen")
            }
            // More Solvers (Settings › Advanced): how a step moves to the next. Euler is the distillation's own.
            if app.offeredSolvers.count > 1 {
                Divider()
                row("Solver") {
                    Picker("Solver", selection: $app.solver) {
                        ForEach(app.offeredSolvers, id: \.self) { Text(verbatim: $0.choice).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                .help("How each step moves to the next, with the same steps: Euler is the one this model was distilled for")
            }
            Divider()
            row("Preview every step") {
                Toggle("Preview every step", isOn: $app.previews)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .help("Shows the image taking shape on the canvas after each step. It does not change the image.")
        }
    }

    private func row<Control: View>(_ title: LocalizedStringKey, @ViewBuilder _ control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            control()
        }
        .frame(minHeight: 38)
    }

    private var seed: some View {
        HStack(spacing: 8) {
            if app.fixedSeed {
                TextField("Seed", value: $app.seed, format: .number.grouping(.never))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 104)
                Button { app.seed = UInt64.random(in: 0...UInt64(UInt32.max)) } label: { Image(systemName: "dice") }
                    .buttonStyle(.borderless)
                    .help("Draw a seed")
                    .accessibilityLabel(Text("Draw a seed"))
            }
            Picker("Seed", selection: $app.fixedSeed) {
                Text("Random").tag(false)
                Text("Fixed").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var variation: some View {
        HStack(spacing: 6) {
            Text(verbatim: app.variations.map { VariationWords.label($0.strength) }.joined(separator: " + "))
            Button { app.variations = [] } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .help("Remove the variation: the seed’s own image")
                .accessibilityLabel(Text("Remove the variation: the seed’s own image"))
        }
    }
}

/// **The left column on the Generate tab**, when one shows it: an edit's images (or a starting image),
/// the LoRA stack and the settings, each on its own plate — the same views the composer's popovers hold.
struct SettingsColumn: View {
    @Bindable var app: AppState

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if app.editingPossible {
                    ImagesNode(app: app)
                } else if app.usedStart != nil {
                    StartImageNode(app: app)
                }
                if app.missing == nil, app.card != nil {
                    LoRAStack(app: app)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.well))
                    RenderOptions(app: app)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.well))
                }
            }
            .font(.callout)
            .padding(14)
        }
        .scrollIndicators(.automatic)
    }
}
