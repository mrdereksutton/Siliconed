// Fork: **what the composer keeps one click away** — the LoRA stack with each strength under the hand,
// and the render's settings (seed, steps, detail, solver, step previews). The composer opens them as
// popovers from its « LoRA » and settings pills; the left column, when shown on the Generate tab, lays
// out the same views (`SettingsColumn`), an edit's images above them.

import AppKit
import Siliconed
import SwiftUI

/// **The LoRA stack**: how many of the three, « Add » (the model's LoRAs not yet in the stack) and
/// « Import… », then one row per LoRA with its strength slider.
struct LoRAStack: View {
    @Bindable var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("LoRA").font(.headline)
                if !app.loras.isEmpty {
                    Text(verbatim: "\(app.loras.count)/\(AppState.maxLoRA)").monospacedDigit().foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if !app.compatibleLoras.isEmpty { LoRAAddMenu(app: app) }
                Button("Import…") { app.chooseToImport() }
                    .buttonStyle(.link)
                    .disabled(!app.importPossible)
                    .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
            }
            if app.loras.isEmpty {
                Text(app.compatibleLoras.isEmpty ? "No LoRA for this model" : "Add a LoRA to the stack (3 at most)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach($app.loras) { $slot in LoRARow(app: app, slot: $slot) }
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
                Toggle("Preview every step", isOn: $app.previews).toggleStyle(.switch).labelsHidden().controlSize(.small)
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
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Button { app.seed = UInt64.random(in: 0...UInt64(UInt32.max)) } label: { Image(systemName: "dice") }
                    .buttonStyle(.borderless)
                    .help("Draw a seed")
                    .accessibilityLabel(Text("Draw a seed"))
            }
            Picker("Seed", selection: $app.fixedSeed) {
                Text("Random").tag(false)
                Text("Fixed").tag(true)
            }
            .labelsHidden().fixedSize()
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

/// **The left column on the Generate tab**, when one shows it: an edit's images, the LoRA stack and the
/// settings, each on its own plate — the same views the composer's popovers hold.
struct SettingsColumn: View {
    @Bindable var app: AppState

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if app.editingPossible { ImagesNode(app: app) }
                if app.missing == nil, app.card != nil {
                    LoRAStack(app: app)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.well))
                    RenderOptions(app: app)
                        .padding(.horizontal, 12).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.well))
                }
            }
            .font(.callout)
            .padding(14)
        }
        .scrollIndicators(.automatic)
    }
}
