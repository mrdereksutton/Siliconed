// Fork: **what the composer keeps one click away** — the LoRA stack with each strength under the hand,
// and the render's settings (seed, steps, detail, solver, step previews). The composer opens them as
// panels from its « LoRA » and « Settings » cells: the one place they live. Drawn with Silicon's controls
// (`Silicon.swift`): chips, a stepper cell, a slider, a switch.

import AppKit
import Siliconed
import SwiftUI

/// **The LoRA stack**: how many of the three and « Import… », one line per LoRA with its strength, then
/// the model's LoRAs not yet in the stack — a click adds one.
struct LoRAStack: View {
    @Bindable var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SpecCaption("LoRA")
                if !app.loras.isEmpty {
                    Text(verbatim: "\(app.loras.count)/\(AppState.maxLoRA)").font(Silicon.readout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button("Import…") { app.chooseToImport() }
                    .buttonStyle(SiliconButtonStyle())
                    .disabled(!app.importPossible)
                    .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
            }
            if app.compatibleLoras.isEmpty {
                Text("No LoRA for this model").font(.callout).foregroundStyle(.secondary)
            } else if app.loras.isEmpty {
                Text("Add a LoRA to the stack (3 at most)").font(.callout).foregroundStyle(.secondary)
            }
            ForEach($app.loras) { $slot in LoRALine(app: app, slot: $slot) }
            LoRAChoices(app: app)
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
                            Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(Color.accentColor)
                            Text(verbatim: l.name).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .help(([l.name] + l.fromItsMetadata).joined(separator: "\n"))
                }
            }
        }
    }
}

/// **A LoRA of the stack**: its name, its strength as a figure and a slider — a double click puts 0.8
/// back —, and its remove button.
struct LoRALine: View {
    let app: AppState
    @Binding var slot: LoRASlot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(verbatim: app.loraCard(slot.path)?.name ?? URL(fileURLWithPath: slot.path).deletingPathExtension().lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
                    .help(app.loraCard(slot.path).map { ([$0.name] + $0.fromItsMetadata).joined(separator: "\n") } ?? slot.path)
                Spacer(minLength: 4)
                Text(Figures.strength(slot.strength)).font(Silicon.readout).foregroundStyle(.secondary)
                    .onTapGesture(count: 2) { slot.strength = LoRASlot().strength }
                    .help("Strength — double-click for 0.8")
                Button {
                    // The id is read BEFORE: `slot` is a binding on `app.loras`, and re-reading it in
                    // `removeAll`'s predicate accesses the array during its mutation.
                    let id = slot.id
                    app.loras.removeAll { $0.id == id }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Silicon.cellHover))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove this LoRA from the stack")
                .accessibilityLabel(Text("Remove this LoRA from the stack"))
            }
            SiliconSlider(value: $slot.strength, range: app.loraStrengthRange, reset: LoRASlot().strength)
                .accessibilityLabel(Text("Strength"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Silicon.cell))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Silicon.edge))
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
                divider
                row("Variation") { variation }
                    .help("The next render is a variation of the seed’s image, like the image it came from")
            }
            divider
            row("Steps") { StepperChip(value: $app.steps, range: 1...50) }
                .help(String(localized: "\(app.card?.defaultSteps ?? 8) steps: the count this Turbo model is distilled for"))
            // Not on a model that offers none (Anima): a choice that changes nothing is not shown.
            if app.offersDetail {
                divider
                row("Detail") {
                    ChipPicker(selection: $app.detail, choices: Detail.allCases) { Text(verbatim: $0.choice) }
                        .fixedSize()
                }
                .help("Adds fine texture and small details; Most can over-sharpen")
            }
            // More Solvers (Settings › Advanced): how a step moves to the next. Euler is the distillation's own.
            if app.offeredSolvers.count > 1 {
                divider
                row("Solver") {
                    ChipPicker(selection: $app.solver, choices: app.offeredSolvers) { Text(verbatim: $0.choice) }
                        .fixedSize()
                }
                .help("How each step moves to the next, with the same steps: Euler is the one this model was distilled for")
            }
            divider
            Toggle("Preview every step", isOn: $app.previews)
                .toggleStyle(SiliconToggleStyle())
                .frame(minHeight: 40)
                .help("Shows the image taking shape on the canvas after each step. It does not change the image.")
        }
    }

    private var divider: some View { Rectangle().fill(Silicon.edge).frame(height: 1) }

    private func row<Control: View>(_ title: LocalizedStringKey, @ViewBuilder _ control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            control()
        }
        .frame(minHeight: 40)
    }

    private var seed: some View {
        HStack(spacing: 6) {
            if app.fixedSeed {
                TextField("Seed", value: $app.seed, format: .number.grouping(.never))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(Silicon.readout)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .frame(width: 104, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Silicon.cell))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Silicon.edge))
                Button { app.seed = UInt64.random(in: 0...UInt64(UInt32.max)) } label: {
                    Image(systemName: "dice").frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Silicon.cell))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Silicon.edge))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Draw a seed")
                .accessibilityLabel(Text("Draw a seed"))
            }
            ChipPicker(selection: $app.fixedSeed, choices: [false, true]) { fixed in
                fixed ? Text("Fixed") : Text("Random")
            }
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
